#!/bin/bash 

DATE=`date -u`
echo "$DATE [CRON] Initiating postgresql wal-e basebackup"
/usr/local/bin/wal-e backup-push $PGDATA 
DATE=`date -u`
echo "$DATE [CRON] Finished postgresql wal-e basebackup"