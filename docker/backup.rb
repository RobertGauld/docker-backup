#!/usr/bin/env ruby

# Uses rsync to maintain multiple deduplicated backups (ala rsnapshot)
# Directories named by date and time eg 20101112-0456 for 4:56 AM on 12 Nov 2010

require 'date'
require 'fileutils'
require 'optparse'
require 'yaml'



class Backup

  attr_accessor :config

  def debug?
    @config['debug']
  end
  def dry_run?
    @config['dry_run']
  end
  def wet_run?
    !@config['dry_run']
  end

  def initialize
    initialize_config
    initialize_options
    initialize_opt_parser

    @opt_parser.parse(ARGV)
    @config.merge!(YAML.load_file(@options['config_file'])) if @options['config_file']
    @config.merge!(@options)
    @config['new_backup_name'] ||= DateTime.now.strftime('%Y%m%d-%H%M')

    unless File.directory?(@config['directory'])
      puts "Missing/Invalid configuration value: directory - where the backups are to be stored"
      exit 1
    end

    if debug?
      puts "Arguments:\t#{ARGV}"
      puts "Config file: #{@options['config_file']}"
      puts "Backup directory: #{@config['directory']}"
      puts "Keeping all from the last #{@config['all_from_last_days'].to_i} days."
      puts "Keeping the latest from each day for #{@config['dailies'].to_i} days."
      puts "Keeping the earliest for each week for #{@config['weeklies'].to_i} weeks.."
      puts "Keeping the earliest for each month for #{@config['monthlies'].to_i} months."
      puts "Weekly backups are the ones done on day #{@config['weekly_on']} (#{Date::DAYNAMES[@config['weekly_on']]})."
      puts "New backup name: #{@config['new_backup_name']}." if @config['new_backup_name']
      puts "Doing a dry run." if dry_run?
      puts
    end
  end


  def run
    unless any_config?(['no_backup', 'only_rotate'])
      backup
    end

    unless any_config?(['no_rotate', 'only_backup'])
      rotate
    end

    true
  end # run


  def backup
    create_new_backup
    perform_backup
  end


  def rotate
    today = Date.today
    daily_from = today - (@config['dailies'].to_i - 1)
    weekly_from = today - (@config['weeklies'].to_i * 7)
    monthly_from = today << @config['monthlies'].to_i
    keep_all_after = today - @config['all_from_last_days'].to_i
    weekly_on = @config['weekly_on'].to_i
    directory = @config['directory']

    # Get lists of backups
    files = Dir.entries(directory)
    files.select!{ |i| i.match(/\d{8}-\d{4}/) && File.directory?("#{directory}/#{i}") }
    files.sort!
    files.map! do |file|
      date, time = file.match(/(\d{8})-(\d{4})/).captures
      day = Date.strptime(date, '%Y%m%d')
      week = day - day.wday + weekly_on
      week -= 7 if day.wday < weekly_on
      month = day - day.day + 1
      month = month.strftime('%Y%m')
      {
        file_name: file,
        file_path: "#{directory}/#{file}",
        day: day,
        week: week,
        month: month,
        time: time,
        keep: false,
      }
    end # map files

  # Find which backups to delete
  # We want to keep any backup since config['all_from_last_days']
    puts if debug?
    files.select{ |data| data[:day] >= keep_all_after }.each do |data|
      puts "Keeping #{data[:file_name]} - made in last #{config['all_from_last_days']} days." if debug?
      data[:keep] = true
    end
    # We want to keep the latest of each day for the last config['dailies'] days
    files.select{ |data| data[:day] >= daily_from }.group_by{ |data| data[:day] }.each do |day, datas|
      data = datas[-1]
      puts "Keeping #{data[:file_name]} - daily." if debug?
      data[:keep] = true
    end
    # We want to keep the earliest from each week for the last config['weeklies'] weeks
    files.select{ |data| data[:day] >= weekly_from }.group_by{ |data| data[:week] }.each do |week, datas|
      data = datas[0]
      puts "Keeping #{data[:file_name]} - weekly." if debug?
      data[:keep] = true
    end
    # We want to keep the earliest from each month for the last config['monthlies'] months
    files.select{ |data| data[:day] >= monthly_from }.group_by{ |data| data[:month] }.each do |week, datas|
      data = datas[0]
      puts "Keeping #{data[:file_name]} - monthly." if debug?
      data[:keep] = true
    end

    # List files if debugging
    if debug?
      puts
      files.each do |data|
        puts "#{data[:file_path]}\t#{data[:keep] ? 'KEEP' : 'delete'}"
      end
      puts
    end

    # Delete old backups
    files.select{ |data| !data[:keep] }.each do |data|
      file = data[:file_path]
      if dry_run?
        puts "Would delete #{file}"
      else
        puts "Deleting #{file}" if debug?
        FileUtils.rm_rf(file)
      end
    end

  end # rotate


  def create_new_backup
    latest_name = Dir.entries(@config['directory']).select{ |i| i.match(/\d{8}-\d{4}/) }.sort[-1]
    latest_path = "#{@config['directory']}/#{latest_name}"

    if latest_name.nil?
      puts "No latest backup!\n\n" if debug?
    else
      puts "Latest backup: #{latest_name}" if debug?
      run_command "cp -al '#{latest_path}' '#{new_backup_path}'"
    end
  end


  def perform_backup
    if @config['rsync_paths'].nil? || @config['rsync_paths'].empty?
      puts "Missing/Invalid configuration value: rsync_paths - the paths on the server to backup."
      exit 2
    end

    base_rsync_command = @config['path_to_rsync']
    base_rsync_command << ' --verbose --itemize-changes --human-readable --progress' if debug?
    base_rsync_command << ' --recursive --archive --delete --force --relative --links --owner --group --times --perms --numeric-ids'
    base_rsync_command << " --rsh='#{config['rsync_ssh_args']}'" if config['rsync_ssh_args']
    base_rsync_command << ' --one-file-system' if config['rsync_one_fs']
    config['rsync_exclude'].each do |path|
      base_rsync_command << " --exclude='#{path}'"
    end

    if debug?
      puts "base rsync command:\n#{base_rsync_command}"
      puts
    end


    @config['rsync_paths'].each do |rsync_path|
      path = rsync_path.is_a?(String) ? rsync_path : rsync_path['path']
      path = "#{config['rsync_server']}:#{path}" unless config['rsync_server'].nil? || config['rsync_server'].eql?('')
      excludes = rsync_path.is_a?(Hash) ? rsync_path['exclude'] || [] : []
      rsync_command = base_rsync_command.dup
      excludes.each do |exclude|
        rsync_command << " --exclude='#{exclude}'"
      end
      rsync_command << " #{path} #{new_backup_path}"
      run_command rsync_command
    end # each rsync_path
  end # perform_backup


  private
  def run_command(command)
    if dry_run?
      puts "Would run: #{command}\n\n"
    else
      puts "#{command}\n\n" if debug?
      system command
    end
  end

  def write_blank_config(file)
    File.open(file, 'w') do |f|
      f.write <<CONFIG_TEMPLATE
