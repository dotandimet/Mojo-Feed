#!/usr/bin/env perl

use Mojo::Base -strict;

use Mojo::Feed::Reader;
use Mojo::File qw(path);

package Mojo::Feed::Role::FeedType;
use Mojo::Base -role;

has feed_type => sub {
  my $top     = shift->dom->children->first;
  my $tag     = $top->tag;
  my $version = $top->attr('version');
  return
      ($tag =~ /feed/i) ? 'atom'
    : ($tag =~ /rss/i)  ? 'rss ' . $version
    : ($tag =~ /rdf/i)  ? 'rss 1.0'
    :                     'unknown';
};

package main;

my $mfr
  = Mojo::Feed::Reader->new->_feed_class(Mojo::Feed->with_roles("+FeedType"));

for my $file (path(q{t/samples})->list()->grep(sub { "$_" =~ /xml$/ })->each) {
  my $feed = $mfr->parse($file);
  next unless ($feed);
  say $feed->source, "\t", $feed->feed_type;
}

package Mojo::Feed::Item::Role::ReEnclosure; # re-implement enclosures as role
use Mojo::Base -role;

has re_enclosures => sub {
    my $self = shift;
    my @enclosures;
  $self->dom->find('enclosure')->each(sub {
    push @enclosures, $_;
  });
  $self->dom->find('link')->each(sub {
    my $l = shift;
    if ($l->attr('href') && $l->attr('rel') && $l->attr('rel') eq 'enclosure') {
      push @enclosures, $l;
    }
  });
  return Mojo::Collection->new(
    map { Mojo::Feed::Item::Enclosure->new(dom => $_) } @enclosures);
 
};

package Mojo::Feed::Role::ReEnclosed;
use Mojo::Base -role;

has _item_class => sub { Mojo::Feed::Item->with_roles('+ReEnclosure') };

package main;


use Mojo::Base -strict;

use Test::More;
use Mojo::File 'path';
use Mojo::Feed::Reader;

use FindBin;

my %test_results = (
  'rss20-multi-enclosure.xml' => [
    {
      'length' => '2478719',
      'type'   => 'audio/mpeg',
      'url'    => 'http://example.com/sample_podcast.mp3'
    },
    {
      'length' => '8888',
      'type'   => 'video/mpeg',
      'url'    => 'http://example.com/sample_movie.mpg'
    }
  ],
  'atom-multi-enclosure.xml' => [
    {
      'length' => '2478719',
      'type'   => 'audio/mpeg',
      'url'    => 'http://example.com/sample_podcast.mp3'
    },
    {
      'length' => '8888',
      'type'   => 'video/mpeg',
      'url'    => 'http://example.com/sample_movie.mpg'
    }
  ],
  'atom-enclosure.xml' => [{
    'length' => '2478719',
    'type'   => 'audio/mpeg',
    'url'    => 'http://example.com/sample_podcast.mp3'
  }],
  'rss20-enclosure.xml' => [{
    'length' => '2478719',
    'type'   => 'audio/mpeg',
    'url'    => 'http://example.com/sample_podcast.mp3'
  }],
);

my $samples = path('t')->child('samples');

my $feedr = Mojo::Feed::Reader->new(_feed_class => Mojo::Feed->with_roles('+ReEnclosed'));

while (my ($file, $result) = each %test_results) {
  my $feed = $feedr->parse($samples->child($file));
  is_deeply($feed->items->[0]->re_enclosures->map('to_hash'), $result);
}

done_testing();
