use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use Mojo::File 'path';
use Mojo::Feed;
use Mojolicious::Lite;

use FindBin;

my $t = Test::Mojo->new(app);
push @{ app->static->paths }, path($FindBin::Bin)->child('samples');

my $reader = Mojo::Feed->new( ua => $t->app->ua );
my $feed;

# parse a URL
$feed = $reader->parse( Mojo::URL->new("/atom.xml") );
is( $feed->title, 'First Weblog' );

done_testing();
