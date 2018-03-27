package Mojo::Feed;
use Mojo::Base '-base';

our $VERSION = "0.01";

use Mojo::Feed::Item;
use Mojo::DOM;
use HTTP::Date;
use Scalar::Util 'weaken';

has body => '';

has dom => sub {
  my ($self) = @_;
  my $body = $self->body;
  return if !$body;
  return Mojo::DOM->new($body);
};

my %selector = (
  description => ['description', 'tagline', 'subtitle'],
  published   => [
    'published', 'pubDate', 'dc\:date', 'created',
    'issued',    'updated', 'modified'
  ],
  author   => ['author', 'dc\:creator', 'webMaster'],
  title    => ['title'],
  tagline  => ['tagline'],
  subtitle => ['subtitle'],
  html_url => ['link:not([rel])', 'link[rel=alternate]'],
);

foreach my $k (keys %selector) {
  has $k => sub {
    my $self = shift;
    for my $selector (@{$selector{$k} || [$k]}) {
      if (my $p = $self->dom->at("channel > $selector, feed > $selector")) {
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
  my $self = shift;
  $self->dom->find('item, entry')
    ->map(sub { Mojo::Feed::Item->new(dom => $_, feed => $self) })
    ->each(sub { weaken $_->{feed} });
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

=head2 body

The original decoded string of the feed. 

=head2 dom

The parsed feed as <Mojo::DOM> object.

=head2  title

Returns the feeds title.

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
  my $feed = Mojo::Feed->new( body => $string);

Construct a new L<Mojo::Feed> object.

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

