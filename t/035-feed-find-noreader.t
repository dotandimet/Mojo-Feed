use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use FindBin;
use Mojo::File qw(path);

use Mojolicious::Lite;

use Mojo::Feed;

get '/floo' => sub { shift->redirect_to('/link1.html'); };

my $samples = path( $FindBin::Bin, 'samples' );
push @{ app->static->paths }, $samples;
get '/olaf' => sub {
    shift->render(
        data =>
           path( $samples, 'atom.xml' )->slurp,
        format => 'html'
    );
};
get '/monks' => sub {
    shift->render(
        data =>
          path( $samples, 'perlmonks.html' )->slurp,
        format => 'htm'
    );
};
get '/wp' => sub {
    shift->render(
        data => '<html><a href="http://feed.dummy.com">subscribe</a> for updates</html>',
        format => 'html'
    );
};

get '/' => sub {
    my $self = shift;
    if ($self->param('feed') eq 'rss2') {
        $self->redirect_to('rss20.xml');
    }
    elsif ($self->param('feed') eq 'rss') {
        $self->redirect_to('rss10.xml');
    }
    elsif ($self->param('feed') eq 'atom') {
        $self->redirect_to('atom.xml');
    }
    else {
        $self->reply->not_found();
    }
};

my $t            = Test::Mojo->new(app);

sub abs_url {
return $t->ua->server->url->clone->path($_[0])->to_abs;
};

my $abs_feed_url = abs_url('atom.xml');

# feed

# (Mojo::URL, abs)
$t->get_ok('/atom.xml')->status_is(200);
my $feed = Mojo::Feed->new(ua => $t->ua, url => abs_url('/atom.xml'));
is($feed->title, 'First Weblog', 'load ok'); # load it
is( $feed->url, $abs_feed_url, 'Mojo::URL (abs) ok' );    # abs url!

# not a Mojo::URL:
$feed = Mojo::Feed->new(ua => $t->ua, url => "" . abs_url('/atom.xml'));
is($feed->title, 'First Weblog', 'load ok'); # load it
is( $feed->url, $abs_feed_url , "string URL (abs) ok");    # abs url!

# Just a relative URL::
$feed = Mojo::Feed->new(ua => $t->ua, url => '/atom.xml');
is($feed->title, 'First Weblog', 'load ok'); # load it
is( $feed->url, '/atom.xml', 'relative string URL ok' );    # relative url!


# link
$t->get_ok('/link1.html')->status_is(200);
$feed = Mojo::Feed->new(ua => $t->ua, url => abs_url('/link1.html'));
is($feed->title, 'First Weblog', 'load ok'); # load it
is( $feed->url, $abs_feed_url, 'link) ok' );    # abs url!

# html page with multiple feed links
$t->get_ok('/link2_multi_rel.html')->status_is(200);
$feed = Mojo::Feed->new(ua => $t->ua, url => '/link2_multi_rel.html');
is($feed->title, 'First Weblog', 'load ok'); # load it
is( $feed->url, abs_url('/rss20.xml'), 'link multi ok' );    # abs url!
my @feeds = @{$feed->related};
is( scalar @feeds, 2, 'got 2 additional feed links' );
is( $feeds[0], abs_url('/')->query(feed=>'rss') );     # abs url!
is( $feeds[1], abs_url('/')->query(feed=>'atom') );    # abs url!

done_testing();
__END__

# feed is in link:
# also, use base tag in head - for pretty url
$t->get_ok('/link3_anchor.html')->status_is(200);
$feedr->discover('/link3_anchor.html')->then(sub{ (@feeds) = @_ })->wait;
is( $feeds[0], 'http://example.com/foo.rss' );
is( $feeds[1], 'http://example.com/foo.xml' );

@feeds = ();
$feedr->discover( '/link2_multi.html' )->then(sub{ (@feeds) = @_ })->wait;
is( scalar @feeds, 3 );
is( $feeds[0],     'http://www.example.com/?feed=rss2' );    # abs url!
is( $feeds[1],     'http://www.example.com/?feed=rss' );     # abs url!
is( $feeds[2],     'http://www.example.com/?feed=atom' );    # abs url!

# Let's try something with redirects:
$t->get_ok('/floo')->status_is(302);
$feedr->discover('/floo')->then(sub{ (@feeds) = @_ })->wait;
is( $feeds[0], undef, 'default UA does not follow redirects' )
  ;    # default UA doesn't follow redirects!
$feedr->ua->max_redirects(3);
$feedr->discover('/floo')->then(sub{ (@feeds) = @_ })->wait;
is( $feeds[0], $abs_feed_url, 'found with redirect' );    # abs url!

# what do we do on a page with no feeds?
$t->get_ok('/no_link.html')->status_is(200);
$feedr->discover('/no_link.html')->then(sub{ (@feeds) = @_ })->wait;
is( scalar @feeds, 0, 'no feeds' );
say "feed: $_" for (@feeds);

# a feed with an incorrect mime-type:
$t->get_ok('/olaf')->status_is(200)
  ->content_type_like( qr/^text\/html/, 'feed served as html' );
$feedr->discover('/olaf')->then(sub{ (@feeds) = @_ })->wait;
is( scalar @feeds, 1 );
is( Mojo::URL->new( $feeds[0] )->path, '/olaf', 'feed served as html' );


@feeds = ();

$feedr->discover( '/no_link.html' )->then(sub{ (@feeds) = @_ })->wait;
is( scalar @feeds, 0, 'no feeds (nb)' );

@feeds = ();
$feedr->discover('/monks')->then(sub{ (@feeds) = @_ })->wait;
is( scalar @feeds, 0, 'no feeds for perlmonks' );
@feeds = ();
$feedr->discover( '/monks')->then(sub{ (@feeds) = @_ })->wait;
is( scalar @feeds, 0, 'no feeds for perlmonks (nb)' );

# why just an extension? look for the word "feed" somewhere in the url
@feeds=();
$feedr->discover('/wp')->then(sub { @feeds = @_ })->wait;
is($feeds[0], 'http://feed.dummy.com', 'promising url title');

# @feeds = ();
# $delay = Mojo::IOLoop->delay(sub { shift; (@feeds) = @_; });
# $t->app->find_feeds('slashdot.org', $delay->begin(0));
# $delay->wait();
# is(scalar @feeds, 1, 'feed for slashdot');
# @feeds = ();
# @feeds = $t->app->find_feeds('slashdot.org');
# is(scalar @feeds, 1, 'feed for slashdot');

done_testing();
