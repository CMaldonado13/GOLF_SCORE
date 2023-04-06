require 'nokogiri'
require 'net/http'
require 'uri'


url = URI.parse('https://www.espn.com/golf/leaderboard')
response = Net::HTTP.get_response(url)
doc = Nokogiri::HTML(response.body)
# Locate the table element that contains the data
table = doc.css('table').first

# Extract the rows and cells from the table element
rows = table.css('tr')
rows.shift # Remove the header row if present

# Iterate through the rows and extract the data from the "PLAYER" column
players = []
rows.each do |row|
  cols = row.css('td')
  player_link = cols[2].css('a.leaderboard_player_name').first
  if player_link
    player_name = player_link.text.strip
    score = cols[3].text.strip
    today = cols[4].text.strip
    thru = cols[5].text.strip
    players << "#{player_name}: #{score} (#{today}) [#{thru}]"
  end
end

# Write the list of player names and scores to a file
File.open("output.txt", "w") do |file|
  players.each do |player|
    file.puts(player)
  end
end