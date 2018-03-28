package Mojo::Feed::Item::Enclosure;
use Mojo::Base -base;

has [qw( url type length )];

sub to_hash {
    return { map { $_ => '' . ($_[0]->$_ || '') } (qw(url type length))}
}


1;
