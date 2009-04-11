require 'Forwardable'
require File.expand_path(File.dirname(__FILE__) + "/hand_constants")

class HandStatistics
  extend Forwardable
  include HandConstants
  
  require File.expand_path(File.dirname(__FILE__) + "/statistics_holders/statistics_holder")
  require File.expand_path(File.dirname(__FILE__) + "/statistics_holders/blind_attack_statistics")
  require File.expand_path(File.dirname(__FILE__) + "/statistics_holders/continuation_bet_statistics")
  require File.expand_path(File.dirname(__FILE__) + "/statistics_holders/cash_statistics")
  require File.expand_path(File.dirname(__FILE__) + "/statistics_holders/preflop_raise_statistics")
  require File.expand_path(File.dirname(__FILE__) + "/statistics_holders/aggression_statistics")
    
  attr_accessor :button
  attr_reader :player_hashes, :statistics_holders

  def_delegators :@blind_attack_statistics_holder,
    :blind_attack_opportunity?, :blind_attack_opportunity_taken?, :blind_defense_opportunity?, :blind_defense_opportunity_taken?
  def_delegators :@continuation_bet_statistics_holder, :cbet_opportunity?, :cbet_opportunity_taken?
  def_delegators :@cash_statistics_holder, :posted, :paid, :won, :cards
  def_delegators :@aggression_statistics_holder, :preflop_passive, :preflop_aggressive, :postflop_passive, :postflop_aggressive
  def_delegators :@preflop_raise_statistics_holder, :pfr_opportunity?, :pfr_opportunity_taken?

  def initialize
    @hand_information = {}
    @player_hashes = []
    @position = {}
    initialize_statistics
  end
  
  def b value
    if value.nil?
      return "?"
    elsif value
      return "t"
    else
      return "."
    end
  end
  
  def debug_display
    reports = self.reports
    print_report_header
    players.each do |each|
      print_report(each, reports[each])
    end
  end
  
  def print_report_header
    puts("                                                    |pre|pos|pfr|bat|bdf|cbt|\n")
    puts("                                                    |---+---|-+-|-+-|-+-|-+-|\n")
    puts("                                                    |a|p|a|p|o|t|o|t|o|t|o|t|\n")
    puts("                                                    |g|a|g|a|p|k|p|k|p|k|p|k|\n")
    puts("screenname     |posted  |paid    |won     |cards    |g|s|g|s|t|n|t|n|t|n|t|n|\n")
    puts("---------------+--------+--------+--------+---------|-+-|-+-|-+-|-+-|-+-|-+-|\n")
  end
  
  def print_report(screen_name, data)
    printf("%-15s|%8.2d|%8.2d|%8.2d|%9s|%1d|%1d|%1d|%1d|%1s|%1s|%1s|%1s|%1s|%1s|%1s|%1s|%d\n",
      screen_name, data[:posted], data[:paid], data[:won], data[:cards], 
      data[:preflop_aggressive], data[:preflop_passive], data[:postflop_aggressive], data[:postflop_passive],
      b(data[:is_pfr_opportunity]), b(data[:is_pfr_opportunity_taken]),
      b(data[:is_blind_attack_opportunity]), b(data[:is_blind_attack_opportunity_taken]), 
      b(data[:is_blind_defense_opportunity]), b(data[:is_blind_defense_opportunity_taken]),
      b(data[:is_cbet_opportunity]), b(data[:is_cbet_opportunity_taken]), position(screen_name)
    )
  end
  
  def players
    @player_hashes.sort{|a, b| a[:seat] <=> b[:seat]}.collect{|each| each[:screen_name]}
  end
  
  def street
    @street
  end
  
  def report(player)
    result = {}
    @statistics_holders.each {|each| result.merge!(each.report(player))}
    result
  end
  
  def reports
    result = {}
    players.each{|each| result[each] = report(each)}
    result
  end
  
  def register_player(player)
    screen_name = player[:screen_name]
    raise "#{PLAYER_RECORDS_DUPLICATE_PLAYER_NAME}: #{screen_name.inspect}" if players.member?(screen_name)
    @player_hashes << player
    @position[screen_name] = nil
    @statistics_holders.each {|each| each.register_player(screen_name, @street)}
    street_transition_for_player(@street, screen_name)
  end
  
  def button_relative_seat(player_hash)
    (player_hash[:seat] + MAX_SEATS - @button)%MAX_SEATS
  end

  def register_button(position)
    @button = position
    return true if @player_hashes.empty?
    @player_hashes.sort!{|a,b| button_relative_seat(a) <=> button_relative_seat(b)}
    @player_hashes = [@player_hashes.pop] + @player_hashes unless @player_hashes.first[:seat] == @button
    @player_hashes.each_with_index{|player, index| player[:position] = index, @position[player[:screen_name]] = index}
  end
  
  def hand_record
    raise "#{HAND_RECORD_INCOMPLETE_MESSAGE}: #{(HAND_INFORMATION_KEYS - @hand_information.keys).inspect}" unless (HAND_INFORMATION_KEYS - @hand_information.keys).empty?
    @hand_information
  end
  
  def out_of_balance
    false
  end
  
  def validate_player_records
    raise PLAYER_RECORDS_NO_PLAYER_REGISTERED if players.empty?
    raise PLAYER_RECORDS_NO_BUTTON_REGISTERED if button.nil?
    raise PLAYER_RECORDS_OUT_OF_BALANCE if out_of_balance
  end
  
  def player_records
    validate_player_records
    self.player_hashes
  end
  
  def update_hand(hash)
    unless hash[:street].nil? || hash[:street] == @street
      street_transition(hash[:street])
      hash.delete(:street)
    end
    @hand_information.update(hash)
    self
  end
  
  def register_action(screen_name, description, options={})
    raise "#{PLAYER_RECORDS_UNREGISTERED_PLAYER}: #{screen_name.inspect}" unless players.member?(screen_name)
    apply_action({:screen_name => screen_name, :description => description, :aggression => aggression(description)}.update(options))
  end
  
  def number_players
    @player_hashes.size
  end
  
  def position(screen_name)
    @position[screen_name]
  end
  
  def cutoff_position
    (number_players > 3) && (-1 % number_players)
  end
  
  def button?(screen_name)
    position(screen_name) && position(screen_name).zero?
  end
  
  def cutoff?(screen_name)
    position(screen_name) == cutoff_position
  end
  
  def blind?(screen_name)
    (sbpos?(screen_name) || bbpos?(screen_name)) and !posted(screen_name).zero?
  end
  
  def sbpos?(screen_name)
    (number_players > 2) && position(screen_name) == 1
  end
  
  def bbpos?(screen_name)
    (number_players > 2) && position(screen_name) == 2
  end

  def attacker?(screen_name)
    button?(screen_name) || cutoff?(screen_name)
  end
  
  def street
    @street
  end

  private
  
  def aggression(description)
    case description
    when /call/
      :passive
    when /raise/
      :aggressive
    when /bet/
      :aggressive
    when /fold/
      :fold
    when /check/
      :check
    else
      :neutral
    end
  end
  
  def initialize_statistics
    @last_state = nil
    @statistics_holders = [
      @blind_attack_statistics_holder = BlindAttackStatistics.new(self),
      @cash_statistics_holder = CashStatistics.new(self),
      @continuation_bet_statistics_holder = ContinuationBetStatistics.new(self),
      @aggression_statistics_holder = AggressionStatistics.new(self),
      @preflop_raise_statistics_holder = PreflopRaiseStatistics.new(self)
    ]
    street_transition(:prelude)
  end

  def street_transition(street)
    @street = street
    @statistics_holders.each {|each| each.street_transition(street)}
    players.each {|player| street_transition_for_player(street, player)}
  end

  def street_transition_for_player(street, player)
    # puts "street transition for player #{player} to #{street}"
    @statistics_holders.each {|each| each.street_transition_for_player(street, player)}
  end
  
  def apply_action(action)
    @statistics_holders.each {|each| each.apply_action action, @street}
  end
end