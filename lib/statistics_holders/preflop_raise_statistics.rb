
class PreflopRaiseStatistics < StatisticsHolder

  def initialize handstatistics
    super handstatistics
    @pfr_opportunity = {}
    @pfr_opportunity_taken = {}
  end
  
  def pfr_opportunity?(screen_name)
    @pfr_opportunity[screen_name]
  end
  
  def pfr_opportunity_taken?(screen_name)
    @pfr_opportunity[screen_name] && @pfr_opportunity_taken[screen_name]
  end
  
  def report screen_name
    {
      :is_pfr_opportunity => pfr_opportunity?(screen_name),
      :is_pfr_opportunity_taken => pfr_opportunity_taken?(screen_name)
    }
  end
  
  def apply_action action, street
    # puts "pfr: apply_action #{street}, #{action.inspect}"
    result = action[:result]
    player = action[:screen_name]
    if street == :preflop and [:pay, :pay_to, :neutral].member?(result) and @pfr_opportunity[player].nil?
      case result
      when :pay, :neutral
        @pfr_opportunity[player] = true
        @pfr_opportunity_taken[player] = false
      when :pay_to
        @hand_statistics.players.each {|each_player| @pfr_opportunity[each_player] ||= (each_player == player)}
        @pfr_opportunity_taken[player] = true
      end
    end
  end
end
