package Mojo::Feed;
use Mojo::Base '-base';

our $VERSION = "0.01";

use Mojo::Feed::Item;

use Mojo::Util qw(decode trim);
use Mojo::DOM;
use HTTP::Date;
use Mojo::File;
use Mojo::UserAgent;
use Carp qw(carp croak);
use Scalar::Util qw(blessed);

our @time_fields
  = (qw(pubDate published created issued updated modified dc\:date));
our %is_time_field = map { $_ => 1 } @time_fields;

# feed mime-types:
our @feed_types = (
  'application/x.atom+xml', 'application/atom+xml',
  'application/xml',        'text/xml',
  'application/rss+xml',    'application/rdf+xml'
);
our %is_feed = map { $_ => 1 } @feed_types;

has default_charset => 'UTF-8';
has charset         => sub { shift->default_charset };
has ua              => sub { Mojo::UserAgent->new };
has root            => sub { {} };

has body => '';

# Stole this from Mojo::URL
sub new { @_ == 2 ? shift->SUPER::new->parse(@_) : shift->SUPER::new(@_) }

sub url {
  my ($self) = shift;

  # Get
  return $self->{'url'} unless (@_);

  # Set
  $self->{'url'}
    = (ref $_[0] && ref $_[0] eq 'Mojo::URL') ? $_[0] : Mojo::URL->new($_[0]);
  return $self;
}

sub path {
  my ($self) = shift;
  return $self->{'path'} unless (@_);
  $self->{'path'}
    = (ref $_[0] && ref $_[0] eq 'Mojo::File') ? $_[0] : Mojo::File->new($_[0]);
  return $self;
}

sub load {
  my ($self) = shift;
  my $tx = $self->ua->get($self->url);
  if ($tx->success) {
    $self->body($tx->res->body);
    $self->charset($tx->res->content->charset);
  }
  else {
    croak "Error getting feed from url ", $self->url, ": ",
      (($tx->error) ? $tx->error->{message} : '');
  }
}

sub text {
  my $self    = shift;
  my $body    = $self->body;
  my $charset = $self->charset || $self->default_charset;
  return $charset ? decode($charset, $body) // $body : $body;
}

sub dom {
  my ($self) = @_;
  my $text = $self->text;
  return undef unless ($text);
  return Mojo::DOM->new($text);
}


sub parse {
  my ($self, $xml) = @_;
  if ($xml) {
    if ($xml =~ /^\</) {
      $self->body($xml);
    }
    elsif (-r $xml) {
      $self->path(Mojo::File->new($xml));
      $self->body($self->path->slurp);
    }
    elsif ($xml =~ /^https?\:/ || (ref $xml && ref $xml eq 'Mojo::URL')) {
      $self->url((ref $xml) ? $xml->clone() : Mojo::URL->new($xml));
    }
    else { }
  }
  $self->load() if ($self->url);
  $self->parse_feed_dom();
  return $self;
}

sub parse_feed_dom {
  my ($self)  = @_;
  my $dom     = $self->dom;
  my $feed    = $self->parse_feed_channel();    # Feed properties
  my $items   = $dom->find('item');
  my $entries = $dom->find('entry');            # Atom
  my $res     = [];
  foreach my $item ($items->each, $entries->each) {
    push @$res, parse_feed_item($item);
  }
  if (@$res) {
    $feed->{'items'} = $res;
  }
  $self->root($feed);
  return $feed;
}

sub parse_feed_channel {
  my ($self) = shift;
  my $dom = $self->dom;
  my %info;
  foreach my $k (
    qw{title subtitle description tagline link:not([rel]) link[rel=alternate] dc\:creator author webMaster},
    @time_fields
    )
  {
    my $p = $dom->at("channel > $k") || $dom->at("feed > $k");    # direct child
    if ($p) {
      $info{$k} = $p->text || $p->content || $p->attr('href');
      if ($k eq 'author' && $p->at('name')) {
        $info{$k} = $p->at('name')->text || $p->at('name')->content;
      }
      if ($is_time_field{$k}) {
        $info{$k} = str2time($info{$k});
      }
    }
  }
  my ($htmlUrl)
    = grep { defined $_ }
    map { delete $info{$_} } ('link:not([rel])', 'link[rel=alternate]');
  my ($description)
    = grep { defined $_ }
    map { exists $info{$_} ? $info{$_} : undef }
    (qw(description tagline subtitle));
  $info{htmlUrl}     = $htmlUrl     if ($htmlUrl);
  $info{description} = $description if ($description);

  # normalize fields:
  my @replace = (
    'pubDate'     => 'published',
    'dc\:date'    => 'published',
    'created'     => 'published',
    'issued'      => 'published',
    'updated'     => 'published',
    'modified'    => 'published',
    'dc\:creator' => 'author',
    'webMaster'   => 'author'
  );
  while (my ($old, $new) = splice(@replace, 0, 2)) {
    if ($info{$old} && !$info{$new}) {
      $info{$new} = delete $info{$old};
    }
  }

  # return (keys %info) ? \%info : undef;
  return \%info;
}

