package Mojo::Feed;
use Mojo::Base '-base';

our $VERSION = "0.01";

use Mojo::Feed::Item;

use Mojo::Util qw(decode);
use Mojo::DOM;
use HTTP::Date;

has default_charset => 'UTF-8';
has charset         => sub { shift->default_charset };

has body => '';

has text => sub {
  my $self    = shift;
  my $body    = $self->body;
  my $charset = $self->charset || $self->default_charset;
  return $charset ? decode($charset, $body) // $body : $body;
};

has dom => sub {
  my ($self) = @_;
  my $text = $self->text;
  return undef unless ($text);
  return Mojo::DOM->new($text);
};

my %selector = (
  description => ['description', 'tagline', 'subtitle'],
  published   => [
    'published', 'pubDate', 'dc\:date', 'created',
    'issued',    'updated', 'modified'
  ],
  author => ['author', 'dc\:creator', 'webmaster'],
  title     => [ 'title' ],
  tagline     => [ 'tagline' ],
  subtitle     => ['subtitle'],
  htmlURL => [ 'link:not([rel])', 'link[rel=alternate]' ],
);

foreach my $k ( keys %selector ) {
  has $k => sub {
    my $self = shift;
    my $channel = shift->dom->at('channel');
    for my $selector (@{$selector{$k} || [$k]}) {
      if ( my $p = $channel->at($selector) ) {
        if ($k eq 'author' && $p->at('name')) {
          return $p->at('name')->text;
        }
        my $text = $p->text || $p->content || $p->attr('href');
        if ($k eq 'published') {
          return str2time($text);
        }
        return $text;
      }
    }
    return;
  };
}

has items => sub {
  shift->dom->find('item, entry')
    ->map(sub { Mojo::Feed::Item->new(dom => $_) });
};

1;
__END__

=encoding utf-8

=for stopwords tagline pubDate dc:date

=head1 NAME

Mojo::Feed - Mojo::DOM-based parsing of RSS & Atom feeds

=head1 SYNOPSIS

    use Mojo::Feed::Reader;
    use Mojo::Feed;

    my $feed = Mojo::Feed::Reader->new->parse("atom.xml");
    print $feed->title, "\n",
      $feed->items->map('title')->join("\n");

    $feed = Mojo::Feed->new( dom => $dom );

=head1 DESCRIPTION

L<Mojo::Feed> is an Object Oriented module for identifying,
fetching and parsing RSS and Atom Feeds.  It relies on
L<Mojo::DOM> for XML/HTML parsing.

Date parsing used L<HTTP::Date>.

=head1 ATTRIBUTES

L<Mojo::Feed> implements the following attributes.

=head2 text
=head2 body
=head2 dom

The following attributes are available after the feed has been parsed:

=head2  title

=head2  description 

May be filled from subtitle or tagline if absent

=head2  html_url

web page URL associated with the feed

=head2  items

L<Mojo::Collection> of L<Mojo::Feed::Item> objects representing feed news items

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

Some tests adapted from L<Feed::Find> and L<XML:Feed>, Feed auto-discovery adapted from L<Feed::Find>.



=head1 LICENSE

Copyright (C) Dotan Dimet.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Dotan Dimet E<lt>dotan@corky.netE<gt>

=cut

