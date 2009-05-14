# F.A.T. LAB
# KANYE WEB TOOLS
# RANT DETECTOR 1.0
#
# SUBJECT'S ALLCAPS BLOG POSTS ALERTED TO TWITTER <HTTP://TWITTER.COM/KANYERANTS>
# JAMIE DUBS <HTTP://JAMIEDUBS.COM>

# YEEZY'S RSS DOES NOT CONTAIN FULLTEXT 
# WHICH WOULD HAVE MADE THIS MAD EASIER

require 'rubygems'
require 'yaml'
require 'mechanize' # FOR PARSING KANYEBLOG
require 'open-uri' # FOR BIT.LY MAGIC
require 'twitter' # FOR SHOUTING LOUDLY
require 'sequel' # FOR STORING FOUND RANTS
require 'logger' # FOR CHOPPING WOOD
require 'cgi' # FOR CGI.escape -_-


# MIN RANTITTUDE -- AVOID FALSE POSITIVES
MINIMUM_RANT_LENGTH = 500


# WAS THIS TEXT WRITTEN BY KANYE? Y/N
def kanye?(text)
  return text == text.upcase
end

# CONVENIENCE IS KING
class String
  def strip_html
    self.gsub(/(<[^>]*>)|\n|\t/s, '')
  end
end

# SHORTEN A URL USING BIT.LY
def bitlyfy(url)
  url = CGI.escape(url)
  return open("http://bit.ly/api?url=#{url}", "UserAgent" => "KANYE RANT DETECTOR <http://fffff.at>").read
end

# POST SOMETHING
def announce(msg, url)
  
  text = "\"#{msg}\": #{url}"
  puts "ANNOUNCE: #{text}"
  @config ||= YAML.load(File.open('config.yml'))
  raise "No config file!" if @config.blank?

  # post to twitter...
  httpauth = Twitter::HTTPAuth.new(@config['username'], @config['password'])
  twitter = Twitter::Base.new(httpauth)
  twitter.update(text)
    
end


# SAVE TO SQLITE
def save(body, excerpt, url, shorturl, time = DateTime.now)

  rants = DB[:rants]
  rows = rants.where(:url => url)
  
  if rows.blank? || rows.first.nil?
    puts "NO RECORD! INSERTING NEW..."
    return rants.insert(:body => body, :excerpt => excerpt, :url => url, :shorturl => shorturl, :created_at => time)
  else
    puts "RECORD ALREADY EXISTS => #{rows.first.inspect}"
    return false # could not save, already exists
  end
end



# ------ WORK IT GIRL --------

STDERR.puts "INITIALIZING DATABASE..."


# INITIALIZE OUR RANTERBASE
DB = Sequel.sqlite 'kanyerants.db'
unless DB.table_exists?(:rants)
  DB.create_table :rants do
    primary_key :id
    String :url
    String :shorturl
    String :body
    String :excerpt
    DateTime :created_at
  end
end


# url = "http://www.kanyeuniversecity.com/blog/"
# page w/ yesterday's twitter rant
# url = "http://www.kanyeuniversecity.com/blog/?em3106=0_-1__-1_~0_-1_5_2009_0_10&em3298=&em3282=&em3281=&em3161="

# last page...
base = "http://www.kanyeuniversecity.com/blog/"
url = "#{base}?em3106=0_-1__-1_~0_-1_5_2009_0_4820&em3298=&em3282=&em3281=&em3161="
# REBOOT -> Last page
# url = "http://www.kanyeuniversecity.com/blog/?em3106=0_-1__-1_~0_-1_5_2009_0_4820&em3298=&em3282=&em3281=&em3161="

STDERR.puts "CONTACTING INTERNETS... #{url}"
agent = WWW::Mechanize.new
# agent.user_agent = "KANYE RANT DETECTOR <http://fffff.at>"
agent.user_agent_alias = "Mac Safari"
page = agent.get(url)

# FOR PROPER ARCHIVAL
reverse_pagination = true

# DETECT KANYES GOGOGOGO
first = 0 # GETS OVERRIDDEN
loop {
  # IN REVERSE MODE...
  (page/'.rapper').to_a.reverse.each { |post|

    content = post.content.strip!
    excerpt = post.content[0..120].gsub("\n",'').gsub("\t",'').strip!

    links = (post/'a')
    permalink = "#{base}#{links[0]['href']}"
    text = (post/'h5').first.content.strip_html
    # puts "PROCESSING: #{excerpt}"
    # puts "#{permalink}"

    # FOUND A SHORTCUT: ONLY RANTS ARE IN SPECIFIED ELEMENT
    content = (post/'h5 div').first.content rescue ''

    # TELL THE MAFACKIN WORLD
    # BONUS: DO IT WITH AUTOTUNE
    if !content.empty? && content.length > MINIMUM_RANT_LENGTH
      shorturl = bitlyfy(permalink)

      # ONLY ANNOUNCE ON SUCCESFUL SAVE TO DB
      announce(excerpt, shorturl) if save(content, excerpt, permalink, shorturl)
      puts ""
    
      sleep 3
    
    end
    
  }

  # RECURSE PAGES... THEY POST A LOT
  current = (page/'#emodpages strong')[1].content.to_i
  first = current if first == 0
  # puts "current = #{current.inspect} -- first = #{first.inspect}"
  prev = (page/'#emodpages a').select { |e| e.content.strip_html.to_i == (reverse_pagination ? current - 1 : current + 1) }
  if prev.blank? or prev.first.nil?
    STDERR.puts "No prev link!"
    break
  end
  
  sleep 1
  link = prev.first
  pagenum = link.content.strip_html.to_i
  if pagenum.blank? || pagenum < 1
    STDERR.puts "Pagenum #{pagenum} is the end of the road! We're done here"
    break 
  end
  
  page = agent.click(link)
  puts "---- loaded page #{pagenum} ----- #{link['href']}"

}


# MY WORK HERE IS DONE
exit 0
