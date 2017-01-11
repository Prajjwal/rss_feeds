require 'nokogiri'
require 'uri'
require 'open-uri'
require 'date'
require 'digest/sha1'

module RssFeed
end

class RssFeed::Metadata
  def initialize(title, description, link, alink)
    @title = title
    @description = description
    @link = link
    @alink = alink
  end

  attr_accessor :title, :description, :link, :alink

  def xml_fragment
    Nokogiri::XML::DocumentFragment.parse <<-EOXML
    <title>#{@title}</title>
    <description>#{@description}</description>
    <link>#{@link}</link>
    <atom:link href="#{@alink}" rel="self" type="application/rss+xml" />
    EOXML
  end
end

class RssFeed::Item
  def initialize(title, description, datetime, uri)
    @title = title
    @description = description
    @date = datetime.strftime("%a, %d %b %Y %H:%M:%S %z")
    @uri = uri
  end

  attr_accessor :title, :description, :date, :uri

  def xml_fragment
    Nokogiri::XML::DocumentFragment.parse <<-EOXML
    <item>
      <title>#{@title}</title>
      <description>#{@description}</description>
      <pubDate>#{@date}</pubDate>
      <link>#{@uri}</link>
      <guid isPermaLink="false">#{guid}</guid>
    </item>
    EOXML
  end

  private
  def guid
    Digest::SHA1.hexdigest(@title + @description + @date + @uri)
  end
end

class RssFeed::Feed
  def initialize(items, metadata)
    @items = items
    @metadata = metadata
  end

  def to_xml
    rss = Nokogiri::XML::Document.parse <<-EOXML
    <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
    <channel>
    </channel>
    </rss>
    EOXML

    rss.encoding = "UTF-8"
    channel =  rss.xpath("//channel").first

    channel.add_child(@metadata.xml_fragment)

    @items.each do |item|
      channel.add_child(item.xml_fragment)
    end

    rss.to_xml
  end
end

def smoke_test
  items = [
    RssFeed::Item.new("Cat", "Dog", DateTime.now, "http://prajjwal.com"),
    RssFeed::Item.new("Cat", "Dog", DateTime.now, "http://prajjwal.com"),
    RssFeed::Item.new("Cat", "Dog", DateTime.now, "http://prajjwal.com"),
    RssFeed::Item.new("Cat", "Dog", DateTime.now, "http://prajjwal.com"),
    RssFeed::Item.new("Cat", "Dog", DateTime.now, "http://prajjwal.com")
  ]

  metadata = RssFeed::Metadata.new(
    "Title",
    "Description",
    "Link",
    "Alink"
  )

  RssFeed::Feed.new(items, metadata).to_xml
end
