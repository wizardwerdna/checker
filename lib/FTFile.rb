require 'yaml'

class FTHandRecord
  include Enumerable
  
  def initialize(lines, path=nil, position=0)
    @lines = lines
    @stats = {}
    @noisy = false
  end
  
  def lines
    @lines
  end
  
  def each
    @lines.each {|line| yield line}
  end
  
  def game
    return "*** invalid ***" if @lines.nil? or @lines.empty?
    @lines[0]
  end
  
  def upto(regexpression)
    prefix = []
    detect{|line|prefix<<line; line.match(regexpression)}
    prefix
  end
  
  def prelude
    @prelude ||= upto(/^\*\*\*/)
  end

  def compute_players
    prelude.grep(/Seat [1-9]: ([^(]+) \(/){$1}
  end
  
  def rewrite(line)
    case line
    when /Board: \[(.*)\]/
      "Board; [#{$1}]"
    when /Seat ([0-9]): (.*)/
      "Seat #{$1}; #{$2}"
    else
      line
    end
  end
  
  def ignore?(line)
    case line
    when /(.*) adds ([$0-9.,]*)/
      puts "cashier: #{$1} adds #{$2}" if @noisy
      true
    when /(.*) is feeling ((normal)|(happy)|(angry)|(confused))/
      puts "emote: #{$1} feels #{$2}" if @noisy
      true
    when /([^,]+) ((is sitting out)|(has timed out)|(has returned)|(stands up)|(sits down))/
      puts "table: #{$1}/#{$2}" if @noisy
      true
    when /The blinds are now (.*)\/(.*)/
      puts "blinds up: #{$1}/#{$2}" if @noisy
      true
    when /(.*) has requested TIME/
      puts "time: #{$1}" if @noisy
      true
    when /Time has expired/
      puts "time expired" if @noisy
      true
    when /(.*) seconds left to act/
      puts "time left to act: #{$1}" if @noisy
      true
    when /(.*) has ((been disconnected)|(reconnected))/
      puts "connection: #{line}" if @noisy
      true
    when /(.*) has (.*) seconds (left )?to ((act)|(reconnect))/
      puts "timeout: #{line}" if @noisy
      true
    else
      false
    end
  end
    
  def process_lines_in_context_for_analysis
    state = :nostate
    @stats = {}
    each do |line|
      next if ignore?(line)
      line = rewrite line
      case line
      when /Full Tilt Poker Game.*\(partial\)/
        raise "partial hand record"
      when /Full Tilt Poker Game #([0-9]+): ([^-]*) - ([^\/]*)\/([^-]*) - ([^\-]*) - ([^-]*) - ([^-]*)/
        # printf ">>%s; title=%s; sb=%s; bb=%s; game=%s; time=%s; date=%s\n", $1, $2, $3, $4, $5, $6, $7
        # 
        # Full Tilt Poker Game #7611168782: $20 + $2 Sit & Go (57898200), Table 1 - 15/30 - No Limit Hold'em - 21:40:35 ET - 2008/08/11
        # Full Tilt Poker Game #8524212293: Table Sable (deep) - $0.25/$0.50 - No Limit Hold'em - 23:58:51 ET - 2008/10/16        
        puts "game: #{line}" if @noisy
        @stats[:header] = line
        @stats[:hand] = $1
        @stats[:description] = $2
        @stats[:sb] = $3
        @stats[:bb] = $4
        @stats[:form] = $5
        @stats[:played_at] = Time.parse("#{$7} #{$6}")
        @stats[:tournament] = (@stats[:description] =~ /\(([0-9]+)\)/) ? $1 : nil
        state = :prelude
      when /Full Tilt Poker Game #([0-9]+):/
        raise "unparseable title line: #{line}"
      when /\*\*\* HOLE CARDS \*\*\*/
        puts "hole: #{line}" if @noisy
        state = :preflop
      when /\*\*\* FLOP \*\*\* \[(.*)\]/
        puts "flop (#{$1}): #{line}" if @noisy
        state = :flop
      when /\*\*\* TURN \*\*\* \[([^\]]*)\] \[([^\]]*)\]/
        puts "turn (#{$1}/#{$2}): #{line}" if @noisy
        state = :turn
      when /\*\*\* RIVER \*\*\* \[([^\]]*)\] \[([^\]]*)\]/
        puts "river (#{$1}/#{$2}): #{line}" if @noisy
        state = :river
      when /\*\*\* SHOW DOWN \*\*\*/
        puts "showdown (#{$1}/#{$2}): #{line}" if @noisy
        state = :showdown
      when /\*\*\* SUMMARY \*\*\*/
        puts "summary: #{line}" if @noisy
        state = :summary
      when /(.*): (.*)/
        puts "------------->#{$1}: #{$2}" if @noisy
      else
        yield state, line
      end
    end
  end
  
  def analyze_prelude(state, line)
    @noisy = false
    case line
    when /Seat ([0-9]); ([^(]+) ([^)]+)/
      puts "prelude: player #{$1}/#{$2}" if @noisy
      @stats[:players] ||= {}
      @stats[:players][$2] = {:seat => $1.to_i}
      @stats[$2] = []
    when /(.*) posts (((the )|(a dead ))?((small)|(big)) blind of )?([$0-9,.]+)/
      puts "prelude: post #{$1}/#{$2}/#{$3}/#{$4}/#{$5}" if @noisy
      raise "action for non-player: #{line}" if @stats.nil? || @stats[$1].nil?
      @stats[$1] << {:action => "post", :result => :post, :amount => $9, :state => state}
    when /(.*) antes ([$0-9,.]+)/
      puts "prelude: antes #{$1}/#{$2}" if @noisy
      @stats[$1] << {:action => "ante", :result => :post, :amount => $9, :state => state}
    when /The button is in seat #([0-9])/
      puts "prelude: button #{$1}" if @noisy
      players = @stats[:players]
      @stats[:button] = $1.to_i
      raise "no players for this hand" if players.nil?
      @stats[:positions] = players.keys.sort do |a, b| 
        (players[a][:seat]-@stats[:button]-1+11)%11 <=> 
          (players[b][:seat]-@stats[:button]-1+11)%11
      end
      @stats[:positions].unshift @stats[:positions].pop
      @stats[:positions].each_with_index{|each, index| @stats[:players][each][:position] = index}
    else
      raise "unparseable content in prelude: #{line}"
    end
  end
  
  def analyze_actions(state, line)
    case line
    when /Dealt to ([^)]+) \[([^\]]+)\]/
      raise "icky icky icky" if state != :preflop
      puts "preflop: dealt #{$1}/#{$2}" if @noisy
    when /(.+) ((folds)|(checks))/
      raise "action for non-player: #{line}" if @stats.nil? || @stats[$1].nil?
      @stats[$1] << {:action => $2, :result => :neutral, :amount => 0, :state => state}
      puts "#{state}: action #{$1}/#{$2}/#{$3}/#{$4}/#{$5}/#{$6}/#{$8}/#{$9}/" if @noisy
    when /(.+) ((calls)|(bets)|(raises to)) (([$0-9.,]*)(, and is all in)?)?$/
      raise "action for non-player: #{line}" if @stats.nil? || @stats[$1].nil?
      @stats[$1] << {:action => $2, :result => :pay, :amount => $7, :state => state}
      puts "#{state}: action #{$1}/#{$2}/#{$3}/#{$4}/#{$5}/#{$6}/#{$8}/#{$9}/" if @noisy
    when /Uncalled bet of (.*) returned to (.*)/
      raise "action for non-player: #{line}" if @stats.nil? || @stats[$2].nil?
      @stats[$2] << {:action => "return", :result => :win, :amount => $1, :state => state}
      puts "#{state}: uncalled bet returned #{$1}/#{$2}" if @noisy
    when   /(.*) mucks/
      puts "#{state}: mucks #{$1}" if @noisy
    when /(.*) ((wins)|(ties for)) (the )?((main )|(side ))?pot (#[0-9] )?\((.*)\)( with (.*))?/
      raise "action for non-player: #{line}" if @stats.nil? || @stats[$1].nil?
      @stats[$1] << {:action => "wins", :result => :win, :amount => $10, :state => state}
      puts "#{state}: wins #{$1}/#{$2}/#{$3}" if @noisy
    when /(.*) shows \[(.*)\]/
      puts "#{state}: shows #{$1}/#{$2}"  if @noisy
    when /(.*) shows (.*)/
      puts "#{state}: shows #{$1}/#{$2}" if @noisy
    else        
      raise "unparseable content in #{state}: #{line}"
    end
  end
  
  def analyze_summary(state, line)
    # puts line
    case
      when /Board; \[(.*)\]/
        puts "Board: #{$1}" if @noisy
      when /Total pot (.*) | Rake (.*)/
      when /Seat [0-9]; (.*) \(((small)|(big)) blind\) folded on the Flop/
      when /Seat [0-9]; (.*) folded on the ((Flop)|(Turn)|(River))/
      when /Seat [0-9]; (.*) didn't bet (folded)/
      when /Seat [0-9]; (.*) collected (.*), mucked/
      when /Seat [0-9]; (.*) (\((small blind)|(big blind)|(button)\) )?didn't bet (folded)/
      when /Seat [0-9]; (.*) showed \[([^\]]+)\] and ((won)|(lost)) with a (.*)/
    else
      raise "unparseable content in summary: #{line}"
    end
  end
  
  def analyze
    begin
      process_lines_in_context_for_analysis do |state, line|
        case state
        when :prelude
          analyze_prelude(state, line)
        when :preflop, :flop, :turn, :river, :showdown
          analyze_actions(state, line)
        when :summary
          analyze_summary(state, line)
        end
      end
    rescue => e
      puts e.inspect
      # puts e.backtrace
    end
    # puts @stats.inspect
    self
  end
  
  def atstats
    analyze if @stats.empty?
    puts @stats
    @stats
  end
  
  def game
    @lines[0]
  end
  
  def reflect_stats(symbol)
    analyze if @stats.empty?
    @stats && @stats[symbol]
  end
  
  def hand
    reflect_stats(:hand)
  end

  def description
    reflect_stats(:description)
  end
  
  def sb
    reflect_stats(:sb)
  end

  def bb
    reflect_stats(:bb)
  end
  
  def form
    reflect_stats(:form)
  end
  
  def played_at
    reflect_stats(:played_at)
  end

  def tournament
    reflect_stats(:tournament)
  end
  
  def players
    analyze if @stats.empty?
    @stats && @stats[:positions]
  end
  
  def seat(player)
    summary_stats?(player) && @stats[:players][player][:seat]
  end
  
  def vpip?(player)
    summary_stats?(player) && @vpip[player]
  end
  
  def pfr?(player)
    summary_stats?(player) && @pfr[player]
  end
  
  def net(player)
    summary_stats?(player) && @net[player]
  end
  
  def sawflop?(player)
    summary_stats?(player) && @sawflop[player]
  end
  
  def preflop_action(player, action)
    summary_stats?(player) && ((@preflop_action[player] && @preflop_action[player][action]) || 0)
  end
  
  def postflop_action(player, action)
    summary_stats?(player) && ((@postflop_action[player] && @postflop_action[player][action]) || 0)
  end
  
  def preflop_aggressive(player)
    summary_stats?(player) && (preflop_action(player, "raises to") + preflop_action(player, "bets"))
  end
  
  def preflop_passive(player)
    summary_stats?(player) && preflop_action(player, "calls")
  end
  
  def postflop_aggressive(player)
    summary_stats?(player) && postflop_action(player, "raises to") + postflop_action(player, "bets")
  end
  
  def postflop_passive(player)
    summary_stats?(player) && postflop_action(player, "calls")
  end
  
  def summary_stats?(player)
    return false unless players.member?(player)
    compute_summary_stats(player) if @vpip.nil? || @vpip[player].nil?
    true
  end
  
  require "pp"
  def compute_summary_stats(player)
    @vpip ||= {}
    @pfr ||= {}
    @net ||= {}
    @sawflop ||= {}
    @net[player] = "0"
    @vpip[player] = false
    @pfr[player] = false
    @sawflop[player] = false
    @preflop_action ||= {}
    @postflop_action ||= {}
    @preflop_action[player] ||= {}
    @postflop_action[player] ||= {}
    @stats[player].each do |action|
      @sawflop[player]=true if action[:state] == :flop
      case action[:result]
      when :post
        @net[player]+="-#{action[:amount]}"
      when :pay
        @vpip[player]=true
        @net[player]+="-#{action[:amount]}"
      when :win
        @net[player]+="+#{action[:amount]}"
      end
      case action[:state]
      when :preflop
        @preflop_action[player][action[:action]] ||= 0
        @preflop_action[player][action[:action]] += 1
        @pfr[player] ||= (action[:action] == "raises to")
      else
        @postflop_action[player][action[:action]] ||= 0
        @postflop_action[player][action[:action]] += 1
      end
    end
    self
  end

  def to_s
    "FTHandRecord: #{game}"
  end

  def stats (logger=nil)
    result = []
    players && players.each_with_index do |player, position|
      hand_record = Hand.find_by_name(hand)
      unless hand_record
        hand_record = Hand.create(:name => hand, :description => description, :sb => sb, :bb => bb, :played_at => played_at, :tournament => tournament)
        if logger.nil?
          puts "judistats/stats: created_at: #{Time.now}; hand: #{hand.inspect}; players: #{players.size}" 
        else
          logger.info "judistats/stats: created_at: #{Time.now}; hand: #{hand.inspect}; players: #{players.size}" 
        end
      end
      result << {
        :hand => hand_record,
        :player => Player.find_or_create_by_screen_name(player),
        :seat => seat(player),
        :position => position,
        :vpip => vpip?(player) ? 1 : 0,
        :pfrp  => pfr?(player)  ? 1 : 0,
        # :sawflop => sawflop?(player) ? 1 : 0,
        :preflop_aggressive => preflop_aggressive(player),
        :preflop_passive => preflop_passive(player),
        :postflop_aggressive => postflop_aggressive(player),
        :postflop_passive => postflop_passive(player),
        :posted => 0,
        :bet => 0,
        :cashed => 0
      }
    end
    result
  end
end

class FTFile
  include Enumerable
  
  def self.open(filename, starting_at = 0)
    new(filename, starting_at)
  end
  
  def initialize(filename, starting_at = 0)
    @file = File.open(filename)
    @starting_at = starting_at
    @file.pos = @starting_at
    @lastline = @file.readline
  end

  def each(starting_at = 0)
    lines = []
    game = nil
    has_handrecord = false
    File.open(@filename, "r") do |f|
      f.pos = @starting_at
      f.each do |line|
        line.chomp!
        if line =~ /Full Tilt Poker Game #([0-9]+)/
          yield FTHandRecord.new(lines) if has_handrecord
          has_handrecord = true
          lines = [line]
          game = line
        end
        lines << line unless line.empty?
      end
      yield FTHandRecord.new(lines) if has_handrecord
    end
  end
end