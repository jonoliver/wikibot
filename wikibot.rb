require 'nokogiri'
require 'erb'
require 'byebug'

class Article
  attr_reader :url

  def initialize response
    lines = response.split("\n")
    @url = lines.pop
    @doc = Nokogiri.parse(lines.join '')
  end

  def title
    @doc.css('#firstHeading').text
  end

  def summary
    content = @doc.css('#mw-content-text>p').first
    content.xpath("./*[contains(@class, 'reference')]").remove
    return content.text unless content.nil?
    ""
  end

  def image
    img = @doc.css('.infobox img').first
    return img.attr('src') unless img.nil?
    ""
  end

  def random_link
    random_link = links.sample
    random_link
  end

  def links
    link_nodes = @doc.css('#bodyContent a').select{|a| validate_link a}
    link_nodes.map{|a| format_link a.attr('href')}.uniq
  end

  private

    def validate_link a
      href = a.attr('href')
      href.start_with?('/wiki/') &&
      !href.include?(':') &&
      !href.include?('Main_Page')
    end

    def format_link link
      link.sub(/^\/wiki\//, '').sub(/\#.*/, '').sub('(', '%28').sub(')', '%29')
    end
end

class ConsoleRenderer
  def initialize articles
    @articles = articles
  end

  def render
    2.times{ puts "" }
    @articles.each{|article| render_article article }
  end

  private

  def render_article article
    puts article.title.upcase
    puts article.summary
    puts article.url
    # puts article.image
    puts ''
  end
end
class HtmlRenderer
  def initialize articles
    @articles = articles
  end
  def render
    file = 'index.html'
    content = ERB.new(template).result(binding)
    File.write(file, content)
    `open #{file}`
  end
  def template
%{
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Randomizer</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://fonts.googleapis.com/css?family=Lora" rel="stylesheet">
    <style>
      body {
        font-family: Lora,serif;
        line-height: 1.6;
        background: #e2e2e2;
        padding: 0;
        margin: 0;
      }
      main {
        background: #FFF;
        padding: 20px;
      }
      a {
        color: #000;
        text-decoration: none;
        padding-bottom: .3em;
      }
      a:hover {
        color: #5d5d5d;
        border-bottom: 1px solid #5d5d5d;
      }
      hr {
        border: none;
        border-bottom: 1px solid #e2e2e2;
      }
      @media (min-width: 700px) {
        main {
          max-width: 700px;
          margin: 0 auto;
        }
      }
    </style>
  </head>
  <body>
    <main>
      <% @articles.each do |article| %>
        <h1><a href="<%= article.url %>"><%= article.title %></a></h1>
        <p><%= article.summary %></p>
        <img src="https:<%= article.image %>"></img>
        <hr />
      <% end %>
    </main>
  </body>
</html>
}
  end
end
class Crawler
  WIKI_ROOT = "https://en.wikipedia.org/wiki/"
  WIKI_RANDOM = "#{WIKI_ROOT}Special:Random"

  def initialize options
    @options = options
    @iterations = options[:iterations]
    @renderer = options[:renderer]
    @articles = []
  end

  def run url=nil
    print '.'
    response = `curl -Ls -w %{url_effective} #{url || WIKI_RANDOM}`
    article = Article.new response

    @articles << article
    if keep_going?
      if @options[:rlyrandom]; run
      else run "#{WIKI_ROOT}#{article.random_link}"
      end
    end
  end

  private
    def keep_going?
      @iterations = @iterations - 1 and return true if @iterations > 1
      @iterations = @options[:iterations]
      finish
      false
    end

    def finish
      @renderer.new(@articles).render
    end
end


require 'optparse'

options = {
  iterations: 20,
  renderer: ConsoleRenderer
}
OptionParser.new do |opts|
  opts.banner = "Usage: wikibot.rb [options] [url]"

  opts.on("-r", "--[no-]rlyrandom", "Really Really Random") do |v|
    options[:rlyrandom] = v
  end
  opts.on("-t N", "--total N", Integer, "Return N articles") do |v|
    options[:iterations] = v
  end
  opts.on("-b", "--browse", "Open results in browser (prints to console by default)") do |v|
    options[:renderer] = HtmlRenderer
  end
  # opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
  #   options[:verbose] = v
  # end
end.parse!

p options

puts 'Fetching some articles, hang tight!'
crawler = Crawler.new options
crawler.run ARGV[0]
