# frozen_string_literal: true

require 'csv'

class RosterPlayer < ApplicationRecord
  belongs_to :general_manager
  belongs_to :player
  has_many :skater_game_statlines, primary_key: :player_id, foreign_key: :skater_id

  validates :player_id, uniqueness: { scope: %i[round general_manager] }
  before_save :update_stats

  def self.import(file, round, gm)
    team_abbreviations = Player.distinct.pluck(:team)
    errors = []
    i = 3

    CSV.parse(File.readlines(file.path).drop(3).join) do |row|
      i += 1
      case round
      when '1'
        category_column = 0
        player_column = 1
      when '2'
        category_column = 4
        player_column = 5
      when '3'
        category_column = 8
        player_column = 9
      when '4'
        category_column = 12
        player_column = 13
      end

      next if row[category_column].nil? || %w[FORWARDS DEFENCE GOALIE].include?(row[category_column])

      player_info = row[player_column].split(' (')
      errors << "Player at row #{i} was written improperly" && next if player_info.length != 2

      team = player_info[1].gsub!(/[()]/, '')
      last_name = player_info[0]

      player = Player.where('lower(last_name) = ? AND team = ?', last_name.downcase, team).first

      if player.nil?
        errors << "Unknown team: #{team} at row #{i} make sure you have the proper abbreviation" unless team_abbreviations.include?(team)
        errors << "Unknown player: #{last_name} at row #{i} make sure you have the proper abbreviation" unless Player.where('lower(last_name) = ?', last_name.downcase).any?
        next
      end

      gm.roster_players.build(player_id: player.id, position: player.position_category, general_manager_id: gm.id, league_id: gm.league_id, round: round).save
    end

    errors
  end

  def not_played?
    series_starts = Round.start_time_hash
    return false if series_starts[team.to_sym][round][:start_time] == true || Time.now.utc > series_starts[team.to_sym][round][:start_time]

    true
  end

  private

  def update_stats
    if position == 'G'
      goalie = Goalie.find_by(id: player_id)
      return if goalie.nil?

      goalie.update_statline
    else
      skater = Skater.find_by(id: player_id)
      return if skater.nil?

      skater.update_statline
    end
  end
end
