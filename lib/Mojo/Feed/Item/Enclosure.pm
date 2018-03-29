package Mojo::Feed::Item::Enclosure;
use Mojo::Base -base;

has 'dom';

has length => sub { shift->dom->attr('length'); };
has type   => sub { shift->dom->attr('type'); };
has url => sub { my $attr = shift->dom->attr; $attr->{url} || $attr->{href} };

sub to_hash {
  return {map { $_ => $_[0]->$_ } (qw(length type url))};
}

sub to_string {
  shift->dom->to_string;
}

1;
