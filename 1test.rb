require 'nokogiri'
require 'net/http'
require 'uri'
require 'sqlite3'
require 'csv'

begin
    url = URI.parse('https://www.espn.com/golf/leaderboard')
    response = Net::HTTP.get_response(url)
    doc = Nokogiri::HTML(response.body)
  rescue StandardError => e
    puts "Error fetching/parsing HTML content: #{e}"
  end

  require 'watir'

browser = Watir::Browser.new :chrome, headless: true
browser.goto 'https://www.espn.com/golf/leaderboard'

# Wait for the table to load
browser.div(class: 'competitors').table.wait_until_present

# Get the table rows and extract player names
players = browser.div(class: 'competitors').table.tbody.rows.map do |row|
  name = row.td(class: 'name').a.text
  score = row.td(class: 'toPar').text
  today = row.td(class: 'today').text
  thru = row.td(class: 'thru').text
  "#{name}: #{score} (#{today}) [#{thru}]"
end

browser.close

  File.open("output.txt", "w") do |file|
    file.puts(doc) # Write the document object to the file
    
  end