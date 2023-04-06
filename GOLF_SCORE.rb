require 'nokogiri'
require 'net/http'
require 'uri'

url = URI.parse('https://www.espn.com/golf/leaderboard')
response = Net::HTTP.get_response(url)
doc = Nokogiri::HTML(response.body)