sub parse_feed_item {
  my ($item) = @_;
  my %h;
  foreach my $k (
    qw(title id summary guid content description content\:encoded xhtml\:body dc\:creator author),
    @time_fields
    )
  {
    my $p = $item->at($k);
    if ($p) {

      # skip namespaced items - like itunes:summary - unless explicitly
      # searched:
      next
        if ($p->tag =~ /\:/
        && $k ne 'content\:encoded'
        && $k ne 'xhtml\:body'
        && $k ne 'dc\:date'
        && $k ne 'dc\:creator');
      $h{$k} = $p->text || $p->content;
      if ($k eq 'author' && $p->at('name')) {
        $h{$k} = $p->at('name')->text;
      }
      if ($is_time_field{$k}) {
        $h{$k} = str2time($h{$k});
      }
    }
  }

  $item->find('enclosure')->each(
    sub {
        push @{ $h{enclosures} }, shift->attr;
    }
  );

  # let's handle links seperately, because ATOM loves these buggers:
  $item->find('link')->each(sub {
    my $l = shift;
    if ($l->attr('href')) {
      if ( $l->attr('rel' ) && $l->attr('rel') eq 'enclosure' ) {
                push @{$h{enclosures}}, {
                    url    => $l->attr('href'),
                    type   => $l->attr('type'),
                    length => $l->attr('length')
                };
      }
      elsif (!$l->attr('rel') || $l->attr('rel') eq 'alternate') {
        $h{'link'} = $l->attr('href');
      }
    }
    else {
      if ($l->text =~ /\w+/) {
        $h{'link'} = $l->text;    # simple link
      }

#         else { # we have an empty link element with no 'href'. :-(
#           $h{'link'} = $1 if ($l->next->text =~ m/^(http\S+)/);
#         }
    }
  });

  # find tags:
  my @tags;
  $item->find('category, dc\:subject')
    ->each(sub { push @tags, $_[0]->text || $_[0]->attr('term') });
  if (@tags) {
    $h{'tags'} = \@tags;
  }
  #
  # normalize fields:
  my @replace = (
    'content\:encoded' => 'content',
    'xhtml\:body'      => 'content',
    'summary'          => 'description',
    'pubDate'          => 'published',
    'dc\:date'         => 'published',
    'created'          => 'published',
    'issued'           => 'published',
    'updated'          => 'published',
    'modified'         => 'published',
    'dc\:creator'      => 'author'

      #    'guid'             => 'link'
  );
  while (my ($old, $new) = splice(@replace, 0, 2)) {
    if ($h{$old} && !$h{$new}) {
      $h{$new} = delete $h{$old};
    }
  }
  my %copy = ('description' => 'content', link => 'id', guid => 'id');
  while (my ($fill, $required) = each %copy) {
    if ($h{$fill} && !$h{$required}) {
      $h{$required} = $h{$fill};
    }
  }
  $h{"_raw"} = $item->to_string;
  return \%h;
}

# discover - get RSS/Atom feed URL from argument.
# Code adapted to use Mojolicious from Feed::Find by Benjamin Trott
# Any stupid mistakes are my own
sub discover {
  my $self = shift;
  my $url  = shift;

#  $self->ua->max_redirects(5)->connect_timeout(30);
  return
  $self->ua->get_p( $url )
           ->catch(sub { my ($err) = shift; die "Connection Error: $err" })
           ->then(sub {
                my ($tx) = @_;
                my @feeds;
                if ($tx->success && $tx->res->code == 200) {
                    @feeds = _find_feed_links($self, $tx->req->url, $tx->res);
                }
              return (@feeds);
            });
}

