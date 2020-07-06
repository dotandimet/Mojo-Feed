package Mojo::Feed::Item::Atom;
use Mojo::Base 'Mojo::Feed::Item';

1;

__END__

=encoding utf-8

=head1 NAME

Mojo::Feed::Item::Atom - represents an item from an Atom 1 feed.

=head1 SYNOPSIS

    use Mojo::Feed;

    my $feed = Mojo::Feed::Atom->new("atom.xml");

    my $item = $feed->entries->first;

    print $item->title, $item->author, $item->published, "\n";

=head1 DESCRIPTION

L<Mojo::Feed::Item::Atom> is an Object wrapper for a entry from an RSS or Atom Feed.

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

=head2  enclosures

Optional - array ref of enclosures, each a hashref with the keys url, type and length.

=head2  feed

A reference to the feed this item belongs to. Note that this is a weak
reference, so it maybe undefined, if the parent feed is no longer in scope.

=head1 METHODS

L<Mojo::Feed::Item> inherits all methods from L<Mojo::Base> and adds the following ones:

=head2 to_hash

  my $hash = $item->to_hash;
  print $hash->{title};

Return a hash reference representing the item.

=head2 to_string

Return a XML serialized text of the item's Mojo::DOM node. Note that this can be different from the original XML text in the feed.

=head1 CREDITS

Dotan Dimet

Mario Domgoergen

=head1 LICENSE

Copyright (C) Dotan Dimet.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Dotan Dimet E<lt>dotan@corky.netE<gt>

Mario Domgoergen

=cut
