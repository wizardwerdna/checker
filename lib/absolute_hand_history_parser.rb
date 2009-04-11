require File.expand_path(File.dirname(__FILE__) + '/hand_constants')
require File.expand_path(File.dirname(__FILE__) + '/hand_statistics')

CASH_NO_DOLLAR = "[0-9,.]+"
CASH_WITH_DOLLAR = "\\$#{CASH_NO_DOLLAR}"
CASH = "[0-9$,.]+"

class AbsoluteHandHistoryParser
  def self.parse_lines(lines, stats=nil)
    parser = self.new(stats)
    lines.each {|line| parser.parse(line)}
  end
  
  def initialize stats=nil
    @stats = stats || HandStatistics.new
  end
    
  def ignorable?(line)
    regular_expressions_for_ignorable_phrases = [
      /(.*) - Does not show/,
      # /(.*) has timed out/,
      # /(.*) has returned/,
      # /(.*) leaves the table/,
      # /(.*) joins the table at seat #[0-9]+/,
      /(.*) - sitout/,
      # /(.*) is (dis)?connected/,
      # /(.*) said,/, 
      # /(.*) will be allowed to play after the button/,
      # /(.*) was removed from the table for failing to post/,
      # /(.*) re-buys and receives (.*) chips for (.*)/,
      /(.*)Collects Bounty Prize of (.*)/,
  		/Seat [0-9]+: (.*)Folded on the (POCKET CARDS|FLOP|TURN|RIVER)/,
  		/Seat [0-9]+: (.*)collected Total \((#{CASH})\) HI:\((#{CASH})\)  \[Does not show\]/,
  		/Seat [0-9]+: (.*)collected Total \(#{CASH}\)/,
  		/Seat [0-9]+: (.*)won Total \(#{CASH}\) HI:\(#{CASH}\) with (.*)/,
  		/Seat [0-9]+: (.*)Total(.*)HI:(.*)with(.*)/,
  		/Seat [0-9]+: (.*)lost with (.*)/,
  		/Seat [0-9]+: (.*)HI: \[Mucked\]/,
  		/(.*) - Mucks/,
  		/Total Pot\(.*\)/
      # /^\s*$/    
    ]
    regular_expressions_for_ignorable_phrases.any?{|re| re =~ line }
  end
  
  def parse(line)
    begin
      case line
      # when /PokerStars Game #([0-9]+): Tournament #([0-9]+), (\$[0-9+$]+) ([^\-]*) - Level ([IVXL]+) \((#{CASH})\/(#{CASH})\) - (.*)$/
      #   @stats.update_hand :name => "PS#{$1}", :description=> "#{$2}, #{$3} #{$4}", :tournament=> $2, :sb=> $6.to_d, :bb=> $7.to_d, :played_at=> Time.parse($8), :street => :prelude
      # Stage #1545974005: Holdem  No Limit 20 - 2009-03-22 17:13:28 (ET)

      when /Stage #([0-9]+): +(.*) (#{CASH_NO_DOLLAR}) - (.+)$/
        @stats.update_hand :name => "AB#{$1}", :description=> "#{$2} #{$3}", :tournament=> true, :sb=> cash_to_d($3), :bb=> cash_to_d($3) * 2, :played_at=> Time.parse($4), :street => :prelude
      when /Stage #([0-9]+): +(.*) (#{CASH_WITH_DOLLAR}) - (.+)$/
        @stats.update_hand :name => "AB#{$1}", :description=> "#{$2} #{$3}", :tournament=> nil, :sb=> cash_to_d($3), :bb=> cash_to_d($3) * 2, :played_at=> Time.parse($4), :street => :prelude
      when /\*\*\* POCKET CARDS \*\*\*/
        @stats.register_button(@stats.button)
        @stats.update_hand :street => :preflop
      when /\*\*\* FLOP \*\*\* \[(.*)\]/
        @stats.update_hand :street => :flop
      when /\*\*\* TURN \*\*\* \[([^\]]*)\] \[([^\]]*)\]/
        @stats.update_hand :street => :turn
      when /\*\*\* RIVER \*\*\* \[([^\]]*)\] \[([^\]]*)\]/
        @stats.update_hand :street => :river
      when /\*\*\* SHOW DOWN \*\*\*/
        @stats.update_hand :street => :showdown
      when /\*\*\* SUMMARY \*\*\*/
        @stats.update_hand :street => :summary
      # when /PokerStars Game #([0-9]+):/
      #   raise "invalid hand record: #{line}"
      when /Dealt to ([^)]+) \[([^\]]+)\]/
        @stats.register_action($1, 'dealt', :result => :cards, :data => $2)
      when /(.*) - Shows \[(.*)\] (\(.*\))?/
        @stats.register_action($1, 'shows', :result => :cards, :data => $2)
      when /Board \[(.*)\]/
        @stats.update_hand :board => $1
      when /Total pot *\((#{CASH})\) (((Main)|(Side)) pot(-[0-9]+)? (#{CASH}). )*\| Rake \((#{CASH})\)/
        @stats.update_hand(:total_pot => cash_to_d($1), :rake => cash_to_d($8))
      when /Total Pot\((#{CASH})\) \| Rake \((#{CASH})\)/
        @stats.update_hand(:total_pot => cash_to_d($1), :rake => cash_to_d($2))
      when /Seat ([0-9]+) - (.+) \((#{CASH}) in chips\)/
        @stats.register_player(:seat => $1.to_i, :screen_name => $2)
      when /(.+) - Posts ((big|small) blind )?(#{CASH})/
        @stats.register_action($1, 'posts', :result => :post, :amount => cash_to_d($4))
      when /(.+) - Posts dead (#{CASH}) dead (#{CASH})/
        @stats.register_action($1, 'posts', :result => :post, :amount => cash_to_d($2))
        @stats.register_action($1, 'posts', :result => :post, :amount => cash_to_d($3))
      # when /(.*): posts the ante (#{CASH})/
      #   @stats.register_action($1, 'antes', :result => :post, :amount => cash_to_d($2))
      when /Table: (.*) Seat \#([0-9]+) is the dealer/
        @stats.register_button($2.to_i)
      # when /Table '(.*)' (.*) Seat #([0-9]+) is the button/
      #   @stats.register_button($3.to_i)
      when /(.+) - returned \((#{CASH})\) : not called/
        @stats.register_action($1, 'return', :result => :win, :amount => cash_to_d($2))
      when /(.+) - ((Checks)|(Folds))/
        @stats.register_action($1, $2.downcase, :result => :neutral)
      when /(.+) - ((Bets)|(Calls)) (#{CASH})/
        @stats.register_action($1, $2.downcase, :result => :pay, :amount => cash_to_d($5))
      when /(.+) - All-In (#{CASH})/
        @stats.register_action($1, "calls", :result => :pay, :amount => cash_to_d($2))
      when /(.+) - Raises (#{CASH}) to (#{CASH})/    
        @stats.register_action($1, 'raises', :result => :pay_to, :amount => cash_to_d($3))
      when /(.+) - All-In\(Raise\) (#{CASH}) to (#{CASH})/
        @stats.register_action($1, 'raises', :result => :pay_to, :amount => cash_to_d($3))
      when /(.+) Collects (#{CASH}) from (main|side) pot/
        @stats.register_action($1, "wins", :result => :win, :amount => cash_to_d($2))
      else
        raise "invalid line for parse: #{line}" unless ignorable?(line)
      end
    rescue => e
      raise e.inspect + e.backtrace.join("\n")
    end
  end
  
  private
  
  def cash_to_d(string)
    string.gsub!(/[$, ]/,"")
    string.to_d
  end
end