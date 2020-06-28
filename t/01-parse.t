use Mojo::Base -strict;

use Test::More;
use Mojo::URL;
use Mojo::File qw(path);
use HTTP::Date qw(time2isoz);
use Mojolicious;
use FindBin;
use Mojo::Feed;
use Mojo::Feed::Reader;


my $app = Mojolicious->new;
$app->ua->server->app($app); # self-referntiality!
$app->log->level('fatal');

my $sample_dir = path($FindBin::Bin, 'samples');
push @{$app->static->paths}, $sample_dir;

$app->routes->get(
  '/plasm' => sub {
    shift->render(
      data   => path($sample_dir, 'plasmastrum.xml')->slurp,
      format => 'htm'
    );
  }
);

$app->routes->get(
  '/feed' => sub {
    shift->redirect_to('atom.xml');
  }
);

# test the parse_feed helper.

# tests lifted from XML::Feed

## First, test all of the various ways of calling parse.

# File:
subtest(
  'file' => sub {
    my $file = path($sample_dir, 'atom.xml');
    my $feed = Mojo::Feed::Reader->new->parse($file);
    isa_ok($feed, 'Mojo::Feed');
    is($feed->title,    'First Weblog',           'title ok');
    is($feed->subtitle, 'This is a test weblog.', 'tagline/subtitle');
    is($feed->source,   $file,                    'source ok');
    done_testing();
  }
);

# parse a string
subtest(
  'string' => sub {
    my $str  = path($sample_dir, 'atom.xml')->slurp;
    my $feed = Mojo::Feed->new(body => $str);
    isa_ok($feed, 'Mojo::Feed');
    is($feed->title, 'First Weblog', 'title ok');
    ok(!$feed->source, 'feed created from string has no source');
    done_testing();
  }
);

# parse a URL
subtest(
  'url' => sub {
    plan tests => 3;
    my $feed = Mojo::Feed::Reader->new->ua($app->ua)
      ->parse(Mojo::URL->new("/atom.xml"));
    isa_ok($feed, 'Mojo::Feed');
    is($feed->title,        'First Weblog', 'title ok');
    is($feed->source->path, '/atom.xml',    'source ok');
  }
);

# parse a URL with a redirect
subtest(
  'URL with redirect' => sub {
    plan tests => 3;
    my $feed = Mojo::Feed::Reader->new->ua($app->ua)
      ->parse(Mojo::URL->new("/feed"));
    isa_ok($feed, 'Mojo::Feed', 'got feed on redirect');
    is($feed->title,        'First Weblog', 'title ok');
    is($feed->source->path, 'atom.xml',     'source changed on redirect');
  }
);

## Callback and non-blocking no longer supported - how do we make a promise API?

subtest(
  'All attributes',
  sub {
    my $feedr = Mojo::Feed::Reader->new;
    ## Then try calling all of the unified API methods.
    my %Feeds = (
      'atom.xml'  => 'Atom',
      'rss10.xml' => 'RSS 1.0',
      'rss20.xml' => 'RSS 2.0',
    );

    for my $file (sort keys %Feeds) {
      my $path = path($FindBin::Bin, 'samples', $file);
      my $feed = $feedr->parse($path) or die "parse feed returned undef";

      #is($feed->format, $Feeds{$file});
      #is($feed->language, 'en-us');
      is($feed->title,       'First Weblog');
      is($feed->link,        'http://localhost/weblog/');
      is($feed->description, 'This is a test weblog.');
      my $dt = $feed->published;

      # isa_ok($dt, 'DateTime');
      #  $dt->set_time_zone('UTC');
      ok(defined($feed->published), 'feed published defined');
      is(time2isoz($dt), '2004-05-30 07:39:57Z');
      is($feed->author, 'Melody', 'feed author');

      my $entries = $feed->items;
      is(scalar @$entries, 2);
      my $entry = $entries->[0];
      is($entry->title, 'Entry Two');
      is($entry->link,  'http://localhost/weblog/2004/05/entry_two.html');

      #     $dt = $entry->issued;
      #     isa_ok($dt, 'DateTime');
      #     $dt->set_time_zone('UTC');
      #say "Raw Entry: ", $entry->{'_raw'};
      #say join q{,}, sort keys %$entry;
      ok(defined $entry->published, 'has pubdate');
      is(time2isoz($entry->published), '2004-05-30 07:39:25Z');
      like($entry->content, qr/<p>Hello!<\/p>/);
      is($entry->description, 'Hello!...');
      is($entry->tags->[0],   'Travel');
      is($entry->author,      'Melody', 'entry author');

      # no id if no id in feed - just link
      ok($entry->id);

      is($entry->feed, $feed, 'reference for feed');
      undef $feed;
      ok(!$entry->feed, 'weak reference for feed');
    }
    done_testing();
  }
);

