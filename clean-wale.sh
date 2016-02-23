#!/bin/bash 

DATE=`date -u`
echo "$DATE [CRON] Cleaning old wal-e backups with retain: $WALE_RETAIN"
/usr/local/bin/wal-e delete --confirm retain $WALE_RETAIN
