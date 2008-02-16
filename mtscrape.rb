#!/usr/bin/ruby
#
# == Synopsis
#
# mtscrape: parse and download streams of ZDF.de Mediathek
#
# == Usage
#
# mtscrape [OPTIONS] [SOURCES]
#
#  The following OPTIONS can be specified:
#
#   -a, --age       Maximum age of feed item
#   -c, --convert   Convert wmv to ogg/theora
#   -d, --dir       Output directory
#   -f, --fast      Stream low-quality (faster)
#   -m, --match     Regular expression to match against items
#   -h, --help      This help text
#   -v, --verbose   Verbose output
#
#  Note: -a and -m are only used in combination with -C
#        -f is not used in combination with -A
#
#  The following SOURCES can be specified:
#
#   -A, --asx       Parse ASX link/file directly
#   -C, --category  Parse RSS feed of mediathek category ID
#   -I, --item      Parse JSON of mediathek item ID
#   -L, --link      Parse JSON of mediathek link
#
#  Note: you can specify all sources multiple times to download multiple items.
#
# == Examples
#
# This command will download the item with ID 257404 (heute 100sec, 15.10.07):
#
#   mtscrape -v -I 257404
#
# Same file as above, but using the ASX file directly (easier to find in the webinterface):
#
#  mtscrape -v -A http://wstreaming.zdf.de/zdf/veryhigh/071015_hko_2000.asx
#
# Same file as above, but using the HTTP link directly (easier to find in the RSS feed):
#
#  mtscrape -v -L http://www.zdf.de/ZDFmediathek/content/heute_100SEC/166/257404
#
# This will stream all items from category 208 (JBK) and 414 (Maybritt Illner)
# since one week ago into directory /data/talkshows/:
#
#   mtscrape -v -a 7 -d /data/talkshows -C 208 -C 414
#
# This will stream all items from category ID 228 (heute) since yesterday whose
# title matches the regular expression '.*heute-journal.*':
#
#   mtscrape -v -a 1 -C 228 -m '.*heute-journal.*'
#
# == Bugs
#
# This script will not work with livestreams. mtscrape has been designed for
# automatic download of ondemand content, but downloading (parts) of the
# livestream requires manual work (i.e. stoping the recording) and is therefore
# not implemented in this script.
#
# In fact, mtscrape even prevents livestreams from being downloaded if they appear
# in the RSS feeds.
#
# To dump the livestream you can use mplayer directly:
#
#   mplayer \
#      -playlist http://wgeostreaming.zdf.de/encoder/livestream15_vh.asx \
#      -dumpstream \
#      -dumpfile zdf_stream.wmv
#
# == Requirements
#
# To use this script you need the following software installed on your system:
#
#   - Ruby-1.8.x (apt-get install ruby1.8 rubygems, emerge ruby, etc)
#   - Ruby-JSON (gem install json)
#   - LibXML-Ruby (gem install libxml-ruby)
#   - mplayer (apt-get install mplayer, emerge mplayer, etc)
#   - ffmpeg2theora (only for --convert)
#
# == License
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.
#
# == Copyright
#
# 2007 Benedikt Boehm <hollow@gentoo.org>
#
# == ChangeLog
#
#  - Oct 26 2007: add --convert (v0.2)
#  - Oct 15 2007: initial release (v0.1)

require 'rubygems'
require 'date'
require 'getoptlong'
require 'json' # gem install json
require 'open-uri'
require 'rdoc/usage'
require 'rss/1.0'
require 'rss/2.0'
require 'xml/libxml' # gem install libxml-ruby

@age     = Time.now - (5 * 24 * 3600)
@convert = false
@bw      = 'dsl2000'
@dir     = '.'
@filter  = nil
@verbose = false

@asxs  = []
@cats  = []
@items = []
@links = []

opts = GetoptLong.new(
  [ '--age',      '-a', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--convert',  '-c', GetoptLong::NO_ARGUMENT ],
  [ '--dir',      '-d', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--fast',     '-f', GetoptLong::NO_ARGUMENT ],
  [ '--match',    '-m', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--help',     '-h', GetoptLong::NO_ARGUMENT ],
  [ '--verbose',  '-v', GetoptLong::NO_ARGUMENT ],

  [ '--asx',      '-A', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--category', '-C', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--item',     '-I', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--link',     '-L', GetoptLong::REQUIRED_ARGUMENT ]
)

def mt_parse_asx(link)
  data = ""
  open(link) do |s| data = s.read end
  XML::Parser.string(data).parse.root.find('Entry').first.find('Ref').first['href']
end

def mt_stream_url(link)
  data = ""
  open("#{link}?&bw=#{@bw}&pp=wmp&view=navJson") do |s| data = s.read end
  json = JSON.parse(data)
  return "INVALID:#{json['assetType']}" if json['assetType'] != "video"
  mt_parse_asx(json['assetUrl'])
end

@spinner = [ '-', '\\', '|', '/' ]

def wait(pid)
  if @verbose
    i = 0
    while Process::waitpid(pid, Process::WNOHANG) == nil
      print "\b#{@spinner[i]}"
      STDOUT.flush
      i = (i + 1) % 4
      sleep 0.05
    end

    puts "\b\b."
  else
    Process::waitpid(pid, 0)
  end
end

def dump_stream(url)
  match = /^INVALID:(.*)/.match(url)
  if match
    puts "[skip] this looks like a #{match[1]} source"
    return
  end

  basename = url.split("/").last
  outfile  = "#{@dir}/#{basename}"
  system("mkdir -p #{@dir}")

  begin File::Stat.new(outfile)
    puts "[skip] File already exists (#{outfile})" if @verbose
  rescue
    cmd = "mplayer -nolirc -really-quiet -dumpstream -dumpfile '#{outfile}' '#{url}'"
    print "[dump] #{url} -> #{outfile}  " if @verbose
    wait(fork do system(cmd) end)
    convert_stream(outfile) if @convert
  end
end

def convert_stream(file)
  print "[conv] #{file}  " if @verbose
  wait(fork do system("ffmpeg2theora '#{file}'") end)
end

opts.each do |opt, arg|
  case opt
  when '--age'
    @age = Time.now - (arg.to_i * 24 * 3600)
  when '--convert'
    @convert = true
  when '--dir'
    @dir = arg
  when '--fast'
    @bw = 'dsl1000'
  when '--match'
    @filter = Regexp.new(arg, true, 'u')
  when '--player'
    if ['wmp','qtp'].include?(arg)
      @player = arg
    else
      raise "Wrong --player, supported players: wmp, qtp"
    end
  when '--help'
    RDoc::usage
    exit 0
  when '--verbose'
    @verbose = true

  when '--asx'
    @asxs << arg
  when '--category'
    @cats << arg.to_i
  when '--item'
    @items << arg.to_i
  when '--link'
    @links << arg
  end
end

@asxs.each do |asx|
  dump_stream(mt_parse_asx(asx))
end

@cats.each do |cat|
  rss = RSS::Parser.parse("http://www.zdf.de/ZDFmediathek/content/#{cat}?view=rss")
  rss.items.each do |item|
    if item.date >= @age
      puts "[test] #{item.title}" if @verbose
      match = @filter.nil? ? true : item.title =~ @filter
      dump_stream(mt_stream_url(item.link)) if match
    end
  end
end

@items.each do |item|
  dump_stream(mt_stream_url("http://www.zdf.de/ZDFmediathek/content/#{item}"))
end

@links.each do |link|
  dump_stream(mt_stream_url(link))
end
