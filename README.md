[![Build Status](https://travis-ci.org/dotandimet/Mojo-Feed.svg?branch=master)](https://travis-ci.org/dotandimet/Mojo-Feed)
# NAME

Mojo::Feed - Mojo::DOM-based parsing of RSS & Atom feeds

# SYNOPSIS

    use Mojo::Feed::Reader;
    use Mojo::Feed;

    my $feed = Mojo::Feed::Reader->new->parse("atom.xml");
    print $feed->title, "\n",
      $feed->items->map('title')->join("\n");

    $feed = Mojo::Feed->new( dom => $dom );

# DESCRIPTION

[Mojo::Feed](https://metacpan.org/pod/Mojo::Feed) is an Object Oriented module for identifying,
fetching and parsing RSS and Atom Feeds.  It relies on
[Mojo::DOM](https://metacpan.org/pod/Mojo::DOM) for XML/HTML parsing.

Date parsing used [HTTP::Date](https://metacpan.org/pod/HTTP::Date).

# ATTRIBUTES

[Mojo::Feed](https://metacpan.org/pod/Mojo::Feed) implements the following attributes.

## body

The original decoded string of the feed.

## dom

The parsed feed as <Mojo::DOM> object.

## source

The source of the feed; either a [Mojo::Path](https://metacpan.org/pod/Mojo::Path) or [Mojo::URL](https://metacpan.org/pod/Mojo::URL) object, or
undef if the feed source was a string scalar.

## title

Returns the feeds title.

## description 

May be filled from subtitle or tagline if absent

## html\_url

web page URL associated with the feed

## items

[Mojo::Collection](https://metacpan.org/pod/Mojo::Collection) of [Mojo::Feed::Item](https://metacpan.org/pod/Mojo::Feed::Item) objects representing feed news items

## subtitle

Optional feed description

## tagline

Optional feed description

## author

Name of author field, or dc:creator or webMaster

## published

Time in epoch seconds (may be filled with pubDate, dc:date, created, issued, updated or modified)

# METHODS

[Mojo::Feed](https://metacpan.org/pod/Mojo::Feed) inherits all methods from
[Mojo::Base](https://metacpan.org/pod/Mojo::Base) and implements the following new ones.

## new

    my $feed = Mojo::Feed->new;
    my $feed = Mojo::Feed->new( body => $string);

Construct a new [Mojo::Feed](https://metacpan.org/pod/Mojo::Feed) object.

# CREDITS

Dotan Dimet

Mario Domgoergen

Some tests adapted from [Feed::Find](https://metacpan.org/pod/Feed::Find) and [XML:Feed](XML:Feed), Feed auto-discovery adapted from [Feed::Find](https://metacpan.org/pod/Feed::Find).

# LICENSE

Copyright (C) Dotan Dimet.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Dotan Dimet <dotan@corky.net>

Mario Domgoergen
