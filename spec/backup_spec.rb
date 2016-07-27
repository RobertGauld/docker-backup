require_relative 'spec_helper'

describe "Backup" do

  before :each do
    ARGV.clear
  end

  it "Initializes" do
    expect(YAML).to receive(:load_file).and_return( {} )
    expect(File).to receive(:directory?).with('/media/target').and_return( true )
    backup = Backup.new
    expect( backup ).not_to eq(nil)
  end

  it "Default configuration" do
    Timecop.freeze(Time.new(2015, 6, 7, 8, 9))
    expect(YAML).to receive(:load_file).and_return( {} )
    expect(File).to receive(:directory?).with('/media/target').and_return( true )
    backup = Backup.new
    expect( backup.config ).to eq({
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
      "config_file" => "/home/robert/.rbenv/versions/2.3.yml",
      "new_backup_name" => "20150607-0809",
    })
    Timecop.return
  end

  it "Gets configuration from file" do
    Timecop.freeze(Time.new(2015, 6, 7, 8, 9))
    expect(YAML).to receive(:load_file).and_return( {from_file: true} )
    expect(File).to receive(:directory?).with('/media/target').and_return( true )
    backup = Backup.new
    expect( backup.config ).to eq({
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
      :from_file => true,
      "config_file" => "/home/robert/.rbenv/versions/2.3.yml",
      "new_backup_name" => "20150607-0809",
    })
    Timecop.return
  end

  describe "Gets configuration from command line" do
    before :each do
      allow(YAML).to receive(:load_file).and_return( {} )
      allow(File).to receive(:directory?).with('/media/target').and_return( true )
      allow(STDOUT).to receive(:puts).and_return( '' )
    end

    it "--verbose" do
      ARGV = ["--verbose"]
      expect( Backup.new.config['debug'] ).to eq(true)
    end
    it "--no-verbose" do
      ARGV = ["--no-verbose"]
      expect( Backup.new.config['debug'] ).to eq(false)
    end
    it "--debug" do
      ARGV = ["--debug"]
      expect( Backup.new.config['debug'] ).to eq(true)
    end
    it "--no-debug" do
      ARGV = ["--no-debug"]
      expect( Backup.new.config['debug'] ).to eq(false)
    end

    it "--dry-run" do
      ARGV = ["--dry-run"]
      expect( Backup.new.config['dry_run'] ).to eq(true)
    end
    it "--no-dry-run" do
      ARGV = ["--no-dry-run"]
      expect( Backup.new.config['dry_run'] ).to eq(false)
    end

    it "--config-file file" do
      ARGV = ["--config-file", 'file_name']
      expect(YAML).to receive(:load_file).with('file_name').and_return( {} )
      expect(File).to receive(:directory?).with('/media/target').and_return( true )
      expect( Backup.new.config['config_file'] ).to eq('file_name')
    end

    it "--no-config-file" do
      ARGV = ["--no-config-file"]
      expect(YAML).not_to receive(:load_file)
      allow(File).to receive(:directory?).with('/media/target').and_return( true )
      expect( Backup.new.config['config_file'] ).to eq(nil)
    end

    it "--create-config-file file" do
      ARGV = ["--create-config-file", "new_config_file"]
      expect(STDOUT).to receive(:puts).with('Created config file: new_config_file')
      expect(STDOUT).to receive(:puts).with('Please open it, fill in the blanks and uncomment the appropriate lines before using it.')
      file = StringIO.new
      expect(File).to receive(:open).with('new_config_file', 'w').and_yield(file)
      expect(file).to receive(:write)
      expect{ Backup.new }.to exit_with_code(0)
    end

    it "--new-backup-name name" do
      ARGV = ["--new-backup-name", 'backup_name']
      expect(YAML).to receive(:load_file).and_return( {} )
      expect(File).to receive(:directory?).with('/media/target').and_return( true )
      expect( Backup.new.config['new_backup_name'] ).to eq('backup_name')
    end

    it "--no-backup" do
      ARGV = ["--no-backup"]
      expect( Backup.new.config['no_backup'] ).to eq(true)
    end
    it "--only-backup" do
      ARGV = ["--only-backup"]
      expect( Backup.new.config['only_backup'] ).to eq(true)
    end
    it "--no-rotate" do
      ARGV = ["--no-rotate"]
      expect( Backup.new.config['no_rotate'] ).to eq(true)
    end
    it "--only-rotate" do
      ARGV = ["--only-rotate"]
      expect( Backup.new.config['only_rotate'] ).to eq(true)
    end

    it "--help" do
      ARGV = ["--help"]
      expect(STDOUT).to receive(:puts)
      expect{ Backup.new }.to exit_with_code(0)
    end
    it "-h" do
      ARGV = ["-h"]
      expect(STDOUT).to receive(:puts)
      expect{ Backup.new }.to exit_with_code(0)
    end
    it "-?" do
      ARGV = ["-?"]
      expect(STDOUT).to receive(:puts)
      expect{ Backup.new }.to exit_with_code(0)
    end
  end

  describe "Checks config" do
    it "Directory" do
      expect(YAML).to receive(:load_file).and_return( {from_file: true} )
      expect(File).to receive(:directory?).with('/media/target').and_return( false )
      expect(STDOUT).to receive(:puts).with('Missing/Invalid configuration value: directory - where the backups are to be stored')
      expect{ Backup.new }.to exit_with_code(1)
    end

    it "Rsync paths" do
      expect(YAML).to receive(:load_file).and_return( {from_file: true} )
      expect(File).to receive(:directory?).with('/media/target').and_return( true )
      expect(STDOUT).to receive(:puts).with('Missing/Invalid configuration value: rsync_paths - the paths on the server to backup.')
      backup = Backup.new
      expect{ backup.perform_backup }.to exit_with_code(2)
    end
  end

  describe "Run command" do
    it "Dry run" do
      expect(YAML).to receive(:load_file).and_return( {} )
      expect(File).to receive(:directory?).with('/media/target').and_return( true )
      backup = Backup.new
      backup.config['dry_run'] = true
      expect(STDOUT).to receive(:puts).with("Would run: command\n\n")
      expect(backup).not_to receive(:system)
      backup.send(:run_command, 'command')
    end

    it "Debugs" do
      expect(YAML).to receive(:load_file).and_return( {} )
      expect(File).to receive(:directory?).with('/media/target').and_return( true )
      backup = Backup.new
      backup.config['debug'] = true
      expect(STDOUT).to receive(:puts).with("command\n\n")
      expect(backup).to receive(:system).with('command').and_return( true )
      backup.send(:run_command, 'command')
    end

    it "Normally" do
      expect(YAML).to receive(:load_file).and_return( {} )
      expect(File).to receive(:directory?).with('/media/target').and_return( true )
      backup = Backup.new
      expect(STDOUT).not_to receive(:puts)
      expect(backup).to receive(:system).with('command').and_return( true )
      backup.send(:run_command, 'command')
    end
  end # describe run_command

  describe "Performs backup" do
  end

  describe "Performs rotation" do
  end

  describe "Run" do
    before :each do
      expect(YAML).to receive(:load_file).and_return( {} )
      expect(File).to receive(:directory?).with('/media/target').and_return( true )
      @backup = Backup.new
    end

    it "Runs backup and rotate normally" do
      expect(@backup).to receive(:backup).and_return(true)
      expect(@backup).to receive(:rotate).and_return(true)
      expect( @backup.run ).to eq(true)
    end

    it "Runs only backup if option passed" do
      @backup.config['only_backup'] = true
      expect(@backup).to receive(:backup).and_return(true)
      expect(@backup).not_to receive(:rotate)
      expect( @backup.run ).to eq(true)
    end

    it "Runs only rotate if option passed" do
      @backup.config['only_rotate'] = true
      expect(@backup).to receive(:rotate).and_return(true)
      expect(@backup).not_to receive(:backup)
      expect( @backup.run ).to eq(true)
    end

    it "Skips backup if option passed" do
      @backup.config['no_backup'] = true
      expect(@backup).to receive(:rotate).and_return(true)
      expect(@backup).not_to receive(:backup)
      expect( @backup.run ).to eq(true)
    end

    it "Skips rotate if option passed" do
      @backup.config['no_rotate'] = true
      expect(@backup).to receive(:backup).and_return(true)
      expect(@backup).not_to receive(:rotate)
      expect( @backup.run ).to eq(true)
    end
  end


  describe "Actions" do

    before :each do
      Timecop.freeze(Time.new(2016, 7, 1, 6, 30))
      allow(YAML).to receive(:load_file).and_return( {} )
      allow(File).to receive(:directory?).with('/media/target').and_return( true )
      @backup = Backup.new
    end
    after :each do
      Timecop.return
    end

    describe "Create new backup" do
      it "Existing backups" do
        expect(Dir).to receive(:entries).with('/media/target').and_return(['.', '..', 'ignore-this-file', '20160701-0030', '20160630-1830'])
        expect(@backup).to receive(:run_command).with("cp -al '/media/target/20160701-0030' '/media/target/20160701-0630'").and_return(true)
        @backup.create_new_backup
      end

      it "No existing backups" do
        expect(Dir).to receive(:entries).with('/media/target').and_return(['.', '..', 'ignore-this-file'])
        expect(@backup).to_not receive(:run_command)
        @backup.create_new_backup
      end
    end

    describe "Perform backup" do
      it "Runs rsync" do
        expect(@backup).to receive('run_command').with('/usr/bin/rsync --recursive --archive --delete --force --relative --links --owner --group --times --perms --numeric-ids --one-file-system /target/source /media/target/20160701-0630')
        @backup.config.merge!({
          'rsync_paths' => [{'path' => '/target/source'}]
        })
        @backup.perform_backup
      end

      it "Makes rsync verbose in debug mode" do
        expect(@backup).to receive('run_command').with('/usr/bin/rsync --verbose --itemize-changes --human-readable --progress --recursive --archive --delete --force --relative --links --owner --group --times --perms --numeric-ids --one-file-system /target/source /media/target/20160701-0630')
        allow(STDOUT).to receive(:puts)
        @backup.config.merge!({
          'debug' => true,
          'rsync_paths' => [{'path' => '/target/source'}]
        })
        @backup.perform_backup
      end

      it "Uses configured global excludes" do
        expect(@backup).to receive('run_command').with("/usr/bin/rsync --recursive --archive --delete --force --relative --links --owner --group --times --perms --numeric-ids --one-file-system --exclude='global_exclude' --exclude='global_exclude_2' /target/source /media/target/20160701-0630")
        @backup.config.merge!({
          'rsync_paths' => [{'path' => '/target/source'}],
          'rsync_exclude' => ['global_exclude', 'global_exclude_2']
        })
        @backup.perform_backup
      end

      it "Uses configured path specific excludes" do
        expect(@backup).to receive('run_command').with("/usr/bin/rsync --recursive --archive --delete --force --relative --links --owner --group --times --perms --numeric-ids --one-file-system --exclude='global_exclude' --exclude='global_exclude_2' --exclude='path_exclude' --exclude='path_exclude_2' /target/source /media/target/20160701-0630")
        @backup.config.merge!({
          'rsync_paths' => [{'path' => '/target/source', 'exclude' => ['path_exclude', 'path_exclude_2']}],
          'rsync_exclude' => ['global_exclude', 'global_exclude_2']
        })
        @backup.perform_backup
      end

      it "Uses passed backup name" do
        expect(@backup).to receive('run_command').with('/usr/bin/rsync --recursive --archive --delete --force --relative --links --owner --group --times --perms --numeric-ids --one-file-system /target/source /media/target/custom_backup_name')
        @backup.config.merge!({
          'rsync_paths' => [{'path' => '/target/source'}],
          'new_backup_name' => 'custom_backup_name'
        })
        @backup.perform_backup
      end

      it "Uses configured directory" do
        expect(@backup).to receive('run_command').with('/usr/bin/rsync --recursive --archive --delete --force --relative --links --owner --group --times --perms --numeric-ids --one-file-system /target/source /custom/target/20160701-0630')
        @backup.config.merge!({
          'rsync_paths' => [{'path' => '/target/source'}],
          'directory' => '/custom/target'
        })
        @backup.perform_backup
      end

      it "Uses configured server" do
        expect(@backup).to receive('run_command').with('/usr/bin/rsync --recursive --archive --delete --force --relative --links --owner --group --times --perms --numeric-ids --one-file-system server.example.com:/target/source /media/target/20160701-0630')
        @backup.config.merge!({
          'rsync_paths' => [{'path' => '/target/source'}],
          'rsync_server' => 'server.example.com',
        })
        @backup.perform_backup
      end

      it "Uses configured rsync binary" do
        expect(@backup).to receive('run_command').with('/path/to/rsync --recursive --archive --delete --force --relative --links --owner --group --times --perms --numeric-ids --one-file-system /target/source /media/target/20160701-0630')
        @backup.config.merge!({
          'rsync_paths' => [{'path' => '/target/source'}],
          'path_to_rsync' => '/path/to/rsync'
        })
        @backup.perform_backup
      end

      it "Uses configured SSH args" do
        expect(@backup).to receive('run_command').with("/usr/bin/rsync --recursive --archive --delete --force --relative --links --owner --group --times --perms --numeric-ids --rsh='-p 2022' --one-file-system /target/source /media/target/20160701-0630")
        @backup.config.merge!({
          'rsync_paths' => [{'path' => '/target/source'}],
          'rsync_ssh_args' => '-p 2022'
        })
        @backup.perform_backup
      end

      it "Honors configured one file system option" do
        expect(@backup).to receive('run_command').with('/usr/bin/rsync --recursive --archive --delete --force --relative --links --owner --group --times --perms --numeric-ids /target/source /media/target/20160701-0630')
        @backup.config.merge!({
          'rsync_paths' => [{'path' => '/target/source'}],
          'rsync_one_fs' => false
        })
        @backup.perform_backup
      end

    end

    describe "Rotate" do
      before :each do
        @entries = ['.', '..', 'ignore_this_file', '20161231-0000']
        expect(YAML).to receive(:load_file).and_return( {} )
        allow(File).to receive('directory?').and_return( true )
      end

      it "Honors all_from_last_days" do
        @entries += ['20160701-0200', '20160630-0800', '20160630-1234', '20160629-0200', '20160629-2359']
        expect(Dir).to receive(:entries).with('/media/target').and_return( @entries )
        backup = Backup.new
        backup.config.merge!(
          'all_from_last_days' => 1,
          'dailies' => -1,
          'weeklies' => -1,
          'monthlies' => -1,
        )
        expect(FileUtils).to receive(:rm_rf).with('/media/target/20160629-0200')
        expect(FileUtils).to receive(:rm_rf).with('/media/target/20160629-2359')
        backup.rotate
      end

      it "Honors dailies" do
        @entries += ['20160701-0100', '20160701-2300', '20160630-0100', '20160629-0100']
        expect(Dir).to receive(:entries).with('/media/target').and_return( @entries )
        backup = Backup.new
        backup.config.merge!(
          'all_from_last_days' => -1,
          'dailies' => 2,
          'weeklies' => -1,
          'monthlies' => -1,
        )
        expect(FileUtils).to receive(:rm_rf).with('/media/target/20160701-0100')
        expect(FileUtils).to receive(:rm_rf).with('/media/target/20160629-0100')
        backup.rotate
      end

      it "Honors weeklies" do
        @entries += ['20160701-0100', '20160627-0100', '20160626-0100', '20160620-0100', '20160614-0900']
        expect(Dir).to receive(:entries).with('/media/target').and_return( @entries )
        backup = Backup.new
        backup.config.merge!(
          'all_from_last_days' => -1,
          'dailies' => -1,
          'weeklies' => 2,
          'monthlies' => -1,
          'weekly_on' => 1,
        )
        expect(FileUtils).to receive(:rm_rf).with('/media/target/20160701-0100')
        expect(FileUtils).to receive(:rm_rf).with('/media/target/20160626-0100')
        expect(FileUtils).to receive(:rm_rf).with('/media/target/20160614-0900')
        backup.rotate
      end

      it "Honors weekly_on" do
        @entries += ['20160701-0100', '20160623-0100', '20160624-0100', '20160617-0100']
        expect(Dir).to receive(:entries).with('/media/target').and_return( @entries )
        backup = Backup.new
        backup.config.merge!(
          'all_from_last_days' => -1,
          'dailies' => -1,
          'weeklies' => 1,
          'monthlies' => -1,
          'weekly_on' => 5,
        )
        expect(FileUtils).to receive(:rm_rf).with('/media/target/20160623-0100')
        expect(FileUtils).to receive(:rm_rf).with('/media/target/20160617-0100')
        backup.rotate
      end

      it "Honors monthlies" do
        @entries += ['20160701-0900', '20160701-0100', '20160615-0100', '20160510-1000', '20160412-0900']
        expect(Dir).to receive(:entries).with('/media/target').and_return( @entries )
        backup = Backup.new
        backup.config.merge!(
          'all_from_last_days' => -1,
          'dailies' => -1,
          'weeklies' => -1,
          'monthlies' => 2,
        )
        expect(FileUtils).to receive(:rm_rf).with('/media/target/20160701-0900')
        expect(FileUtils).to receive(:rm_rf).with('/media/target/20160412-0900')
        backup.rotate
      end

    end # describe rotate

  end # describe actions

end
