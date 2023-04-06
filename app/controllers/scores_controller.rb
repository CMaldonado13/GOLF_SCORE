class ScoresController < ApplicationController
    def index
      require 'nokogiri'
      require 'net/http'
      require 'uri'
      require 'sqlite3'
      require 'csv'

        csv_path = '/public/TeamList.csv'
  
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
          CSV.foreach('/workspace/GOLF_SCORE/public/TeamList.csv', headers: ['player_name', 'team_number']) do |row|
            break if counter == 55
            player_name = row['player_name']
            team_number = row['team_number']
            db.execute("INSERT INTO team_assignments (player_name, team_number) VALUES (?, ?)", [player_name, team_number])
            counter += 1
          end
        

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
          db.execute "INSERT INTO scores (player_name, score, today, thru) VALUES (?, ?, ?, ?)", player_name, score, today, thru
        end
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
  holes_played = 0
  player_assignments.each do |player_assignment|
    # Query the database for the player's score and thru
    score, thru = db.execute("SELECT score, thru FROM scores WHERE player_name=?", player_assignment[1]).first
    puts "#{player_assignment[1]}: #{score}, #{thru}" # Print the score and thru values for each player
    if score
        if score == "E"
          total_score += 0
        elsif score != "WD"
          total_score += score.to_i
        else
          puts "Warning: #{player_assignment[1]} has a score of WD"
          total_score += 9
        end
      
        if thru.is_a?(String) && thru.strip == "F"
          holes_played += 18
        elsif thru
          holes_played += thru.to_i
        end
      end
    end  

  # Update the teams table with the total score and total number of holes played for the current team
  db.execute("UPDATE teams SET total_score=?, holes_played=? WHERE id=?", total_score, holes_played, team[0])
end

# Query the database for all teams (including the updated total scores)
teams = db.execute "SELECT * FROM teams"
      # Write the list of player names and scores to a file
      File.open("output.txt", "w") do |file|
        players.each do |player|
          file.puts(player)
        end
      end
      # Display the contents of the scores table
      @scores = db.execute("SELECT * FROM scores")
       # Query the database for all teams
  @teams = db.execute "SELECT * FROM teams"
  @team_assignments =db.execute "SELECT * FROM team_assignments"
    end
  end