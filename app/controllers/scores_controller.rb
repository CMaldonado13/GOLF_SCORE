class ScoresController < ApplicationController
 
    def index
      require 'nokogiri'
      require 'net/http'
      require 'uri'
      require 'sqlite3'
      require 'csv'
      require 'json'
      require 'mechanize'
      require 'open-uri'
    
      
      csv_path = Rails.root.join('public', 'TeamList.csv')

  
      # Open a connection to the database
      db = SQLite3::Database.new "golf_scores.db"
  
      # Create a "scores" table if it doesn't already exist
      db.execute "DROP TABLE IF EXISTS scores;"
      db.execute "DROP TABLE IF EXISTS teams;"
      db.execute "DROP TABLE IF EXISTS team_assignments;"
      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS scores (
          id INTEGER PRIMARY KEY,
          player_name TEXT,
          score TEXT,
          today TEXT,
          thru TEXT
        );
      SQL
      
      db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS teams (
        id INTEGER PRIMARY KEY,
        owner TEXT,
        total_score INTEGER DEFAULT 0,
        holes_played INTEGER DEFAULT 0
      );
        SQL

        db.execute <<-SQL
            INSERT INTO teams (owner) VALUES
            ('Collin'),
            ('John'),
            ('Greyson'),
            ('Sujay'),
            ('Christian S'),
            ('Mike'),
            ('Nick'),
            ('Christian M'),
            ('JJ'),
            ('Matt'),
            ('Owen');
            SQL
            db.execute <<-SQL
            CREATE TABLE IF NOT EXISTS team_assignments (
              id INTEGER PRIMARY KEY,
              player_name TEXT,
              team_number INTEGER
           );
          SQL
          counter = 0
          # Read the player assignments from a CSV file and insert them into the table
          CSV.foreach(csv_path, headers: ['player_name', 'team_number']) do |row|
            break if counter == 55
            player_name = row['player_name']
            team_number = row['team_number']
            db.execute("INSERT INTO team_assignments (player_name, team_number) VALUES (?, ?)", [player_name, team_number])
            counter += 1
          end
  # Visit the web page with Mechanize
url = 'https://golfweek.sportsdirectinc.com/golf/pga-results.aspx?page=/data/pga/leaderboard/leaderboard1_total.html'
agent = Mechanize.new
page = agent.get(url)

# Parse the HTML with Nokogiri and locate the script element containing player details
doc = Nokogiri::HTML(page.body)
players_details = doc.css('script').text[/var playersDetails = (\[.*?\]);/m, 1]

# Parse the JSON data and extract the player details
players_details = JSON.parse(players_details)
# Iterate through the players and output their details
players = []
players_details.each do |player|
  player_name = player["playerName"]
  score = player["total"]
  today = player["inProgressCurrScore"]
  thru = player["thru"]
  players << "#{player_name}: #{score} (#{today}) [#{thru}]"
  db.execute "INSERT INTO scores (player_name, score, today, thru) VALUES (?, ?, ?, ?)", player_name, score, today, thru
end
   # Calculate the total score for each team
   # Query the database for all teams
   teams = db.execute "SELECT * FROM teams"
   # Iterate over each team and calculate the total score
   teams.each do |team|
     # Query the database for all player assignments for the current team
     player_assignments = db.execute("SELECT * FROM team_assignments WHERE team_number=?", team[0])
     # Calculate the total score and total number of holes played for the current team
     total_score = 0
     holes_played = 90
     player_scores = []
     player_assignments.each do |player_assignment|
       # Query the database for the player's score and thru
       score, thru = db.execute("SELECT score, thru FROM scores WHERE player_name=?", player_assignment[1]).first
       puts "#{player_assignment[1]}: #{score}, #{thru}" # Print the score and thru values for each player
       if score
         if score == "E"
           player_scores << 0
         elsif score != "-"
           player_scores << score.to_i
         else
           puts "Warning: #{player_assignment[1]} has a score of WD"
           player_scores << 9
         end
         if thru.is_a?(String) && (thru.strip == "F" || thru.strip == "-")
           holes_played += 18
         elsif thru
           holes_played += thru.to_i
         end
       end
     end
   
     # Remove the highest score
     player_scores.sort!.pop
   
     # Calculate the total score for the current team
     total_score = player_scores.sum
   
     # Update the teams table with the total score and total number of holes played for the current team
     db.execute("UPDATE teams SET total_score=?, holes_played=? WHERE id=?", total_score, holes_played, team[0])
   end
   

# Query the database for all teams (including the updated total scores)
teams = db.execute "SELECT * FROM teams"
      # Display the contents of the scores table
  @scores = db.execute("SELECT * FROM scores")
  # Query the database for all teams
  @teams = db.execute "SELECT * FROM teams"
  @team_assignments =db.execute "SELECT * FROM team_assignments"
    end
  end