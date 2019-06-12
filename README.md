# backup-mongodb
Backup MongoDB to anywhere

## Overview
Use a container to back up MongoDB in a practical way

Features:

* dump and restore
* dump For local volumes, windows shares or Bucket s3
* Simply enter the database, username and password
* It connects to any MOngodb available via network, it can be dockerizado or not
* Choose how often DUMPS occur
* Select the schedule that the dump should happen, or leave this default value as the time the container went up



## Backup
To run a backup, run the image as a container with the correct parameters. Everything is controlled by environment variables passed pro container.

Por exemplo:

````bash
docker run -d --restart=always -e DB_DUMP_FREQ=60 -e DB_DUMP_BEGIN=2330 -e DB_DUMP_TARGET=/db -e MONGO_URI=mongodb://db:27017/database -v /local/file/path:/db atilaloise/mongodb-backup
````
The above example dumps the uri baseevery 60 minutes, starting at 11:30 pm local time

## Stack example

```
  MongoDB-backup:
    image: atilaloise/mongodb-backup
    environment:
      - MONGO_URI=mongodb://db:27017/database
      - DB_DUMP_TARGET=s3://dumps/MongoDBhomolog
      - DB_DUMP_BEGIN=1205
      - AWS_ACCESS_KEY_ID=teste
      - AWS_SECRET_ACCESS_KEY=aeuiaehuep4ssw0rd
      - AWS_ENDPOINT_URL=https://minio.lab.test
      - COMPRESSION=bzip2
    volumes:
      - /etc/localtime:/etc/localtime:ro
    networks:
      - app
```

## Environment variables


* `MONGO_URI`: Connection string with mongoDB. MANDATORY.
* `DB_DUMP_FREQ`: Frequency of dump, in minutes. Default `1440` minutes = once per day.
* `DB_DUMP_BEGIN`: Time to do Dumps. Default `Immediately while rotating the container`. Define using the syntax:
    * Absolute: HHMM. for example at 23:30 use `2330` or at 04:15 use` 0415`
    * Relative: + MM. How many minutes after the container is started. Example `+ 0` (immediately),` + 10` (in 10 minutes), or `+ 90` in an hour and a half