sub _find_feed_links {
  my ($self, $url, $res) = @_;

  state $feed_ext = qr/\.(?:rss|xml|rdf)$/;
  my @feeds;

  # use split to remove charset attribute from content_type
  my ($content_type) = split(/[; ]+/, $res->headers->content_type);
  if ($is_feed{$content_type}) {
    push @feeds, Mojo::URL->new($url)->to_abs;
  }
  else {
    # we are in a web page. PHEAR.
    my $base
      = Mojo::URL->new(
      $res->dom->find('head base')->map('attr', 'href')->join('') || $url)
      ->to_abs($url);
    my $title = $res->dom->find('head > title')->map('text')->join('') || $url;
    $res->dom->find('head link')->each(sub {
      my $attrs = $_->attr();
      return unless ($attrs->{'rel'});
      my %rel = map { $_ => 1 } split /\s+/, lc($attrs->{'rel'});
      my $type = ($attrs->{'type'}) ? lc trim $attrs->{'type'} : '';
      if ($is_feed{$type} && ($rel{'alternate'} || $rel{'service.feed'})) {
        push @feeds, Mojo::URL->new($attrs->{'href'})->to_abs($base);
      }
    });
    $res->dom->find('a')->grep(sub {
      $_->attr('href')
        && Mojo::URL->new($_->attr('href'))->path =~ /$feed_ext/io;
    })->each(sub {
      push @feeds, Mojo::URL->new($_->attr('href'))->to_abs($base);
    });
    unless (@feeds)
    {    # call me crazy, but maybe this is just a feed served as HTML?
      my $body = $res->body;
      $self->parse($body);
      if (%{$self->root}) {
        push @feeds, Mojo::URL->new($url)->to_abs;
      }
    }
  }
  return @feeds;
}

sub parse_opml {
  my ($self, $opml_file) = @_;
  my $opml_str = decode $self->charset,
    (ref $opml_file) ? $opml_file->slurp : Mojo::File->new($opml_file)->slurp;
  my $d = Mojo::DOM->new->parse($opml_str);
  my (%subscriptions, %categories);
  for my $item ($d->find(q{outline})->each) {
    my $node = $item->attr;
    if (!defined $node->{xmlUrl}) {
      my $cat = $node->{title} || $node->{text};
      $categories{$cat} = $item->children('[xmlUrl]')->map('attr', 'xmlUrl');
    }
    else {    # file by RSS URL:
      $subscriptions{$node->{xmlUrl}} = $node;
    }
  }


  # assign categories
  for my $cat (keys %categories) {
    for my $rss ($categories{$cat}->each) {
      next
        unless ($subscriptions{$rss})
        ;     # don't auto-vivify for empty "categories"
      $subscriptions{$rss}{'categories'} ||= [];
      push @{$subscriptions{$rss}{'categories'}}, $cat;
    }
  }
  return (values %subscriptions);
}

sub items {
  my ($self) = shift;
  return Mojo::Collection->new(
    map {
   #    $_->{published} = Mojo::Date->new($_->{published}) if ($_->{published});
      Mojo::Feed::Item->new(%$_);
    } @{$self->root->{'items'}}
  );
}


sub title {
  return shift->root->{title} unless (@_ > 1);
  $_[0]->root->{title} = $_[1];
  return $_[0];
}

sub description {
  return shift->root->{description} unless (@_ > 1);
  $_[0]->root->{description} = $_[1];
  return $_[0];
}

sub html_url {
  return shift->root->{htmlUrl} unless (@_ > 1);
  $_[0]->root->{htmlUrl} = $_[1];
  return $_[0];
}

sub published {
  return shift->root->{published} unless (@_ > 1);
  $_[0]->root->{published} = $_[1];
  return $_[0];
}

sub author {
  return shift->root->{author} unless (@_ > 1);
  $_[0]->root->{author} = $_[1];
  return $_[0];
}


1;
__END__

=encoding utf-8

=head1 NAME

Mojo::Feed - Mojo::DOM-based parsing of RSS & Atom feeds

=head1 SYNOPSIS

    use Mojo::Feed;

    my $feed = Mojo::Feed->new("atom.xml");
    print $feed->title, "\n",
      $feed->items->map('title')->join("\n");

    # Feed discovery (returns a Promise):
    Mojo::Feed->discover("search.cpan.org")->then(sub {
      my (@feeds) = @_;
      if (@feeds) {
        print $_->url for (@feeds);
      }
    })->catch(sub { die "Error: ", @_; });

   # 

