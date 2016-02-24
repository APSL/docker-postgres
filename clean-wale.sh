#!/bin/bash 

echo "[CRON] Initiating cleaning old wal-e backups with retain: $WALE_RETAIN"
/usr/local/bin/wal-e delete --confirm retain $WALE_RETAIN
echo "[CRON] Finished cleaning old wal-e backups with retain: $WALE_RETAIN"