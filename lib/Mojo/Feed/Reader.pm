package Mojo::Feed::Reader;
use Mojo::Base -base;

use Mojo::UserAgent;
use Mojo::Feed;
use Mojo::File 'path';
use Mojo::Util 'decode', 'trim';
use Carp qw(carp croak);
use Scalar::Util qw(blessed);

# feed mime-types:
our @feed_types = (
    'application/x.atom+xml', 'application/atom+xml',
    'application/xml',        'text/xml',
    'application/rss+xml',    'application/rdf+xml'
);
our %is_feed = map { $_ => 1 } @feed_types;

has ua            => sub { Mojo::UserAgent->new };
has charset       => 'UTF-8';
has max_redirects => sub { $ENV{MOJO_MAX_REDIRECTS} || 0 };

sub parse {
    my ( $self, $xml, $charset ) = @_;
    return undef unless ($xml);
    my ( $body, $source, $url, $file );
    my %args;
    $args{'charset'} = $charset if ($charset);
    $body = $self->_from_string($xml) || undef;
    if ( !$body && ( $file = $self->_from_file($xml) ) ) {
        $body = $file->slurp;
    }
    if ( !$body && ( $url = $self->_from_url($xml) ) ) {
        ( $body, $charset, $url ) = $self->load($url); # url might change by redirect
    }
    croak "unknown argument $xml" unless ($body);
    $charset ||= $self->charset;
    $source = $url || $file;
    my $feed =
      Mojo::Feed->new( body => $body, charset => $charset, source => $source );
    return ( $feed->is_valid ) ? $feed : undef;
}

sub _from_string {
    my ( $self, $xml ) = @_;
    my $str = ( !ref $xml ) ? $xml : ( ref $xml eq 'SCALAR' ) ? $$xml : '';
    return ( $str =~ /^\s*\</s ) ? $str : undef;
}

sub _from_url {
    my ( $self, $xml ) = @_;
    my $url =
        ( blessed $xml && $xml->isa('Mojo::URL') ) ? $xml->clone()
      : ( $xml =~ /^https?\:/ ) ? Mojo::URL->new("$xml")
      :                           undef;
    return $url;
}

sub _from_file {
    my ( $self, $xml ) = @_;
    my $file =
        ( ref $xml )
      ? ( blessed $xml && $xml->can('slurp') )
          ? $xml
          : undef
      : ( -r "$xml" ) ? Mojo::File->new($xml)
      :                 undef;
    return $file;
}

sub load {
    my ( $self, $url ) = @_;
    my $tx     = $self->ua->get($url);
    my $result = $tx->result;            # this will croak on network errors
    if ( $result->is_error ) {
        croak "Error getting feed from url ", $url, ": ", $result->message;
    }
    elsif ( $result->code == 301 || $result->code == 302 ) {
        my $new_url = Mojo::URL->new( $result->headers->location );
        return ( $self->load($new_url) );
    }
    return ( $result->body, $result->content->charset, $url );
}

# discover - get RSS/Atom feed URL from argument.
# Code adapted to use Mojolicious from Feed::Find by Benjamin Trott
# Any stupid mistakes are my own
sub discover {
    my ( $self, $url ) = @_;

    #  $self->ua->max_redirects(5)->connect_timeout(30);
    return $self->ua->get_p($url)
      ->catch( sub { my ($err) = shift; croak "Connection Error: $err" } )
      ->then(
        sub {
            my ($tx) = @_;
            if ( $tx->res->is_success && $tx->res->code == 200 ) {
                return $self->_find_feed_links( $tx->req->url, $tx->res );
            }
            return;
        }
      );
}

sub _find_feed_links {
    my ( $self, $url, $res ) = @_;

    state $feed_exp = qr/((\.(?:rss|xml|rdf)$)|(\/feed\/)|(feeds*\.))/;
    my @feeds;

    # use split to remove charset attribute from content_type
    my ($content_type) = split( /[; ]+/, $res->headers->content_type );
    if ( $is_feed{$content_type} ) {
        push @feeds, Mojo::URL->new($url)->to_abs;
    }
    else {
        # we are in a web page. PHEAR.
        my $base = Mojo::URL->new(
                 $res->dom->find('head base')->map( 'attr', 'href' )->join('')
              || $url )->to_abs($url);
        my $title =
          $res->dom->find('head > title')->map('text')->join('') || $url;
        $res->dom->find('head link')->each(
            sub {
                my $attrs = $_->attr();
                return unless ( $attrs->{'rel'} );
                my %rel = map { $_ => 1 } split /\s+/, lc( $attrs->{'rel'} );
                my $type = ( $attrs->{'type'} ) ? lc trim $attrs->{'type'} : '';
                if ( $is_feed{$type}
                    && ( $rel{'alternate'} || $rel{'service.feed'} ) )
                {
                    push @feeds,
                      Mojo::URL->new( $attrs->{'href'} )->to_abs($base);
                }
            }
        );
        $res->dom->find('a')->grep(
            sub {
                $_->attr('href')
                  && $_->attr('href') =~ /$feed_exp/io;
            }
        )->each(
            sub {
                push @feeds, Mojo::URL->new( $_->attr('href') )->to_abs($base);
            }
        );

        # call me crazy, but maybe this is just a feed served as HTML?
        unless (@feeds) {
            if ( $self->parse( $res->body, $res->content->charset ) ) {
                push @feeds, Mojo::URL->new($url)->to_abs;
            }
        }
    }
    return @feeds;
}