=head1 DESCRIPTION

L<Mojo::Feed> is an Object Oriented module for identifying,
fetching and parsing RSS and Atom Feeds.  It relies on
L<Mojo::DOM> for XML/HTML parsing and L<Mojo::UserAgent>
for fetching feeds and checking URLs.

Date parsing used L<HTTP::Date>.

=head1 ATTRIBUTES

L<Mojo::Feed> implements the following attributes.

=head2 url

  $feed->url("http://corky.net/dotan/feed/");
  $url = Mojo::URL->new("http://corky.net/dotan/feed/");
  $feed->url($url);
  print $feed->url->path;

A Mojo::URL object from which to fetch an RSS/Atom feed.

=head2 ua

  $feed->ua(Mojo::UserAgent->new());
  $feed->ua->get("http://example.com");

L<Mojo::UserAgent> object used to fetch feeds from the web.


The following attributes are available after the feed has been parsed:

=head2  title

=head2  description 

May be filled from subtitle or tagline if absent

=head2  html_url

web page URL associated with the feed

=head2  items

L<Mojo::Collection> of L<Mojo::Feed::Item> objects representingfeed news items

=head2  subtitle

Optional

=head2  tagline

Optional

=head2  author

Name of author field, or dc:creator or webMaster

=head2  published

Time in epoch seconds (may be filled with pubDate, dc:date, created, issued, updated or modified)


=head1 METHODS

L<Mojo::Feed> inherits all methods from
L<Mojo::Base> and implements the following new ones.

=head2 new

  my $feed = Mojo::Feed->new;
  $feed->parse('atom.xml');

  my $feed = Mojo::Feed->new('atom.xml');
  my $feed = Mojo::Feed->new('http://example.com/atom.xml');
  my $str = Mojo::File->new('atom.xml')->slurp;
  my $feed = Mojo::Feed->new($str);
  my $feed = Mojo::Feed->new(ua => Mojo::UserAgent->new);

Construct a new L<Mojo::Feed> object. If passed a single argument, will call parse() with that argument. Multiple arguments will be used to initialize attributes, as in L<Mojo::Base>.

=head2 discover

  my @feeds;
  Mojo::Feed->discover('search.cpan.org')
            ->then(sub { @feeds = @_; })
            ->wait();
  for my $feed in (@feeds) {
    print $feed . "\n";
  }
  # @feeds is a list of Mojo::URL objects

A Mojo port of L<Feed::Find> by Benjamin Trott. This method implements feed auto-discovery for finding syndication feeds, given a URL.
Returns a Mojo::Promise, which is fulfilled with a list of feeds (Mojo::URL objects)

=head2 parse

  # parse an RSS/Atom feed
  my $url = Mojo::URL->new('http://rss.slashdot.org/Slashdot/slashdot');
  my $feed = Mojo::Feed->new->parse($url);

  # parse a file
  $feed2 = Mojo::Feed->new->parse('/downloads/foo.rss');

  # parse a string
  my $str = Mojo::File->new('atom.xml')->slurp;
  $feed3 = Mojo::Feed->new->parse($str);

A minimalist liberal RSS/Atom parser, using Mojo::DOM queries.

Dates are parsed using L<HTTP::Date>.

C<parse()> will be called by C<new()> if it is passed a single argument


=head2 parse_opml

  my @subscriptions = Mojo::Feed->parse_opml( 'mysubs.opml' );
  foreach my $sub (@subscriptions) {
    say 'RSS URL is: ',     $sub->{xmlUrl};
    say 'Website URL is: ', $sub->{htmlUrl};
    say 'categories: ', join ',', @{$sub->{categories}};
  }

Parse an OPML subscriptions file and return the list of feeds as an array of hashrefs.

Each hashref will contain an array ref in the key 'categories' listing the folders (parent nodes) in the OPML tree the subscription item appears in.

=head1 CREDITS

Dotan Dimet

Mario Domgoergen

Some tests adapted from L<Feed::Find> and L<XML:Feed>, Feed autodiscovery adapted from L<Feed::Find>.



=head1 LICENSE

Copyright (C) Dotan Dimet.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Dotan Dimet E<lt>dotan@corky.netE<gt>

=cut

