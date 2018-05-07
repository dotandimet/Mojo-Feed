#!/usr/bin/env perl

use lib 'lib';

use Mojo::Feed::Reader;
use Test::More;

my $fdr = Mojo::Feed::Reader->new;
$fdr->ua(Mojo::UserAgent->new->with_roles('+Queued'));
$fdr->ua->max_redirects(5);
my %visited;
$fdr->ua->on(
  start => sub {
    my $tx = pop;
    $visited{$tx->req->url} = 1;
  }
);
my @subs
  = grep { exists $_->{htmlUrl} } $fdr->parse_opml(q{feedbase_hotlist.opml});

plan tests => scalar @subs;
diag "Will run " . scalar(@subs) . " tests\n";

my @promises;
my %tested;
foreach my $sub (@subs) {

  push @promises, $fdr->discover($sub->{htmlUrl})->catch(
    sub {
      my $err = join(', ', @_);
      is(1, 0, ($sub->{htmlUrl} || 'missing_url') . "failed with $err");
    }
  )->then(sub {
    my $feed_url = shift;
    die "No feed found for " . $sub->{htmlUrl} if (not defined $feed_url);
    # normalize urls for comparison:
    my $fixed_feed_url =  $feed_url->to_abs->scheme('http');
    my $listed_feed_url = Mojo::URL->new($sub->{xmlUrl})->scheme('http')->to_abs;
    is($fixed_feed_url, $listed_feed_url, "found feed url for " . $sub->{htmlUrl});
    $tested{$sub->{htmlUrl}} = 1;
  })->catch(
   sub {
        my $err = join(', ', @_);
        is(1, 0, ($sub->{htmlUrl} || 'missing_url') . "failed with $err");
    } 
  );
}

Mojo::Promise->all(@promises)->wait;

my @untested
  = map { $_->{htmlUrl} } grep { !defined $tested{$_->{htmlUrl}} } @subs;

print "Didn't test the following:\n";
print "$_\n" for @untested;
print "Didn't visit the following:\n";
print "$_\n" for (grep { !defined $visited{$_} } @untested);

# handle cases of:
# - spaces/line breaks in link value http://blog.cocoabythefire.com/
# - invalid URL in link value followed by valid url in href (dilbert blog)
