# Adapted from a failing test in hadashot:
use Mojolicious::Lite;

use Test::More;

use Mojo::Feed;

plan tests => 1;    # but a good one

get '/' => sub { shift->render( text => "Hello!" ) };

my $fr = Mojo::Feed->new();
$fr->ua->max_redirects(5);
$fr->discover("http://corky.net")->then(sub { my ($feed) = @_;
my $res = $fr->parse($feed);
is( $res->title, 'קורקי.נט aggregator' );
})->wait;
