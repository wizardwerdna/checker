require 'rubygems'
require 'hpricot'
require 'open-uri'

class PokerEdge
  
  def initialize screen_name
    @screen_name = URI.escape(screen_name)
  end
  
  def get_response_from_internet
    open("http://www.poker-edge.com/whoami.php?name=badbeat_brat") do |f|
      @response = f.read
    end
    @response
  end
  
  def response
    @response ||= get_response_from_internet
  end
  
  def preflop_style
    if self.response =~ /(Pre-Flop Tend.*\n)/
      verbose = $1.gsub(/<\/?[^>]*>/, "")
      if verbose =~ /Pre-Flop Tendency: ([^-]*) -/
        preflop_style = $1
      else
        preflop_style = "N/A"
      end
    end
    preflop_style
  end
  
  def player_type
    if response =~ /(Player Type.*\n)/
      verbose = $1.gsub(/<\/?[^>]*>/, "")
      if verbose =~ /[Yy]ou are a ([^(]* \(.*\))/
        player = $1
      else
        player = ""
      end
    end
    player
  end
end