sub parse_opml {
    my ( $self, $opml_file ) = @_;
    my $opml_str = decode $self->charset,
      ( ref $opml_file )
      ? $opml_file->slurp
      : Mojo::File->new($opml_file)->slurp;
    my $d = Mojo::DOM->new->parse($opml_str);
    my ( %subscriptions, %categories );
    for my $item ( $d->find(q{outline})->each ) {
        my $node = $item->attr;
        if ( !defined $node->{xmlUrl} ) {
            my $cat = $node->{title} || $node->{text};
            $categories{$cat} =
              $item->children('[xmlUrl]')->map( 'attr', 'xmlUrl' );
        }
        else {    # file by RSS URL:
            $subscriptions{ $node->{xmlUrl} } = $node;
        }
    }

    # assign categories
    for my $cat ( keys %categories ) {
        for my $rss ( $categories{$cat}->each ) {
            next
              unless ( $subscriptions{$rss} )
              ;    # don't auto-vivify for empty "categories"
            $subscriptions{$rss}{'categories'} ||= [];
            push @{ $subscriptions{$rss}{'categories'} }, $cat;
        }
    }
    return ( values %subscriptions );
}

1;
__END__

=encoding utf-8

=for stopwords tagline pubDate dc:date

=head1 NAME

Mojo::Feed::Reader - Fetch feeds

=head1 SYNOPSIS

    use Mojo::Feed::Reader;

    my $feedr = Mojo::Feed::Reader->new( ua => $ua );
    my $feed = $feedr->parse("atom.xml");
    print $feed->title, "\n",
      $feed->items->map('title')->join("\n");

    # Feed discovery (returns a Promise):
    $feedr->discover("search.cpan.org")->then(sub {
      my (@feeds) = @_;
      if (@feeds) {
        print $_ for (@feeds);
      }
    })->catch(sub { die "Error: ", @_; });

   # 

=head1 DESCRIPTION

L<Mojo::Feed::Reader> is an Object Oriented module for identifying,
fetching and parsing RSS and Atom Feeds.  It relies on
L<Mojo::DOM> for XML/HTML parsing and L<Mojo::UserAgent>
for fetching feeds and checking URLs.

=head1 ATTRIBUTES

L<Mojo::Feed::Reader> implements the following attributes.

=head2 ua

  $feed->ua(Mojo::UserAgent->new());
  $feed->ua->get("http://example.com");

L<Mojo::UserAgent> object used to fetch feeds from the web.

=head1 METHODS

L<Mojo::Feed::Reader> inherits all methods from
L<Mojo::Base> and implements the following new ones.

=head2 new

Construct a new L<Mojo::Feed::Reader> object.

=head2 discover

  my @feeds;
  Mojo::Feed::Reader->new->discover('search.cpan.org')
            ->then(sub { @feeds = @_; })
            ->wait();
  for my $feed in (@feeds) {
    print $feed . "\n";
  }
  # @feeds is a list of Mojo::URL objects

A Mojo port of L<Feed::Find> by Benjamin Trott. This method implements feed
auto-discovery for finding syndication feeds, given a URL.
Returns a Mojo::Promise, which is fulfilled with a list of feeds (Mojo::URL
objects)

=head2 parse

  my $feedr = Mojo::Feed::Reader->new;
  # parse an RSS/Atom feed
  my $url = Mojo::URL->new('http://rss.slashdot.org/Slashdot/slashdot');
  my $feed = $feedr->parse($url);

  # parse a file
  $feed2 = $feedr->new->parse('/downloads/foo.rss');

  # parse a string
  my $str = Mojo::File->new('atom.xml')->slurp;
  $feed3 = $feedr->parse($str);

A minimalist liberal RSS/Atom parser, using Mojo::DOM queries.

If the parsed object is not a feed (for example, the parser was given an HTML page),
the method will return undef.

=head2 parse_opml

  my @subscriptions = Mojo::Feed::Reader->new->parse_opml( 'mysubs.opml' );
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

Mario Domgoergen

=cut

1;
