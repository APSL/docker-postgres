#!/bin/bash 

echo "List all wal-e basebackups"
/usr/bin/envdir /etc/wal-e.d/env /usr/local/bin/wal-e backup-list