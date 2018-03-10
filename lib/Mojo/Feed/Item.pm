package Mojo::Feed::Item;
use Mojo::Base '-base';
has [qw(title link content id description guid published author _raw)];
has tags => sub { [] };

sub summary { return shift->description }

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

May be filled with content:encoded, xhtml:body or description fields

=head2  id

Will be equal to link or guid if it is undefined and either of those fields exists

=head2  description

Optional - usually a shorter form of the content (may be filled with summary if description is missing)

=head2  guid

Optional

=head2  published

Time in epoch seconds (may be filled with pubDate, dc:date, created, issued, updated or modified)

=head2  author

May be filled from author or dc:creator

=head2  tags

Optional - array ref of tags, categories or dc:subjects.

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
