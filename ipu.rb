require_relative 'generator'
require 'logger'

$log = Logger.new("log.txt")

module IPU
end

module IPU::NoticePageExtractors
  def document_rows
    @document.css("table tbody tr")
  end

  def notices
    document_rows.map do |row|
      IPU::Notice.new(row)
    end
  end
end

module IPU::NoticeExtractors
  def extract_date
    @date = DateTime.strptime(@row[1].content, "%d-%m-%Y")
  rescue
    $log.error("Could not extract date")
  end

  def extract_description
    @description = @row[0].content.encode('UTF-8', invalid: :replace, undef: :replace)
  rescue
    @description = "Could not extract description."
    $log.error("Could not extract description")
  end

  def extract_title
    @title = @date.strftime("%a, %d %b %Y")
  rescue
    @title = "Couldn't extract title."
    $log.error("Could not extract title")
  end

  def extract_uri
    @uri = @row.css('a').first['href']
    @uri = "http://ipu.ac.in#{uri}" if (@uri[0] == '/')
  rescue
    $log.error("Could not extract uri")
  end

  def highlight_keywords
    if @keyword_regexes.any? { |regex| @description =~ regex }
      @title = "-> #{@title}"
    end
  end
end

class IPU::NoticePage
  def initialize(uri)
    @uri = uri
    @document = Nokogiri::HTML(open(uri))
  end

  attr_accessor :uri

  include IPU::NoticePageExtractors
end

class IPU::ResultsNoticePage
  def initialize(uri)
    @uri = uri
    @document = Nokogiri::HTML(open(uri))
  end

  attr_accessor :uri

  include IPU::NoticePageExtractors

  def notices
    document_rows.map do |row|
      IPU::ResultsNotice.new(row)
    end
  end
end

class IPU::Notice
  def initialize(row)
    @row = row.css("td")
    @keyword_regexes = [/mca/i, /usict/i]

    extract_date
    extract_title
    extract_description
    extract_uri
    highlight_keywords
  end

  def xml_fragment
    feed_item = RssFeed::Item.new(
      @title,
      @description,
      @date,
      @uri
    )

    feed_item.xml_fragment
  end

  attr_accessor :title, :description, :uri, :date, :row

  private
  include IPU::NoticeExtractors
end

class IPU::ResultsNotice
  def initialize(row)
    @row = row.css("td")
    @keyword_regexes = [/mca/i, /usict/i]

    extract_date
    extract_title
    extract_description
    extract_uri
    highlight_keywords
  end

  def xml_fragment
    feed_item = RssFeed::Item.new(
      @title,
      @description,
      @date,
      @uri
    )

    feed_item.xml_fragment
  end

  attr_accessor :title, :description, :uri, :date, :row

  private
  include IPU::NoticeExtractors

  def extract_date
    date_string = @row[1].content

    @date = DateTime.strptime(
      date_string,
      (date_string =~ /\d\d-\d\d-\d\d$/) ? "%d-%m-%y" : "%d-%m-%Y"
    )
  rescue
    $log.error("Could not extract date")
  end

  def extract_uri
    uri = @row.css('a').first['href']
    @uri = "http://164.100.158.135/#{uri}"
  rescue
    $log.error("Could not extract uri")
  end
end

class IPU::Feed
  def initialize
    @uris = [
      "http://ipu.ac.in/notices.php",
      "http://ipu.ac.in/exam_notices.php",
      "http://ipu.ac.in/exam_datesheet.php",
      "http://ipu.ac.in/exam_results.php"
    ]

    @results_uri = "http://164.100.158.135/ExamResults/ExamResultsmain.htm"
  end

  def to_xml
    threads = @uris.map do |page|
      Thread.new { IPU::NoticePage.new(page) }
    end

    threads.push(Thread.new { IPU::ResultsNoticePage.new(@results_uri) })

    threads.each { |t| t.join }

    notices = threads
      .map { |t| t.value }
      .map { |page| page.notices }
      .reduce(&:+)

    notices.reject! { |notice| notice.date.nil? }
    notices.sort_by! { |notice| notice.date }.reverse!
    notices.uniq! { |notice| notice.uri }

    notices = notices.take(1000)

    metadata = RssFeed::Metadata.new(
      "IPU Notices / Circulars",
      "Aggregate RSS feed of circulars uploaded to various ipu websites.",
      "http://prajjwal.com",
      "http://rss.prajjwal.com/ipu.xml"
    )

    RssFeed::Feed.new(notices, metadata).to_xml
  end
end

puts IPU::Feed.new.to_xml
