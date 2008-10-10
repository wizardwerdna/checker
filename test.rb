players = {}
players[:andy] = {:seat => 3}
players[:judi] = {:seat => 5}
players[:mike] = {:seat => 9}

0.upto(10) do |button|
  puts "---------"
  puts "button is #{button}"
  temp = players.keys.sort{|a, b| button; (players[a][:seat]-button-1+11)%11 <=> (players[b][:seat]-button-1+11)%11}
  temp.unshift temp.pop
  temp.each do |key|
    puts "#{players[key][:seat]}#{key}"
  end
end