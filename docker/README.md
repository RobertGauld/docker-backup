# backup
Backup a (remote) filesystem folder(s) in an rsnapshot like way.
Like rsnalshot it uses rsync and hard links to allow for deduplication.
Unlike rsnapshot it uses folders named with a date and time rather than an intervan and a number.


## To use:
1. Generate a public/private key pair and save them into a new folder
2. Copy the sample config file and edit it to meet your needs
3. Connect the following to the mount points:
  * /root/backup.yml - the configuration file you edited above
  * /root/.ssh - the folder containing your private/public keys
  * /media/target - the folder to store the backups in
4. Start the container and execute /root/backup.rb on your required schedule


## Example config
```
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
# Enable different modes of operation
debug: false
dry_run: false
```
