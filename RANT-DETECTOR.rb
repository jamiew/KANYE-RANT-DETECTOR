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

# RAPPERS MEET HACKERS? C'MON HELP US OUT
# require 'rss/1.0'
# require 'rss/2.0'
# require 'open-uri'


# MIN RANTITTUDE -- AVOID FALSE POSITIVES
MINIMUM_RANT_LENGTH = 200


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
  return open("http://bit.ly/api?url=#{url}", "UserAgent" => "KANYE RANT DETECTOR <http://fffff.at>").read
end

# POST SOMETHING TO TWITTER
def announce(text)
  puts "ANNOUNCE: #{text}"
  @config ||= YAML.load(File.open('config.yml'))
  raise "No config file!" if @config.blank?
  httpauth = Twitter::HTTPAuth.new(@config['username'], @config['password'])
  twitter = Twitter::Base.new(httpauth)
  twitter.update(text)
end

def save(text, url, shorturl, time = DateTime.now)

  rants = DB[:rants]
  rows = rants.where(:url => url)
  
  if rows.blank? || rows.first.nil?
    puts "NO RECORD! INSERTING NEW..."
    return rants.insert(:text => text, :url => url, :shorturl => shorturl, :created_at => time)
  else
    puts "RECORD ALREADY EXISTS => #{rows.first.inspect}"
    return false # could not save, already exists
  end
end



# ------ WORK IT GIRL --------

puts "INITIALIZING DATABASE..."


# INITIALIZE OUR RANTERBASE
DB = Sequel.sqlite 'kanyerants.db'
unless DB.table_exists?(:rants)
  DB.create_table :rants do
    primary_key :id
    String :url
    String :shorturl
    String :text
    DateTime :created_at
  end
end


# url = "http://www.kanyeuniversecity.com/blog/"
# page w/ yesterday's twitter rant
# url = "http://www.kanyeuniversecity.com/blog/?em3106=0_-1__-1_~0_-1_5_2009_0_10&em3298=&em3282=&em3281=&em3161="
# last page...
url = "http://www.kanyeuniversecity.com/blog/?em3106=0_-1__-1_~0_-1_5_2009_0_4820&em3298=&em3282=&em3281=&em3161="

puts "CONTACTING INTERNETS... #{url}"
agent = WWW::Mechanize.new
agent.user_agent = "KANYE RANT DETECTOR <http://fffff.at>"
# agent.user_agent_alias = "Mac Safari"
page = agent.get(url)

# FOR PROPER ARCHIVAL
reverse_pagination = true

# DETECT KANYES GOGOGOGO
first = 0 # GETS OVERRIDDEN
loop {
  (page/'.rapper').each { |post|
      
    excerpt = post.content[0..100].gsub("\n",'').gsub("\t",'').chomp
    permalink = url+(post/'a').first['href']
    text = (post/'h5').first.content.strip_html
    puts "PROCESSING: #{excerpt} ..."

    # FOUND A SHORTCUT: ONLY RANTS ARE IN SPECIFIED ELEMENT
    content = (post/'h5 div').first.content rescue ''

    # TELL THE MAFACKIN WORLD
    # BONUS: DO IT WITH AUTOTUNE
    if !content.empty? && content.length > MINIMUM_RANT_LENGTH
      shorturl = bitlyfy(permalink)    
      msg = "KANYERANT! \"#{excerpt}\": #{shorturl}"

      # ONLY ANNOUNCE ON SUCCESFUL SAVE TO DB
      announce(msg) if save(msg, permalink, shorturl)
      puts "..."
    
      sleep 5
    
    end
    
  }

  # RECURSE PAGES... THEY POST A LOT
  current = (page/'#emodpages strong')[1].content.to_i
  first = current if first == 0
  puts "current = #{current.inspect} -- first = #{first.inspect}"
  prev = (page/'#emodpages a').select { |e| e.content.strip_html.to_i == (reverse_pagination ? current - 1 : current + 1) }
  puts "prev = #{prev}"
  break if prev.blank?
  
  sleep 3
  page = agent.click(prev.first)
  puts "---- loaded page #{prev} -----"

}


# MY WORK HERE IS DONE
exit 0
