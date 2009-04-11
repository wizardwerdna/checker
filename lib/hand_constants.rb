module HandConstants
  HAND_INFORMATION_KEYS = [:session_filename, :starting_at, :name, :description, :sb, :bb, :board, :total_pot, :rake, :played_at, :tournament]
  PLAYER_INFORMATION_KEYS = [ :hand_name, :player_screen_name, :seat, :position, :cards, :cards_class, 
                              :vpip, :pfrp, :preflop_aggressive, :preflop_passive, :postflop_aggressive, :postflop_passive,
                              :posted, :bet, :cashed, :net, :net_in_bb]

  HAND_RECORD_INCOMPLETE_MESSAGE = "hand record is incomplete"
  PLAYER_RECORDS_NO_PLAYER_REGISTERED = "no players have been registered"
  PLAYER_RECORDS_DUPLICATE_PLAYER_NAME = "player screen_name has been registered twice"
  PLAYER_RECORDS_NO_BUTTON_REGISTERED = "no button has been registered"
  PLAYER_RECORDS_UNREGISTERED_PLAYER = "player has not been registered"
  PLAYER_RECORDS_OUT_OF_BALANCE = "hand record is out of balance"                

  MAX_SEATS = 12
end