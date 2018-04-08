#!/usr/bin/env perl

use lib 'lib';

use Mojo::Feed::Reader;
use Test::More;

my $fdr = Mojo::Feed::Reader->new;
$fdr->ua(Mojo::UserAgent->new->with_roles('+Queued'));
$fdr->ua->max_redirects(5);
my %visited;
$fdr->ua->on(start => sub {
    my $tx = pop;
    $visited{$tx->req->url} = 1;
});
my @subs = $fdr->parse_opml(q{feedbase_hotlist.opml});

plan tests => scalar @subs;
diag "Will run " . scalar(@subs) . " tests\n";

my @promises;
my %tested;
foreach my $sub (@subs) {
   push @promises,
   $fdr->discover($sub->{htmlUrl})->then(sub { 
   my $feed_url = shift;
   is($feed_url, $sub->{xmlUrl}, "found feed url");
   $tested{ $sub->{htmlUrl} } = 1;
})
}

Mojo::Promise->all(@promises)->wait;

my @untested = map { $_->{htmlUrl} } grep { ! defined $tested{$_->{htmlUrl}} } @subs;

print "Didn't test the following:\n";
print "$_\n" for @untested;
print "Didn't visit the following:\n";
print "$_\n" for (grep { ! defined $visited{$_} } @untested);
