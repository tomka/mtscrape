#!/usr/bin/python
# vim: set fileencoding=utf8

import os, sys, subprocess, time, datetime
import re, urllib, feedparser, json
from xml.dom import minidom
from optparse import OptionParser, make_option
import logging as log

__author__ = "Benedikt Böhm"
__copyright__ = "Copyright (c) 2007-2010 Benedikt Böhm <bb@xnull.de>"
__version__ = 0,3

OPTION_LIST = [
  make_option(
    "-a", "--age",
    dest = "age",
    type = "int",
    default = 5,
    metavar = "DAYS",
    help = "maxmimum age of feed item in days"),
  make_option(
    "-c", "--convert",
    dest = "convert",
    action = "store_true",
    default = False,
    help = "convert wmv/mov to ogg/theora"),
  make_option(
    "-d", "--dir",
    dest = "dir",
    type = "string",
    default = ".",
    metavar = "PATH",
    help = "output directory"),
  make_option(
    "-f", "--fast",
    dest = "fast",
    action = "store_true",
    default = False,
    help = "stream low-quality movies (faster)"),
  make_option(
    "-m", "--match",
    dest = "match",
    type = "string",
    default = "",
    metavar = "PATTERN",
    help = "regular expression to match against feed items"),
  make_option(
    "-v", "--verbose",
    dest = "verbose",
    action = "store_true",
    default = False,
    help = "verbose output"),
  make_option(
    "-A", "--asx",
    dest = "asx",
    action = "append",
    default = [],
    metavar = "URL",
    help = "Parse ASX link/file directly"),
  make_option(
    "-C", "--category",
    dest = "cat",
    action = "append",
    default = [],
    metavar = "ID",
    help = "Parse RSS feed of mediathek category"),
  make_option(
    "-I", "--item",
    dest = "item",
    action = "append",
    default = [],
    metavar = "ID",
    help = "Parse JSON of mediathek item ID"),
  make_option(
    "-L", "--link",
    dest = "link",
    action = "append",
    default = [],
    metavar = "URL",
    help = "Parse JSON of mediathek link"),
]

def run_wait(cmd, options):
  spinner = ['-', '\\', '|', '/' ]
  proc = subprocess.Popen(cmd)

  if options.verbose:
    pos = 0
    while proc.poll() == None:
      sys.stdout.write("\b" + spinner[pos])
      sys.stdout.flush()
      time.sleep(0.05)
      pos = (pos + 1) % len(spinner)

    sys.stdout.write("\b\b.\n")
    sys.stdout.flush()
  else:
    proc.wait()

def mt_parse_asx(url):
  dom = minidom.parseString(urllib.urlopen(url).read())
  return dom.getElementsByTagName("Ref")[0].getAttribute("href")

def mt_stream_url(url, options):
  try:
    url.index('?')
    url = url + '&'
  except ValueError:
    url = url + '?'

  url = url + 'flash=off'

  log.debug('scraping URL %s' % (url,))
  dom = minidom.parseString(urllib.urlopen(url).read())

  for a in dom.getElementsByTagName('a'):
    href = a.getAttribute('href')
    if href.find('streaming.zdf.de') > 0 and href.endswith('.asx'):
      if options.fast and href.find('zdf/300/') > 0:
        return mt_parse_asx(href)
      if not options.fast and href.find('zdf/veryhigh/') > 0:
        return mt_parse_asx(href)

def convert_stream(file):
  if options.verbose:
    sys.stdout.write("[conv] %s  " % (file,))
    run_wait(["ffmpeg2theora", file], options)

def dump_stream(url, options):
  if url.startswith("INVALID:"):
    print "[skip] this looks like a %s source" % (url.replace("INVALID:",""))
    return

  basename = url.split("/")[-1]
  outfile = os.path.join(options.dir, basename)
  if not os.path.exists(options.dir):
    os.makedirs(options.dir)

  if os.path.exists(outfile):
    print "[skip] file already exists (%s)" % (outfile,)
    return

  if options.verbose:
    sys.stdout.write("[dump] %s -> %s ." % (url, outfile))
    run_wait(["mplayer", "-nolirc", "-really-quiet", "-dumpstream", "-dumpfile", outfile, url], options)

  if options.convert:
    convert_stream(outfile)

def main():
  log.basicConfig(filename='/dev/stderr', level=log.DEBUG)

  version = ".".join(map(str, __version__))
  parser = OptionParser(option_list=OPTION_LIST,version="%prog " + version)
  (options, args) = parser.parse_args()

  for asx in options.asx:
    dump_stream(mt_parse_asx(asx), options)

  for cat in options.cat:
    rss = feedparser.parse("http://www.zdf.de/ZDFmediathek/rss/%s?view=rss" % (cat,))
    age = datetime.datetime.now() - datetime.timedelta(days=options.age)
    for item in rss['items']:
      if datetime.datetime(*item.updated_parsed[:6]) >= age:
        if options.verbose:
          print "[test] " + item.title
        if re.search(options.match, item.title):
          dump_stream(mt_stream_url(item.link, options), options)

  for item in options.item:
    dump_stream(mt_stream_url("http://www.zdf.de/ZDFmediathek/beitrag/video/" + item, options), options)

  for link in options.link:
    dump_stream(mt_stream_url(link, options), options)

  sys.exit(0)

if __name__ == "__main__":
  main()
