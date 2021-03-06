========
mtscrape
========

:Author: `Benedikt Böhm <bb@xnull.de>`_
:Version: 0.2
:Web: http://github.com/hollow/mtscrape
:Git: ``git clone https://github.com/hollow/mtscrape.git``
:Download: http://github.com/hollow/mtscrape/downloads

Rationale
=========

In 2007, the public broadcasting services in Germany started their online
portal for on-demand content. Users can now watch all broadcastings without
license restrictions for (at least) 7 days after their original transmission.

Unfortunately, the only available formats are WMV and MOV, and therefore users
of free software are forced to use the VLC browser plugin, which does not
support pausing the stream, is awfully slow, and generally sucks.

To rectify this situation, mtscrape can save and convert these streams.

Usage
=====
::

  mtscrape [OPTIONS] [SOURCES]

  Options:
    -a, --age       Maximum age of feed item
    -c, --convert   Convert wmv to ogg/theora
    -d, --dir       Output directory
    -f, --fast      Stream low-quality (faster)
    -m, --match     Regular expression to match against items
    -h, --help      This help text
    -v, --verbose   Verbose output

  Sources:
    -A, --asx       Parse ASX link/file directly
    -C, --category  Parse RSS feed of mediathek category ID
    -I, --item      Parse JSON of mediathek item ID
    -L, --link      Parse JSON of mediathek link

Note: ``-a`` and ``-m`` are only used in combination with ``-C``. ``-f`` is not
used in combination with ``-A``.

Note: you can specify all sources multiple times to download multiple items.

Examples
========

This command will download the item with ID 257404 (heute 100sec, 15.10.07):
::

  mtscrape -v -I 257404

Same file as above, but using the ASX file directly (easier to find in the webinterface):
::

  mtscrape -v -A http://wstreaming.zdf.de/zdf/veryhigh/071015_hko_2000.asx

Same file as above, but using the HTTP link directly (easier to find in the RSS feed):
::

  mtscrape -v -L http://www.zdf.de/ZDFmediathek/content/heute_100SEC/166/257404

This will stream all items from category 208 (JBK) and 414 (Maybritt Illner)
since one week ago into directory ``/data/talkshows/``:
::

  mtscrape -v -a 7 -d /data/talkshows -C 208 -C 414

This will stream all items from category ID 228 (heute) since yesterday whose
title matches the regular expression '.*heute-journal.*':
::

  mtscrape -v -a 1 -C 228 -m '.*heute-journal.*'

Bugs
====

This script will not work with livestreams. mtscrape has been designed for
automatic download of ondemand content, but downloading (parts) of the
livestream requires manual work (i.e. stoping the recording) and is therefore
not implemented in this script.

In fact, mtscrape even prevents livestreams from being downloaded if they
appear in the RSS feeds.

To dump the livestream you can use mplayer directly:
::

  mplayer \
    -playlist \
    http://wgeostreaming.zdf.de/encoder/livestream15_vh.asx \
    -dumpstream \
    -dumpfile zdf_stream.wmv

Requirements
============

To use this script you need the following software installed on your system:

- Ruby-1.8.x (apt-get install ruby1.8 rubygems, emerge ruby, etc)
- Ruby-JSON (gem install json)
- LibXML-Ruby (gem install libxml-ruby)
- mplayer (apt-get install mplayer, emerge mplayer, etc)
- ffmpeg2theora (only for --convert)
