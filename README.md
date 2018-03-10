[![Build Status](https://travis-ci.org/dotandimet/Mojo-Feed.svg?branch=master)](https://travis-ci.org/dotandimet/Mojo-Feed)
# NAME

Mojo::Feed - Mojo::DOM-based parsing of RSS & Atom feeds

# SYNOPSIS

     use Mojo::Feed;

     my $feed = Mojo::Feed->new("atom.xml");
     print $feed->title, "\n",
       $feed->items->map('title')->join("\n");

     # Feed discovery (returns a Promise):
     Mojo::Feed->discover("search.cpan.org")->then(sub {
       my (@feeds) = @_;
       if (@feeds) {
         print $_->url for (@feeds);
       }
     })->catch(sub { die "Error: ", @_; });

    # 

# DESCRIPTION

[Mojo::Feed](https://metacpan.org/pod/Mojo::Feed) is an Object Oriented module for identifying,
fetching and parsing RSS and Atom Feeds.  It relies on
[Mojo::DOM](https://metacpan.org/pod/Mojo::DOM) for XML/HTML parsing and [Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent)
for fetching feeds and checking URLs.

Date parsing used [HTTP::Date](https://metacpan.org/pod/HTTP::Date).

# ATTRIBUTES

[Mojo::Feed](https://metacpan.org/pod/Mojo::Feed) implements the following attributes.

## url

    $feed->url("http://corky.net/dotan/feed/");
    $url = Mojo::URL->new("http://corky.net/dotan/feed/");
    $feed->url($url);
    print $feed->url->path;

A Mojo::URL object from which to fetch an RSS/Atom feed.

## ua

    $feed->ua(Mojo::UserAgent->new());
    $feed->ua->get("http://example.com");

[Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent) object used to fetch feeds from the web.

The following attributes are available after the feed has been parsed:

## title

## description 

May be filled from subtitle or tagline if absent

## html\_url

web page URL associated with the feed

## items

[Mojo::Collection](https://metacpan.org/pod/Mojo::Collection) of [Mojo::Feed::Item](https://metacpan.org/pod/Mojo::Feed::Item) objects representingfeed news items

## subtitle

Optional

## tagline

Optional

## author

Name of author field, or dc:creator or webMaster

## published

Time in epoch seconds (may be filled with pubDate, dc:date, created, issued, updated or modified)

# METHODS

[Mojo::Feed](https://metacpan.org/pod/Mojo::Feed) inherits all methods from
[Mojo::Base](https://metacpan.org/pod/Mojo::Base) and implements the following new ones.

## new

    my $feed = Mojo::Feed->new;
    $feed->parse('atom.xml');

    my $feed = Mojo::Feed->new('atom.xml');
    my $feed = Mojo::Feed->new('http://example.com/atom.xml');
    my $str = Mojo::File->new('atom.xml')->slurp;
    my $feed = Mojo::Feed->new($str);
    my $feed = Mojo::Feed->new(ua => Mojo::UserAgent->new);

Construct a new [Mojo::Feed](https://metacpan.org/pod/Mojo::Feed) object. If passed a single argument, will call parse() with that argument. Multiple arguments will be used to initialize attributes, as in [Mojo::Base](https://metacpan.org/pod/Mojo::Base).

## discover

    my @feeds;
    Mojo::Feed->discover('search.cpan.org')
              ->then(sub { @feeds = @_; })
              ->wait();
    for my $feed in (@feeds) {
      print $feed . "\n";
    }
    # @feeds is a list of Mojo::URL objects

A Mojo port of [Feed::Find](https://metacpan.org/pod/Feed::Find) by Benjamin Trott. This method implements feed auto-discovery for finding syndication feeds, given a URL.
Returns a Mojo::Promise, which is fulfilled with a list of feeds (Mojo::URL objects)

## parse

    # parse an RSS/Atom feed
    my $url = Mojo::URL->new('http://rss.slashdot.org/Slashdot/slashdot');
    my $feed = Mojo::Feed->new->parse($url);

    # parse a file
    $feed2 = Mojo::Feed->new->parse('/downloads/foo.rss');

A minimalist liberal RSS/Atom parser, using Mojo::DOM queries.

Dates are parsed using [HTTP::Date](https://metacpan.org/pod/HTTP::Date).

If parsing fails (for example, the parser was given an HTML page), the method will return undef.

## parse\_opml

    my @subscriptions = Mojo::Feed->parse_opml( 'mysubs.opml' );
    foreach my $sub (@subscriptions) {
      say 'RSS URL is: ',     $sub->{xmlUrl};
      say 'Website URL is: ', $sub->{htmlUrl};
      say 'categories: ', join ',', @{$sub->{categories}};
    }

Parse an OPML subscriptions file and return the list of feeds as an array of hashrefs.

Each hashref will contain an array ref in the key 'categories' listing the folders (parent nodes) in the OPML tree the subscription item appears in.

# CREDITS

Dotan Dimet

Mario Domgoergen

Some tests adapted from [Feed::Find](https://metacpan.org/pod/Feed::Find) and [XML:Feed](XML:Feed), Feed autodiscovery adapted from [Feed::Find](https://metacpan.org/pod/Feed::Find).

# LICENSE

Copyright (C) Dotan Dimet.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Dotan Dimet <dotan@corky.net>