* `DB_DUMP_CRON`: Use crontab syntax to set scheduling (https://en.wikipedia.org/wiki/Cron), UNIQUE LINE.
* `RUN_ONCE`: Kills the container after running the backup. Useful if you use an external scheduler like rundeck. when using this variable, all other scheduling variables like `DB_DUMP_FREQ`,` DB_DUMP_BEGIN` and `DB_DUMP_CRON` will be ignored.
* `DB_DUMP_DEBUG`: Set to` true`, to show the full output of the scripts
* `DB_DUMP_TARGET`: Destination of the dumps. It needs to be a directory. If you want to send to multiple destinations, inform the targets by separating them with spaces. Supports 3 target formats:
    * Local: If the value of `DB_DUMP_TARGET` starts with a` / `, the dump goes to a local destination, which must be a volume mounted inside the container.
    * SMB: If the value of `DB_DUMP_TARGET` is an address in` smb: // hostname / share / path / `format then SMB will be used.
    * S3: If the value of `DB_DUMP_TARGET` is an address in` s3: // bucketname / path` format then awscli will be used.
* `AWS_ACCESS_KEY_ID`: Access key of S3
* `AWS_SECRET_ACCESS_KEY`: Secret key of S3
* `AWS_DEFAULT_REGION`: Region. `Do not set anything when using minio as destination`
* `AWS_ENDPOINT_URL`: address of S3 Server. ex: https://minio.lab.test
* `SMB_USER`: SMB user. Use when `DB_DUMP_TARGET` is an address` smb: // `. You can leave this variable blank and pass it all in the `smb: //` url.
* `SMB_PASS`: PasswordSMB. Use when `DB_DUMP_TARGET` is an address` smb: // `. You can leave this variable blank and pass it all in the `smb: //` url.
* `COMPRESSION`: Compress backup. They are supported: `gzip` (default) and` bzip2`
* `DB_DUMP_KEEP_PERMISSIONS`: holds dump file permissions during copying using` cp -a`. If the target filesystem does not work properly with this, you can disable it by setting `DB_DUMP_KEEP_PERMISSIONS = false`. Default = `true`.


### Scheduling
You can schedule backups in 3 ways

* `RUN_ONCE`: Rotate once and exit.
* `DB_DUMP_FREQ` and` DB_DUMP_BEGIN`: Set the time interval for the backup to occur (`in minutes`) and the backup start time;
* `DB_DUMP_CRON`: Run according to a crontab schedule.

#### Cron Scheduling
If a backup scheduled with cron exceeds the time to start next, then this second backup will be ignored. For example, if you set up an hourly backup as follows:

```
0 * * * *
```

If the backup that started at 1:00 p.m. ends at 2:05 p.m., then the next backup will only happen at 3:00 p.m.
This behavior is dictated by the Cron algorithm


#### Priority
If you set the 3 scheduling options, they will have the following precedence over each other.

1. `RUN_ONCE` runs once and exits, everything else is ignored.
2. `DB_DUMP_CRON`: runs according to the cron schedule set and ignores` DB_DUMP_FREQ` and `DB_DUMP_BEGIN`.
3. `DB_DUMP_FREQ` and` DB_DUMP_BEGIN`: If the other options were not set


### Permissions

By default, the process does not run as root. The default user of this image is the `appuser` with UID / GID` 1005`. You may not be able to access some volumes whose permissions only give administrators access.

In these cases, you have two options:

* Rotate the container as root, `docker run --user 0 ...` or, in `docker - compose.yml`, set `user0`
* Give write permission to the UID or GID `1005`.

### Database Container

To do the dump, `backup-mongodb` needs to connect to the database via the network. You ** are required ** to inform the pgsql server - which can be the pgsql container name inside the stack or standalone docker, or any hostname accessible from the backups container - via the `MONGO_URI` variable, using the hostname or the server ip.


````bash
docker run -d --restart=always -e MONGO_URI=mongodb://db:27017/database -e DB_DUMP_FREQ=60 -e DB_DUMP_BEGIN=2330 -e DB_DUMP_TARGET=/db  -v /local/file/path:/db atilaloise/mongodb-backup
````


### Dump Target
This is where you want the backup to be saved. The file will always be compressed and will follow the format of the following name:

`db_backup_YYYYMMDDHHmm.<compression>`

As:

* YYYY = Year "4 digits"
* MM = Month range 01-12
* DD = date range  01-31
* HH = hour range  00-23
* mm = minute range 00-59
* compression = appropriate extension for the chosen compression type `gz` (gzip; `bz2` (bzip2)



By default, the backup directory is `/ backup` inside the container. Ensure that you have mounted some external volume, after all it is no use to backup the die with the container.

If you use a `smb: // host / share / path` url, the backup will be sent to an SMB server. if you need to pass credentials, use `smb: // user: pass @ host / share / path`.

Note that for smb, if the user belongs to a domain, you should use ';' as a separator between user; domain to pass correctly in the url.

So, `smb://mydom;myuser:pass@host/share/path`

If the url is of type `s3: // bucket / path`, the backup will be saved in a S3 bucket.

Credentials must be passed in `AWS_ACCESS_KEY_ID`,` AWS_SECRET_ACCESS_KEY` and `AWS_DEFAULT_REGION` variables when using amazon

For interoperable systems such as MInio, digitalOcean, and other "S3 like" servers, enter the http address through the variable `AWS_ENDPOINT_URL` for example` https: // minio.lab.test` and set the `DB_DUMP_TARGET` to `s3://bucketname/path`.


## Restore
### Dump Restore

To restore a backup you can also use this same image.

Just use the following environment variables:

* `MONGO_URI`: Connection String . MANDATORY.
* `DB_RESTORE_TARGET`: Backup path that will be restored, either local or SMB or S3
* `DB_DUMP_DEBUG`: Enables the debug of the output of the scripts and shows in the container's logs.
* To use S3, you must set `AWS_ACCESS_KEY_ID`,` AWS_SECRET_ACCESS_KEY` and `AWS_DEFAULT_REGION`


Examples:

1. Restore from a local file: `docker run -e MONGO_URI=mongodb://db:27017/database  -e DB_RESTORE_TARGET=/backup/db_backup_201509271627.gz -v /local/path:/backup atilaloise/mongodb-backup`
2. Restore from SMB share: `docker run -e MONGO_URI=mongodb://db:27017/database -e DB_RESTORE_TARGET=smb://smbserver/share1/backup/db_backup_201509271627.gz atilaloise/mongodb-backup`
3. Restore from S3: `docker run -e MONGO_URI=mongodb://db:27017/database -e AWS_ACCESS_KEY_ID=awskeyid -e AWS_SECRET_ACCESS_KEY=secret -e AWS_DEFAULT_REGION=eu-central-1 -e DB_RESTORE_TARGET=s3://bucket/path/db_backup_201509271627.gz atilaloise/mongodb-backup`
