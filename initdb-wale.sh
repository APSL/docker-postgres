#!/bin/sh

set -e

echo "Configuring wale in postgresl.conf"
# All vars all commented: https://gist.github.com/eduherraiz/68715fb692a78595d935
# We can overwrite it adding on the configuration file.
echo "wal_level = archive" >> $PGDATA/postgresql.conf
echo "archive_mode = on" >> $PGDATA/postgresql.conf
echo "archive_command = '/usr/bin/envdir /etc/wal-e.d/env /usr/local/bin/wal-e wal-push %p'" >> $PGDATA/postgresql.conf
echo "archive_timeout = 1800" >> $PGDATA/postgresql.conf

# Configure env dir
mkdir -p /etc/wal-e.d/env
echo $AWS_ACCESS_KEY_ID > /etc/wal-e.d/env/AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY > /etc/wal-e.d/env/AWS_SECRET_ACCESS_KEY
echo $WALE_S3_PREFIX > /etc/wal-e.d/env/WALE_S3_PREFIX

echo "Configure cron to upload base backups"
