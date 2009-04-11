#TODO <RuntimeError: unparseable content in showdown: FRAJI re-buys and receives 3000 chips for $6.00>
#TODO <RuntimeError: unparseable content in showdown: jackiepackie was removed from the table for failing to post>
#TODO <RuntimeError: unparseable content in preflop: Shoalwater was removed from the table for failing to post>
#TODO <RuntimeError: unparseable content in prelude: Seat 8; Sw?z (1425 in chips) >

require 'yaml'
require File.dirname(__FILE__) + '/../../lib/checker/hand_statistics'

class PSHandRecord
  include Enumerable
  
  CASH = "[0-9$,.]+"

  CARD_RANK_ORDER = 'AKQJT98765432'
  SUIT_RANK_ORDER = "CcDdHhSs"
  
  def self.card_rank char
    CARD_RANK_ORDER.index(char)
  end
  
  def self.suit_rank char
    SUIT_RANK_ORDER.index(char)
  end
  
  def self.valid_card? string
    string.size == 2 && card_rank(string.first) && suit_rank(string.last)
  end
  
  def self.cards_class_string(cards_string)
    card_list = cards_string.split(' ')
    raise "not2cards" unless card_list.size == 2
    raise "invalidcard" unless valid_card?(card_list.first) && valid_card?(card_list.last)
    card_list.sort!{|a, b| card_rank(card_list.first.first) <=> card_rank(card_list.last.first)}
    result = card_list.first.first + card_list.last.first
    return result if result.first == result.last || card_list.first.last != card_list.last.last
    result + "s"
  end
  
  def initialize(lines, path, starting_at)
    @lines = lines
    @path = path
    @starting_at = starting_at
    @stats = {}
    @noisy = false
    @stats[:hand_statistics] = HandStatistics.new.update_hand(:session_filename => path, :starting_at => starting_at)
  end
  
  def lines
    @lines
  end
  
  def path
    @path
  end
  
  def starting_at
    @starting_at
  end
  
  def each
    @lines.each {|line| yield line}
  end
  
  def game
    return "*** invalid ***" if @lines.nil? or @lines.empty?
    @lines[0]
  end
  
  def cash_to_d(string)
    string.gsub!(/[$, ]/,"")
    string.to_d
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
    when /Seat ([0-9]+): (.*)/
      "Seat #{$1}; #{$2}"
    else
      line
    end
  end
  
  def ignore?(line)
    case line
    when /(.*): ((sits out))/
      puts "#{$2}: #{$1}" if @noisy
      true
    when /([^,]+) ((is sitting out)|(has timed out)|(has returned)|(stands up)|(sits down)|(leaves the table))/
      puts "table: #{$1}/#{$2}" if @noisy
      (line =~ /^Seat/).nil? # do not ignore lines beginning with "Seat"
    when /([^,]+) joins the table at seat #([0-9]+)/
      puts "table: #{$1}/#{$2}" if @noisy
      true
    when /(.*) is ((disconnected)|(connected)|(reconnected))/
      puts "connection: #{line}" if @noisy
      (line =~ /^Seat/).nil? # do not ignore lines beginning with "Seat"
    # when /(.*) adds (#{CASH})/
    #   puts "cashier: #{$1} adds #{$2}" if @noisy
    #   true
    # when /(.*) is feeling ((normal)|(happy)|(angry)|(confused))/
    #   puts "emote: #{$1} feels #{$2}" if @noisy
    #   true
    # when /The blinds are now (.*)\/(.*)/
    #   puts "blinds up: #{$1}/#{$2}" if @noisy
    #   true
    # when /(.*) has requested TIME/
    #   puts "time: #{$1}" if @noisy
    #   true
    # when /Time has expired/
    #   puts "time expired" if @noisy
    #   true
    # when /(.*) seconds left to act/
    #   puts "time left to act: #{$1}" if @noisy
    #   true
    # when /(.*) has (.*) seconds (left )?to ((act)|(reconnect))/
    #   puts "timeout: #{line}" if @noisy
    #   true
    else
      false
    end
  end
  
  def determine_player_positions_from_button
    players = @stats[:players]
    raise "no players for this hand" if players.nil?
    @stats[:positions] = players.keys.sort do |a, b| 
      (players[a][:seat]-@stats[:button]-1+11)%11 <=> 
        (players[b][:seat]-@stats[:button]-1+11)%11
    end
    @stats[:positions].unshift @stats[:positions].pop
    @stats[:positions].each_with_index{|each, index| @stats[:players][each][:position] = index}
  end
    
  def process_lines_in_context_for_analysis
    state = :nostate
    @stats = {}
    each do |line|
      next if ignore?(line)
      line = rewrite line
      case line
      when /PokerStars Game.*\(partial\)/
        raise "partial hand record"
      when /PokerStars Game #([0-9]+): Tournament #([0-9]+), \$([0-9+$]+) ([^\-]*) - Level ([IVXL]+) \((#{CASH})\/(#{CASH})\) - (.*)$/
        # PokerStars Game #21650436825: Tournament #117620218, $10+$1 Hold'em No Limit - Level I (10/20) - 2008/10/31 17:25:42 ET
        puts "game: #{line}" if @noisy
        @stats[:header] = line
        @stats[:hand] = 'PS' + $1
        @stats[:tournament] = $2
        @stats[:form] = $4
        @stats[:description] = $2 + ", " + $3 + " " + $4
        @stats[:level] = $5
        @stats[:sb] = cash_to_d($6)
        @stats[:bb] = cash_to_d($7)
        @stats[:played_at] = Time.parse("#{$8}")
        @stats[:hand_statistics].update_hand(
                        :name => 'PS' + $1, 
                        :description => $2 + ", " + $3 + " " + $4,
                        :sb => cash_to_d($6), 
                        :bb => cash_to_d($7),
                        :played_at => Time.parse("#{$8}"),
                        :tournament => $2)
        printf(">> Tournament hand %d; tournament %d; description '%s'; sb = %d; bb = %d; form = %s; played_at = %s\n", 
          @stats[:hand], @stats[:tournament], @stats[:description], @stats[:sb], @stats[:bb], @stats[:form], @stats[:played_at]) if $noisy
        state = :prelude
      when /PokerStars Game #([0-9]+): ([^(]*) \((#{CASH})\/(#{CASH})\) - (.*)$/
        # PokerStars Game #21650146783:  Hold'em No Limit ($0.25/$0.50) - 2008/10/31 17:14:44 ET
        puts "game: #{line}" if @noisy
        @stats[:header] = line
        @stats[:hand] = 'PS' + $1
        @stats[:tournament] = nil
        @stats[:form] = $2
        @stats[:description] = "#{$2} (#{$3}/#{$4})"
        @stats[:level] = "I"
        @stats[:sb] = cash_to_d($3)
        @stats[:bb] = cash_to_d($4)
        @stats[:played_at] = Time.parse("#{$5}")
        @stats[:hand_statistics].update_hand(
                        :name => 'PS' + $1, 
                        :description => "#{$2} (#{$3}/#{$4})",
                        :sb => cash_to_d($3), 
                        :bb => cash_to_d($4),
                        :played_at => Time.parse("#{$5}"),
                        :tournament => nil)
        printf(">> Live Action hand %d; description '%s'; sb = %s; bb = %s; form = %s; played_at = %s\n", 
          @stats[:hand], @stats[:description], @stats[:sb], @stats[:bb], @stats[:form], @stats[:played_at]) if @noisy
        state = :prelude
        @stats[:hand_statistics].update_hand(:street => :prelude  , :board => $1)
      when /PokerStars Game #([0-9]+):/
        raise "unparseable title line: #{line}"
      when /\*\*\* HOLE CARDS \*\*\*/
        puts "hole: #{line}" if @noisy
        determine_player_positions_from_button
        @stats[:hand_statistics].update_hand(:street => :preflop, :board => $1)
        state = :preflop
      when /\*\*\* FLOP \*\*\* \[(.*)\]/
        puts "flop (#{$1}): #{line}" if @noisy
        @stats[:board] = $1
        @stats[:hand_statistics].update_hand(:street => :flop, :board => $1)
        state = :flop
      when /\*\*\* TURN \*\*\* \[([^\]]*)\] \[([^\]]*)\]/
        puts "turn (#{$1}/#{$2}): #{line}" if @noisy
        @stats[:board] = $1 + " " + $2
        @stats[:hand_statistics].update_hand(:street => :turn, :board => $1 + " " + $2)
        state = :turn
      when /\*\*\* RIVER \*\*\* \[([^\]]*)\] \[([^\]]*)\]/
        puts "river (#{$1}/#{$2}): #{line}" if @noisy
        @stats[:board] = $1 + " " + $2
        @stats[:hand_statistics].update_hand(:street => :river, :board => $1 + " " + $2)
        state = :river
      when /\*\*\* SHOW DOWN \*\*\*/
        puts "showdown (#{$1}/#{$2}): #{line}" if @noisy
        state = :showdown
      when /\*\*\* SUMMARY \*\*\*/
        puts "summary: #{line}" if @noisy
        state = :summary
      when /(.*) said, "(.*)"/
        puts "------------->#{$1}: #{$2}" if @noisy
      else
        yield state, line
      end
    end
  end
  
  def analyze_prelude(state, line)
    case line
    when /Seat ([0-9]+); ([^(]+) ([^)]+)( is sitting out)?/
      puts "prelude: player #{$1}/#{$2}/#{$3}/#{$4}/#{$5}" if @noisy
      @stats[:players] ||= {}
      @stats[:players][$2] = {:seat => $1.to_i}
      @stats[:hand_statistics].register_player  :screen_name => $2, :seat => $1.to_i, :initial_stack => $3
    # when /(.*): posts((( the)|( a dead))?(( small)|( big))? blind)? (#{CASH})/
    #   puts "prelude: #{$1} posts #{$9}" if @noisy
    #   raise "action for non-player: #{line}" if @stats.nil? || @stats[$1].nil?
    #   @stats[$1] << {:action => "post", :result => :post, :amount => cash_to_d($9), :state => state}
    when /(.*): posts ((small)|(big)|(small \& big)) blind(s)? (#{CASH})/
      puts "prelude: #{$1} posts #{$7}" if @noisy
      raise "action for non-player: #{line}" if @stats.nil? || @stats[$1].nil?
      @stats[$1] << {:action => "post", :result => :post, :amount => cash_to_d($7), :state => state}
    when /(.*): posts the ante (#{CASH})/
      puts "prelude: antes #{$2}" if @noisy
      raise "action for non-player: #{line}" if @stats.nil? || @stats[$1].nil?
      @stats[$1] << {:action => "ante", :result => :post, :amount => cash_to_d($2), :state => state}
      @stats[:hand_statistics].register_action  $1, state, "ante", :result => :post, :amount => cash_to_d($2)
    when /Table '([0-9]+) ([0-9]+)' (.*) Seat #([0-9]+) is the button/
      puts "prelude: button #{$4} on Tournament Table #{$1}-#{$2} (#{$3})" if @noisy
      @stats[:button] = $4.to_i
      @stats[:hand_statistics].button = $4.to_i
    when /Table '(.*)' (.*) Seat #([0-9]+) is the button/
      puts "prelude: button #{$3} on Live Action Table #{$1} (#{$2})" if @noisy
      @stats[:button] = $3.to_i
      @stats[:hand_statistics].button = $3.to_i
    when /(.*) will be allowed to play after the button/
      puts "prelude: #{$1} will be allowed to play after the button" if @noisy
    else
      raise "unparseable content in prelude: #{line}"
    end
  end
  
  def analyze_actions(state, line)
    case line
    when /Dealt to ([^)]+) \[([^\]]+)\]/
      raise "icky icky icky" if state != :preflop
      puts "preflop: dealt #{$1}/#{$2}" if @noisy
      @stats[$1] << {:action => "dealt", :result => :cards, :data => $2, :state => state}
      @stats[:hand_statistics].register_action  $1, state, "dealt", :result => :cards, :data => $2
    when /(.+): ((folds)|(checks))/
      raise "action for non-player: #{line}" if @stats.nil? || @stats[$1].nil?
      @stats[$1] << {:action => $2, :result => :neutral, :amount => "0".to_d, :state => state}
      @stats[:hand_statistics].register_action  $1, state, $2, :result => :neutral, :amount => "0".to_d
      puts "#{state}: #{$1} #{$2}" if @noisy
    when /(.+): ((calls)|(bets)) ((#{CASH})( and is all-in)?)?$/
      raise "action for non-player: #{line}" if @stats.nil? || @stats[$1].nil?
      @stats[$1] << {:action => $2, :result => :pay, :amount => cash_to_d($6), :state => state}
      @stats[:hand_statistics].register_action  $1, state, $2, :result => :pay, :amount => cash_to_d($6)
      puts "#{state}: #{$1} #{$2} #{$6}" if @noisy
    when /(.+): raises (#{CASH}) to (#{CASH})( and is all-in)?$/
      raise "action for non-player: #{line}" if @stats.nil? || @stats[$1].nil?
      @stats[$1] << {:action => "raises to", :result => :pay_to, :amount => cash_to_d($3), :state => state}
      @stats[:hand_statistics].register_action  $1, state, "raises to", :result => :pay_to, :amount => cash_to_d($3)
      puts "#{state}: #{$1} raises #{$2} to #{$3}" if @noisy
    when /Uncalled bet \((.*)\) returned to (.*)/
      raise "action for non-player: #{line}" if @stats.nil? || @stats[$2].nil?
      puts "#{state}: uncalled bet of #{$1} returned to #{$2}" if @noisy
      @stats[$2] << {:action => "return", :result => :win, :amount => cash_to_d($1), :state => state}
      @stats[:hand_statistics].register_action  $1, state, "return", :result => :win, :amount => cash_to_d($1)
    when   /(.*): doesn't show hand/
      puts "#{state}: #{$1} doesn't show hand" if @noisy
    when   /(.*): mucks hand/
      puts "#{state}: mucks #{$1}" if @noisy
    when /(.*) collected (.*) from ((side )|(main ))?pot/
      raise "action for non-player: #{line}" if @stats.nil? || @stats[$1].nil?
      @stats[$1] << {:action => "wins", :result => :win, :amount => cash_to_d($2), :state => state}
      @stats[:hand_statistics].register_action  $1, state, "wins", :result => :win, :amount => cash_to_d($2)
      puts "#{state}: #{$1} wins #{$2}" if @noisy
    # when /(.*) ((wins)|(ties for)) (the )?((main )|(side ))?pot (#[0-9] )?\((.*)\)( with (.*))?/
    #   raise "action for non-player: #{line}" if @stats.nil? || @stats[$1].nil?
    #   @stats[$1] << {:action => "wins", :result => :win, :amount => cash_to_d($10), :state => state}
    #   puts "#{state}: #{$1} wins #{$10}" if @noisy
    when /(.*): shows \[(.*)\]/
      @stats[$1] << {:action => "shows", :result => :cards, :data => $2, :state => state}
      @stats[:hand_statistics].register_action  $1, state, "shows", :result => :cards, :data => $2
      puts "#{state}: #{$1}shows [#{$2}]"  if @noisy
    when /(.*): shows (.*)/
      puts "#{state}: #{$1} shows2 #{$2}" if @noisy
    when /No low hand qualified/
      puts "#{state}: No low hand qualified." if @noisy
    else        
      raise "unparseable content in #{state}: #{line}"
    end
  end
  
  def analyze_summary(state, line)
    puts "analyze_summary(#{state}, #{line})" if @noisy
    case line
      when /Board \[(.*)\]/
        puts "Board: #{$1}" if @noisy
      when /Total pot (#{CASH}) (((Main)|(Side)) pot (#{CASH}). )*\| Rake (#{CASH})/
        puts "Total pot=#{$1} | Rake=#{$7}" if @noisy
        @stats[:total_pot] = cash_to_d($1)
        @stats[:rake] = cash_to_d($7)
        @stats[:hand_statistics].update_hand(:total_pot => cash_to_d($1), :rake => cash_to_d($7))
      when /Seat [0-9]+; (.*) \(((small)|(big)) blind\) folded on the Flop/
      when /Seat [0-9]+; (.*) folded on the ((Flop)|(Turn)|(River))/
      when /Seat [0-9]+; (.*) folded before Flop \(didn't bet\)/
      when /Seat [0-9]+; (.*) (\((small blind)|(big blind)|(button)\) )?folded before Flop( \(didn't bet\))?/
      when /Seat [0-9]+; (.*) (\((small blind)|(big blind)|(button)\) )?collected (.*)/
      when /Seat [0-9]+; (.*) (\((small blind)|(big blind)|(button)\) )?showed \[([^\]]+)\] and ((won) \(#{CASH}\)|(lost)) with (.*)/
      when /Seat [0-9]+; (.*) mucked \[([^\]]+)\]/
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
  
  def board
    reflect_stats(:board) || ""
  end
  
  def total_pot
    reflect_stats(:total_pot)
  end
  
  def rake
    reflect_stats(:rake)
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
  
  def posted(player)
    summary_stats?(player) && @posted[player]
  end
  
  def bet(player)
    summary_stats?(player) && @bet[player]
  end
  
  def cards(player)
    summary_stats?(player) && @cards[player]
  end
  
  def cards_class(player)
    begin
      PSHandRecord.cards_class_string(self.cards(player))
    rescue => e
      "***" 
    end
  end
  
  def cashed(player)
    summary_stats?(player) && @cashed[player]
  end
  
  def net(player)
    cashed(player) - bet(player) - posted(player)
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
    @sawflop ||= {}
    @posted ||= {}
    @bet ||= {}
    @cashed ||= {}
    @cards ||= {}
    @paid_this_round ||= {}
    @cards[player] = ""
    @posted[player] = "0".to_d
    @bet[player] = "0".to_d
    @cashed[player] = "0".to_d
    @paid_this_round[player] = "0".to_d
    @vpip[player] = false
    @pfr[player] = false
    @sawflop[player] = false
    @preflop_action ||= {}
    @postflop_action ||= {}
    @preflop_action[player] ||= {}
    @postflop_action[player] ||= {}
    last_state = nil
    @stats[player].each do |action|
      if last_state != action[:state]
        @paid_this_round[player] = "0".to_d unless action[:state] == :preflop
        last_state = action[:state]
      end
      @sawflop[player]=true if action[:state] == :flop
      case action[:result]
      when :post
        @posted[player]+=action[:amount]
        @paid_this_round[player]+=action[:amount]
      when :pay
        @vpip[player]=true
        @bet[player]+=action[:amount]
        @paid_this_round[player]+=action[:amount]
      when :pay_to
        @vpip[player]=true
        @bet[player] += action[:amount] - @paid_this_round[player]
        @paid_this_round[player] += action[:amount] - @paid_this_round[player]
      when :win
        @cashed[player]+=action[:amount]
      when :cards
        @cards[player]=action[:data]
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
    "PSHandRecord: #{game}"
  end
  
  def find_session
    result = Session.find_by_file File.basename(path)
    raise "could not find session '#{path}'" unless result
    result
  end
  
  def find_or_create_hand_record(logger=nil)
    hand_record = Hand.find_by_name(hand)
    unless hand_record
      hand_record = Hand.create(:session => find_session, :starting_at => starting_at, 
        :name => hand, :description => description, 
        :sb => sb, :bb => bb, :board => board, :total_pot => total_pot, :rake => rake,
        :played_at => played_at, :tournament => tournament)
      if logger.nil?
        puts "judistats/stats: created_at: #{Time.now}; hand: #{hand.inspect}; players: #{players && players.size}" 
      else
        logger.info "judistats/stats: created_at: #{Time.now}; hand: #{hand.inspect}; players: #{players && players.size}" 
      end
    end
    hand_record
  end

  def stats (logger=nil)
    result = []
    find_or_create_hand_record(logger)
    players && players.each_with_index do |player, position|
      hand_record = Hand.find_by_name(hand)
      result << {
        :hand => hand_record,
        :player => Player.find_or_create_by_screen_name(player),
        :seat => seat(player),
        :position => position,
        :cards => cards(player),
        :cards_class => cards_class(player),
        :vpip => vpip?(player) ? 1 : 0,
        :pfrp  => pfr?(player)  ? 1 : 0,
        # :sawflop => sawflop?(player) ? 1 : 0,
        :preflop_aggressive => preflop_aggressive(player),
        :preflop_passive => preflop_passive(player),
        :postflop_aggressive => postflop_aggressive(player),
        :postflop_passive => postflop_passive(player),
        :posted => posted(player),
        :bet => bet(player),
        :cashed => cashed(player),
        :net => net(player),
        :net_in_bb => net(player) / bb
      }
    end
    puts "stats complete"
    puts "...Compare #{result[:hand].inspect}"
    puts "...with #{@stats[:hand_statistics].hand_record.inspect}"
    result
  end
end

class PSFile
  include Enumerable
  
  POKERSTARS_HEADER_PATTERN = /PokerStars Game #([0-9]+)/
  
  def self.open(filename, starting_at = 0, &block)
    new(filename, starting_at).open(starting_at, &block)
  end
  
  def initialize(filename, starting_at = 0)
    @filename = File.expand_path(filename)
    @lastline = nil
    @lines = []
  end
  
  def open_file_and_verify_first_line(starting_at = 0)
    @file = File.open(@filename, "r")
    self.pos=starting_at
  end
  
  def open(starting_at = 0)
    open_file_and_verify_first_line(starting_at)
    if block_given?
      begin
        yield self
      ensure
        close
      end
    end
    self
  end
  
  def closed?
    @file.closed?
  end
  
  def pos
    return @file.pos if @lastline.nil?
    @file.pos - @lastline.size - 1
  end
  
  def pos=(index)
    @file.pos=index unless pos == index
    @lastline = @file.readline.chomp!
    unless @lastline && @lastline =~ POKERSTARS_HEADER_PATTERN
      close
      raise "hand record must begin with a valid header line"
    end
    @lines = [@lastline]
  end
  
  def eof?
    @lastline.nil?
  end
  
  def first(starting_at = 0)
    open(starting_at) do
      return next_handrecord
    end
  end
  
  def each
    yield next_handrecord
    yield next_handrecord until @lastline.nil?
  end
  
  def next_handrecord
    starting_at = pos
    until @file.eof?
      @lastline = @file.readline.chomp!
      break if @lastline =~ POKERSTARS_HEADER_PATTERN
      @lines << @lastline unless @lastline.empty?
    end
    result, @lines = PSHandRecord.new(@lines, @filename, starting_at), [@lastline]
    if @file.eof?
      @lastline = nil
      @index_of_last_header = nil
      @lines = []
    else
      @index_of_last_header = @file.pos-@lastline.size-1
      @lines = [@lastline]
    end
    result
  end
      
  def close
    @file.close unless @file.closed?
  end
end