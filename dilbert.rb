require_relative 'generator'
require 'mechanize'

module Dilbert
end

class Dilbert::Date
  @@base_uri = "http://dilbert.com/strip"

  def initialize(date)
    @date = date
  end

  def hyphenated_date
    @date.strftime("%Y-%m-%d")
  end

  def uri
    @date.strftime("#{@@base_uri}/#{hyphenated_date}")
  end

  def strftime(format)
    @date.strftime(format)
  end
end

class Dilbert::Comic
  def initialize(date)
    @date = Dilbert::Date.new(date)
    @uri = @date.uri
    @agent = Mechanize.new
    @page = @agent.get(@uri)
    @title = @page.search("span.comic-title-name").text
    @image_uri = @page.image_with(class: /img-comic/).uri.to_s

    @feed_item = RssFeed::Item.new(
      @title,
      "<![CDATA[<p><img src='#{@image_uri}'</p>]]>",
      @date,
      @uri
    )
  end

  def xml_fragment
    @feed_item.xml_fragment
  end
end

class Dilbert::Feed
  def initialize(count)
    @metadata = RssFeed::Metadata.new(
      "Dilbert Comics",
      "Custom RSS Feed",
      "http://dilbert.com",
      "http://rss.prajjwal.com/dilbert.xml",
    )

    @agent = Mechanize.new
    @count = count
    @comics = []
    @rss_feed = nil

    scrape_comics
  end

  attr_accessor :count, :comics

  # When count changes, scrape comics again.
  def count=(count)
    @count = count
    scrape_comics
  end

  def to_xml
    @rss_feed.to_xml
  end

  private
  def scrape_comics
    # TODO: Refactor this into Dilbert::Comic
    latest_comic = @agent.get('http://dilbert.com/')
    latest_comic_link = latest_comic.link_with(class: /comic-title-link/)
    latest_comic_date = parse_date_string(
      date_string(latest_comic_link.uri)
    )

    dates = []

    @count.times do
     dates.push(latest_comic_date)

     latest_comic_date = latest_comic_date.prev_day
    end

    @comics = dates.map { |date| Dilbert::Comic.new(date) }
    @rss_feed = RssFeed::Feed.new(@comics, @metadata)
  end

  def date_string(uri)
    uri.to_s[-10..-1]
  end

  def parse_date_string(date_string)
    DateTime.strptime(date_string, "%Y-%m-%d")
  end
end

puts Dilbert::Feed.new(10).to_xml
