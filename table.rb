printf "%20s\n", "wizardwerdna".center(20)
printf "%20s\n", "Semi-LOOSE Bomb".center(20)
printf "%20s\n", "(Agressive/Agressive)".center(20)

def doit(players)
  puts " "*30 + (players[0][0]).center(20) + " "*30
  puts " "*30 + (players[0][1]).center(20) + " "*30
  puts " "*30 + (players[0][2]).center(20) + " "*30
  puts
  puts " "*15 + (players[9][0]).center(20) + " "*10 + (players[1][0]).center(20) + " "*15
  puts " "*15 + (players[9][1]).center(20) + " "*10 + (players[1][1]).center(20) + " "*15
  puts " "*15 + (players[9][2]).center(20) + " "*10 + (players[1][2]).center(20) + " "*15
  puts
  puts (players[8][0]).center(20) + " "*40 + (players[2][0]).center(20)
  puts (players[8][1]).center(20) + " "*40 + (players[2][1]).center(20)
  puts (players[8][2]).center(20) + " "*40 + (players[2][2]).center(20)
  puts
  puts (players[7][0]).center(20) + " "*40 + (players[3][0]).center(20)
  puts (players[7][1]).center(20) + " "*40 + (players[3][1]).center(20)
  puts (players[7][2]).center(20) + " "*40 + (players[3][2]).center(20)
  puts
  puts " "*15 + (players[6][0]).center(20) + " "*10 + (players[4][0]).center(20) + " "*15
  puts " "*15 + (players[6][1]).center(20) + " "*10 + (players[4][1]).center(20) + " "*15
  puts " "*15 + (players[6][2]).center(20) + " "*10 + (players[4][2]).center(20) + " "*15
  puts
  puts " "*30 + (players[5][0]).center(20) + " "*30
  puts " "*30 + (players[5][1]).center(20) + " "*30
  puts " "*30 + (players[5][2]).center(20) + " "*30
end

players = []
(0..9).each do |i|
  players[i] = []
  players[i][0] = "wizardwerdna".center(20)
  players[i][1] = "Semi-Loose Bomb".center(20)
  players[i][2] = "(Agg/Agg)"
end
doit(players)