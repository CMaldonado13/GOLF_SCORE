class ScoresController < ApplicationController
    def index
      require 'nokogiri'
      require 'net/http'
      require 'uri'
      require 'sqlite3'
  
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
      = 
      db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS teams (
        id INTEGER PRIMARY KEY,
        owner TEXT
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
            team_id INTEGER,
            player_id INTEGER,
            FOREIGN KEY(team_id) REFERENCES teams(id),
            FOREIGN KEY(player_id) REFERENCES scores(id)
        );
        SQL
        

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
    end
  end