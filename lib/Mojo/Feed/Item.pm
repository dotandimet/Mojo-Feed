package Mojo::Feed::Item;
use Mojo::Base '-base';
has [qw(title link content id description guid published author _raw)];
has tags => sub { [] };

sub summary { return shift->description }

1;
