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
      db.execute "DROP TABLE IF EXISTS max_scores;"
      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS scores (
          id INTEGER PRIMARY KEY,
          player_name TEXT,
          score TEXT,
          today TEXT,
          thru TEXT,
          R1 TEXT,
          R2 TEXT,
          R3 TEXT,
          R4 TEXT,
          position TEXT,
          holes_rem INT,
          pool_score INT
        );
      SQL
      db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS max_scores (
        id INTEGER PRIMARY KEY,
        mr1 INT,
        mr2 INT,
        mr3 INT,
        mr4 INT
      );
        SQL
      db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS teams (
        id INTEGER PRIMARY KEY,
        owner TEXT,
        total_score INTEGER DEFAULT 0,
        team_holes INTEGER DEFAULT 360,
        players_cut INTEGER DEFAULT 0
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
            break if counter == 56
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
  r1 = player["inProgressRound1Strokes"]
  r2 = player["inProgressRound2Strokes"]
  r3 = player["inProgressRound3Strokes"]
  r4 = player["inProgressRound4Strokes"]
  position = player["position"]
  holes_rem = 72
if position == "--" || position == "WD"
  holes_rem = 0
else
  holes_rem -= (r1 != "-" ? 18 : 0) + (r2 != "-" ? 18 : 0) + (r3 != "-" ? 18 : 0) + (r4 != "-" ? 18 : 0)
  if thru.is_a?(String) && (thru.strip == "F" || thru.strip == "-")
    holes_rem -= 0
  elsif thru
    holes_rem -= thru.to_i
  end
end   
# Convert R1, R2, R3, and R4 to integers if possible
  r1 = r1 == "-" ? "-" : r1.to_i - 72
  r2 = r2 == "-" ? "-" : r2.to_i - 72
  r3 = r3 == "-" ? "-" : r3.to_i - 72
  r4 = r4 == "-" ? "-" : r4.to_i - 72
  players << "#{player_name}: #{score} (#{today}) [#{thru}]"
  puts "#{player_name} position = #{position} Holes Remaining = #{holes_rem} "
  db.execute "INSERT INTO scores (player_name, score, today, thru, R1, R2, R3, R4, position, holes_rem) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", player_name, score, today, thru, r1, r2, r3, r4, position, holes_rem
end # Calculate the total score for each team
max_r1 = db.execute("SELECT MAX(R1) FROM scores")[0][0]
max_r2 = db.execute("SELECT MAX(R2) FROM scores")[0][0]
max_r3 = db.execute("SELECT MAX(R3) FROM scores")[0][0]
max_r4 = db.execute("SELECT MAX(R4) FROM scores")[0][0]
# Set the highest score to 0 if it is "-"
max_r1 = max_r1 == "-" ? 0 : max_r1.to_i
max_r2 = max_r2 == "-" ? 0 : max_r2.to_i
max_r3 = max_r3 == "-" ? 0 : max_r3.to_i
max_r4 = max_r4 == "-" ? 0 : max_r4.to_i
db.execute("INSERT INTO max_scores (mr1, mr2, mr3, mr4) VALUES (?, ?, ?, ?)", max_r1, max_r2, max_r3, max_r4)
@max_r1 = max_r1
@max_r2 = max_r2
@max_r3 = max_r3
@max_r4 = max_r4
puts "Max scores from each round: R1 = #{max_r1}, R2 = #{max_r2}, R3 = #{max_r3}, R4 = #{max_r4}"
db.execute("UPDATE scores SET pool_score = CASE
              WHEN position NOT IN ('--', 'WD') THEN
                CASE
                  WHEN score != '-' THEN score
                  ELSE R1 + R2 + R3 + R4
                END
              ELSE 
                CASE
                  WHEN R1 != '-' AND R2 != '-' AND R3 != '-' AND R4 != '-' THEN R1 + R2 + R3 + R4
                  WHEN R1 != '-' AND R2 != '-' AND R3 != '-' THEN R1 + R2 + R3 + #{max_r4}
                  WHEN R1 != '-' AND R2 != '-' AND R4 != '-' THEN R1 + R2 + #{max_r3} + R4
                  WHEN R1 != '-' AND R3 != '-' AND R4 != '-' THEN R1 + #{max_r2} + R3 + R4
                  WHEN R2 != '-' AND R3 != '-' AND R4 != '-' THEN #{max_r1} + R2 + R3 + R4
                  WHEN R1 != '-' AND R2 != '-' THEN R1 + R2 + #{max_r3 + max_r4}
                  WHEN R1 != '-' AND R3 != '-' THEN R1 + R3 + #{max_r2 + max_r4}
                  WHEN R1 != '-' AND R4 != '-' THEN R1 + R4 + #{max_r2 + max_r3}
                  WHEN R2 != '-' AND R3 != '-' THEN R2 + R3 + #{max_r1 + max_r4}
                  WHEN R2 != '-' AND R4 != '-' THEN R2 + R4 + #{max_r1 + max_r3}
                  WHEN R3 != '-' AND R4 != '-' THEN R3 + R4 + #{max_r1 + max_r2}
                  WHEN R1 != '-' THEN R1 + #{max_r2 + max_r3 + max_r4}
                  WHEN R2 != '-' THEN R2 + #{max_r1 + max_r3 + max_r4}
                  WHEN R3 != '-' THEN R3 + #{max_r1 + max_r2 + max_r4}
                  WHEN R4 != '-' THEN R4 + #{max_r1 + max_r2 + max_r3}
                  WHEN R1 == '-' THEN #{max_r1 + max_r2 + max_r3 + max_r4}
                END
            END")


            
# Query the database for all teams
teams = db.execute "SELECT * FROM teams"
# Iterate over each team and calculate the total score
teams.each do |team|
  # Query the database for all player assignments for the current team
  player_assignments = db.execute("SELECT * FROM team_assignments WHERE team_number=?", team[0])
  
  # Calculate the total score and total number of holes played for the current team
  total_score = 0
  cut_players = 0
  player_scores = []
  total_holes = 0

  player_assignments.each do |player_assignment|
    # Query the database for the player's score and thru
    score, thru, today, r1, r2, r3, r4, holes_rem, pool_score = db.execute("SELECT score, thru, today, R1, R2, R3, R4, holes_rem, pool_score FROM scores WHERE player_name=?", player_assignment[1]).first
    puts "#{player_assignment[1]}: #{score}, #{thru}, #{r1}, #{r2}, #{r3}, #{r4}, #{holes_rem}" # Print the score and thru values for each player
    #puts "#{player_assignment[1]}:  #{holes_rem}" # Print the score and thru values for each player
    if holes_rem.nil?
      puts "Warning: #{player_assignment[1]} has no holes remaining"
    else
      total_holes += holes_rem
      puts "Total holes for team #{team[0]} after adding #{player_assignment[1]}: #{total_holes}"
    end
    player_scores << pool_score.to_i
      puts "score is #{player_scores}"
  
  end

  puts "Final total holes for team #{team[0]}: #{total_holes}"
  
  # Remove the highest score
  player_scores.sort!.pop
  
  # Calculate the total score for the current team
  total_score = player_scores.sum

  # Update the teams table with the total score and total number of holes played for the current team
  db.execute("UPDATE teams SET total_score=?, team_holes=? WHERE id=?", total_score, total_holes, team[0])
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