subtest(
  'summary vs content',
  sub {
    plan tests => 1;
    my $feedr = Mojo::Feed::Reader->new;
    my $feed = $feedr->parse(path($sample_dir, 'rss20.xml'))
      or die "parse fail";
    my $entry = $feed->items->[0];
    ok(
      $entry->summary ne $entry->content,
      'description and content are different'
    );
  }
);

subtest(
  'summary fallback',
  sub {
    plan tests => 2;
    my $feedr = Mojo::Feed::Reader->new;
    my $feed = $feedr->parse(path($sample_dir, 'rss20-no-summary.xml'))
      or die "parse fail";
    my $entry = $feed->items->[0];
    ok($entry->summary eq $entry->content,
      'no summary use content/description');
    like($entry->content, qr/<p>This is a test.<\/p>/);
  }
);

subtest(
  'invalid dates',
  sub {
    plan tests => 3;
    my $feedr = Mojo::Feed::Reader->new;
    my $feed = $feedr->parse(path($sample_dir, 'rss10-invalid-date.xml'))
      or die "parse fail";
    my $entry = $feed->items->[0];
    ok(!$entry->{issued});       ## Should return undef, but not die.
    ok(!$entry->{modified});     ## Same.
    ok(!$entry->{published});    ## Same.
  }
);

subtest(
  'summary vs. itunes summary',
  sub {
    plan tests => 3;
    my $feedr = Mojo::Feed::Reader->new;
    my $feed = $feedr->parse(path($sample_dir, 'itunes_summary.xml'))
      or die "parse failed";
    my $entry = $feed->items->[0];
    isnt($entry->summary, 'This is for &8220;itunes sake&8221;.');
    is($entry->description, 'this is a <b>test</b>');
    is($entry->content,     '<p>This is more of the same</p>');
  }
);

subtest(
  'author vs itunes:author',
  sub {
    plan tests => 2;

# does the order of the tags change which one we pick?
    my $feedr = Mojo::Feed::Reader->new;
    my $feed = $feedr->parse(path($sample_dir, 'itunes_author_order.xml'))
      or die "parse failed";
    is(
      $feed->items->[0]->author,
      'webmaster@kcrw.org (KCRW, Elvis Mitchell)',
      'author not itunes:author'
    );
    is(
      $feed->items->[1]->author,
      'webmaster@kcrw.org (KCRW, Elvis Mitchell)',
      'author not itunes:author, despite order'
    );
  }
);

# Let's do some errors - trying to parse html responses, basically
subtest(
  'HTMl is invalid',
  sub {
    plan tests => 5;
    my $feed
      = Mojo::Feed->new(body => $app->ua->get('/link1.html')->res->body);
    ok(!$feed->is_valid, "feed is not valid");
    is(scalar $feed->items->each, 0,     'no entries from html page');
    is($feed->title,              undef, 'no title from html page');
    is($feed->description,        undef, 'no description from html page');
    is($feed->link,               undef, 'no link from html page');
  }
);

# Invalid input:
subtest(
  'garbage XML is invalid',
  sub {
    plan tests => 2;
    my $feedr = Mojo::Feed::Reader->new;
    my $feed = $feedr->parse("<xml><garbage>this is invalid</garbage></xml>");
    is($feed, undef, "invalid feed not defined");
    ok(!exists $feed->{items}, 'no entries from dummy xml');
  }
);

# encoding issue when reading utf-8 text from file vs. from URL:
subtest(
  'encoding issue (file vs. URL)' => sub {
    my $feedr = Mojo::Feed::Reader->new;
    my $feed_from_file = $feedr->parse(path($sample_dir, 'plasmastrum.xml'));
    my $tx             = $app->ua->get('/plasmastrum.xml');
    my $feed_from_tx
      = Mojo::Feed::Reader->new->ua($app->ua)->parse($tx->res->body);
    my $feed_from_url = Mojo::Feed::Reader->new->ua($app->ua)
      ->parse(Mojo::URL->new('/plasmastrum.xml'));

    # feed served as HTML:
    my $feed_from_url2 = Mojo::Feed::Reader->new->ua($app->ua)
      ->parse(Mojo::URL->new('/plasm'));

    for my $i (5, 7, 24) {
      is(
        $feed_from_file->items->[$i]->title,
        $feed_from_tx->items->[$i]->title,
        'encoding check'
      );
      is(
        $feed_from_file->items->[$i]->title,
        $feed_from_url->items->[$i]->title,
        'encoding check'
      );
      is(
        $feed_from_file->items->[$i]->title,
        $feed_from_url2->items->[$i]->title,
        'encoding check'
      );
    }
  }
);
done_testing();
