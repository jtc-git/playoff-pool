# frozen_string_literal: true

namespace :daily_functions do
  # Have this check once a day at noon before any games are played to see if new round will start that day so lineups get locked
  desc 'Check if the current round has changed and set accordingly'
  task set_round: :environment do
    message = Scraper.games_today? ? Round.set_round : 'There are no games today. Will check for a new round again tomorrow.'
    puts message
  end

  desc 'Set hash for series start times to allow lineups to be set up until the last possible second'
  task set_series_starts: :environment do
    Round.scrape_series_start_times
  end

  # Have this run overnight to double check old games still have the correct statlines
  desc 'Update games being played or already played on selected date'
  task update_stats: :environment do
    if Round.current_round.zero?
      p 'League has not started, set round to at least 1 before trying again'
      next
    end

    if Time.now < '11:00:00'.to_time # In Heroku's timezone, its 7AM EST
      date = 12.hours.ago.to_datetime
    else
      date = Time.now.to_datetime
    end

    puts "Starting Daily Scrape for #{date.strftime('%m-%d-%y')}..."
    Scraper.update_day_of_games(date.strftime('%Y-%m-%d').to_s)
    League.all.update_all(scraped_at: Time.now)
    puts "Ending Daily Scrape for #{date.strftime('%m-%d-%y')}"
  end

  desc 'Scrape the games played the previous week to fix any statistical changes'
  task scrape: :environment do
    if Round.current_round.zero?
      p 'League has not started, set round to at least 1 before trying again'
      next
    end

    end_date = 12.hours.ago.to_date
    start_date = 8.days.ago.to_date
    Player.seed # Make sure all players exist so new callups don't break everything

    puts 'Starting Daily Scrape...'
    Scraper.scrape_range_of_dates(start_date, end_date)
    puts 'Ending Daily Scrape!'
  end
end
