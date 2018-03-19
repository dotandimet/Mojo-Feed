# Adapted from a failing test in hadashot:
use Mojo::Base -strict;
use Test::More;
use Mojo::Feed::Reader;

my $fr = Mojo::Feed::Reader->new;
$fr->ua->max_redirects(5);
$fr->discover("http://corky.net")->then(sub {
  my ($url) = @_;
  my $feed = $fr->parse($url);
  is($feed->title, 'קורקי.נט aggregator');
})->catch(sub { die @_ })->wait;

done_testing;
