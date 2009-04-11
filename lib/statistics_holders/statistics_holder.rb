class StatisticsHolder
  def initialize handstatistics
    @hand_statistics = handstatistics
  end
  
  def report(screen_name)
    {}
  end
  
  def register_player screen_name, street
  end
  
  def street_transition street
  end
  
  def street_transition_for_player street, player
  end
  
  def apply_action action, street
  end
end