package Mojo::Feed::Item;
use Mojo::Base '-base';
use Mojo::Feed::Item::Enclosure;
use HTTP::Date 'str2time';
has [qw(title link content id description guid published author)];

has tags => sub {
  shift->dom->find('category, dc\:subject')
    ->map(sub { $_[0]->text || $_[0]->attr('term') });
};

has 'dom';

has summary => sub { shift->description };

my %alternatives = (
  content     => ['content\:encoded', 'xhtml\:body', 'description'],
  description => ['summary'],
  published =>
    ['pubDate', 'dc\:date', 'created', 'issued', 'updated', 'modified'],
  author => ['dc\:creator'],
  id     => ['guid', 'link'],
);

sub at_with_namespace {
  my ($self, $field) = @_;
  if (my $p = $self->dom->at($field)) {
    my $tag = $p->tag;
    $tag =~ s/:/\\:/;
    return $p if $tag eq $field;
  }
  return;
}

foreach my $k (qw(title link content id description guid published author)) {
  has $k => sub {
    my $self = shift;
    my @alternatives = @{$alternatives{$k} || []};

    my $p;
    for my $field ($k, @alternatives) {
      $p = $self->at_with_namespace($field);
      last if $p;
    }

    if ($p) {
      if ($k eq 'author' && $p->at('name')) {
        return $p->at('name')->text;
      }
      my $text = $p->text || $p->content;
      if ($k eq 'published') {
        return str2time($text);
      }
      return $text;
    }
    }
}

has enclosures => sub {
  my $self = shift;
  my @enclosures;
  $self->dom->find('enclosure')->each(sub {
    push @enclosures, shift->attr;
  });
  $self->dom->find('link')->each(sub {
    my $l = shift;
    if ($l->attr('href') && $l->attr('rel') && $l->attr('rel') eq 'enclosure') {
      push @enclosures,
        {
        url    => $l->attr('href'),
        type   => $l->attr('type'),
        length => $l->attr('length')
        };
    }
  });
  return Mojo::Collection->new(map { Mojo::Feed::Item::Enclosure->new($_) }
      @enclosures);
};

has link => sub {

  # let's handle links seperately, because ATOM loves these buggers:
  my $link;
  shift->dom->find('link')->each(sub {
    my $l = shift;
    if ($l->attr('href')
      && (!$l->attr('rel') || $l->attr('rel') eq 'alternate'))
    {
      $link = $l->attr('href');
    }
    else {
      if ($l->text =~ /\w+/) {
        $link = $l->text;    # simple link
      }
    }
  });
  return $link;
};

has _raw => sub { shift->dom->to_string };

1;

__END__

=encoding utf-8

=head1 NAME

Mojo::Feed::Item - represents an item from an RSS/Atom feed.

=head1 SYNOPSIS

    use Mojo::Feed;

    my $feed = Mojo::Feed->new("atom.xml");

    my $item = $feed->items->first;

    print $item->title, $item->author, $item->published, "\n";

=head1 DESCRIPTION

L<Mojo::Feed::Item> is an Object wrapper for a item from an RSS or Atom Feed.

=head1 ATTRIBUTES

L<Mojo::Feed::Item> implements the following attributes.

=head2  title

=head2  link

=head2  content

May be filled with C<content:encoded>, C<xhtml:body> or C<description> fields

=head2  id

Will be equal to C<link> or C<guid> if it is undefined and either of those fields exists

=head2  description

Optional - usually a shorter form of the content (may be filled with C<summary> if description is missing)

=head2  guid

Optional

=head2  published

Time in epoch seconds (may be filled with C<pubDate>, C<dc:date>, C<created>, C<issued>, C<updated> or C<modified>)

=head2  author

May be filled from C<author> or C<dc:creator>

=head2  tags

Optional - array ref of C<tags>, C<categories> or C<dc:subjects>.

=head2  _raw

XML serialized text of the item's Mojo::DOM node. Note that this can be different from the original XML text in the feed.

=head2  enclosures

Optional - array ref of enclosures, each a hashref with the keys url, type and length.


=head1 METHODS

L<Mojo::Feed::Item> inherits all methods from L<Mojo::Base>.

=head1 CREDITS

Dotan Dimet

Mario Domgoergen

=head1 LICENSE

Copyright (C) Dotan Dimet.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Dotan Dimet E<lt>dotan@corky.netE<gt>

=cut