---
# Where the backups are stored
directory: "/media/target"
# What to backup
rsync_server: "SERVER TO BAKUP - SET TO EMPTY STRING TO USE LOACAL FILE SYSTEM"
rsync_paths:
  - path: 'PATH TO BACKUP'
  - path: 'ANOTHER PATH TO BACKUP'
    exclude:
     - 'FILE TO EXCLUDE'
     - 'ANOTHER FILE TO EXCLUDE'
  ADD AS MANY OTHERS AS YOU WISH
rsync_exclude:
  - 'FILE TO EXCLUDE FOR ALL PATHS LISTED ABOVE'
# Where to find rsync (defaults to the result of where rsync)
#path_to_rsync: '/usr/bin/rsync'
# Options for rsync
#rsync_ssh_args: '-p 2022'
rsync_one_fs: true
# How many backups to keep
all_from_last_days: 7
dailies: 7
weeklies: 5
monthlies: 6
# Which day of the week to keep weekly backups for (1=Monday, 0=Sunday)
weekly_on: 1
# Enable different modes of operation
debug: false
dry_run: false
CONFIG_TEMPLATE
    end
    puts "Created config file: #{file}"
    puts "Please open it, fill in the blanks and uncomment the appropriate lines before using it."
    exit
  end

  def any_config?(keys, value=true)
    [*keys].each do |key|
      return true if @config[key].eql?(value)
    end
    return false
  end

  def initialize_config
    @config = {
      'dailies' => 7,
      'weeklies' => 5,
      'monthlies' => 6,
      'all_from_last_days' => 7,
      'debug' => false,
      'dry_run' => false,
      'weekly_on' => 1,
      'rsync_one_fs' => true,
      'rsync_ssh_args' => nil,
      'path_to_rsync' => `which rsync`.strip,
      'rsync_exclude' => [],
      'directory' => '/media/target',
      'no_backup' => false,
      'only_backup' => false,
      'no_rotate' => false,
      'only_rotate' => false,
    }
  end

  def initialize_options
    @options = {
      'config_file' => $0.split('.')[0..-2].join('.') + '.yml',
    }
  end

  def initialize_opt_parser
    @opt_parser = OptionParser.new do |opt|
      opt.banner = "Usage: #{$0} [OPTIONS]"
      opt.separator ""
      opt.separator "Options"

      opt.on("--[no-]verbose", "--[no-]debug", "Debug/Verbose mode") do |v|
        @options['debug'] = v
      end

      opt.on("--[no-]dry-run", "Dry run mode") do |v|
        @options['dry_run'] = v
      end

      opt.on("--config-file [FILE]", "Configuration file to use (default: #{@options['config_file']})") do |file|
        @options['config_file'] = file
      end

      opt.on("--no-config-file", "Don't use a configuration file") do |file|
        @options['config_file'] = nil
      end

      opt.on("--create-config-file [FILE]", "Create template config file and exit") do |file|
        write_blank_config(file)
      end

      opt.on("--new-backup-name [NAME]", "Name to use for the new backup directory (like: YYYYmmdd-HHMM)") do |file|
        @options['new_backup_name'] = file
      end

      ['backup', 'rotate'].each do |op|
        opt.on("--no-#{op}", "Don't perform the #{op} operation") do
          @options["no_#{op}"] = true
        end
        opt.on("--only-#{op}", "Only perform the #{op} operation)") do
          @options["only_#{op}"] = true
        end
      end

      opt.on("-?", "-h", "--help", "Display usage instructions and exit") do
        puts @opt_parser
        exit
      end
    end
  end # initialize opt_parser

  def new_backup_name
    @config['new_backup_name'] || DateTime.now.strftime('%Y%m%d-%H%M')
  end
  def new_backup_path
    "#{@config['directory']}/#{new_backup_name}"
  end

end # class Backup



# Only run the below code if the file is being executed rather than included
if __FILE__ == $0
  backup = Backup.new
  backup.run
end
