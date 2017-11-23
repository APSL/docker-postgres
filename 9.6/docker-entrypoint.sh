#!/bin/bash
set -e

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

function configure_wale() {
    # Configure env dir for wal-e
    mkdir -p /etc/wal-e.d/env
    echo $AWS_ACCESS_KEY_ID > /etc/wal-e.d/env/AWS_ACCESS_KEY_ID
    echo $AWS_SECRET_ACCESS_KEY > /etc/wal-e.d/env/AWS_SECRET_ACCESS_KEY
    echo $WALE_S3_PREFIX > /etc/wal-e.d/env/WALE_S3_PREFIX
    echo $AWS_REGION > /etc/wal-e.d/env/AWS_REGION
    echo $PGDATA > /etc/wal-e.d/env/PGDATA
    # Default WALE retention of base backups
    if [ -z "$WALE_RETAIN" ]; then WALE_RETAIN=10; fi
    echo $WALE_RETAIN > /etc/wal-e.d/env/WALE_RETAIN

    #Recover enviroment
    mkdir -p /etc/wal-e.d/env_recover
    echo $RECOVER_AWS_ACCESS_KEY_ID > /etc/wal-e.d/env_recover/AWS_ACCESS_KEY_ID
    echo $RECOVER_AWS_SECRET_ACCESS_KEY > /etc/wal-e.d/env_recover/AWS_SECRET_ACCESS_KEY
    echo $RECOVER_AWS_REGION > /etc/wal-e.d/env_recover/AWS_REGION
    echo $RECOVER_WALE_S3_PREFIX > /etc/wal-e.d/env_recover/WALE_S3_PREFIX
    if [ -z "$RECOVER_WALE_BACKUP_FETCH" ]; then
      export RECOVER_WALE_BACKUP_FETCH='LATEST'
    fi
    if [ -z "$RECOVER_WALE_RECOVERY_TARGET_TIME" ]; then
      export RECOVER_WALE_RECOVERY_TARGET_TIME='latest'
    fi

    chown root:postgres -R /etc/wal-e.d
    chmod 755 -R /etc/wal-e.d
}

function configure_pg_hba() {
    # check password first so we can output the warning before postgres
    # messes it up
    echo
    echo "PostgreSQL configuring pg_hba to $PGDATA/pg_hba.conf"
    echo

    if [ "$POSTGRES_PASSWORD" ]; then
        pass="PASSWORD '$POSTGRES_PASSWORD'"
        authMethod=md5
    else
        # The - option suppresses leading tabs but *not* spaces. :)
        cat >&2 <<-'EOWARN'
                                ****************************************************
                                WARNING: No password has been set for the database.
                                         This will allow anyone with access to the
                                         Postgres port to access your database. In
                                         Docker's default configuration, this is
                                         effectively any other container on the same
                                         system.

                                         Use "-e POSTGRES_PASSWORD=password" to set
                                         it in "docker run".
                                ****************************************************
EOWARN

        pass=
        authMethod=trust
    fi

    cat <<EOPGHBA > "$PGDATA/pg_hba.conf"
# "local" is for Unix domain socket connections only
local   all             all                                     trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            trust
# IPv6 local connections:
host    all             all             ::1/128                 trust
EOPGHBA

    { echo; echo "host all all 0.0.0.0/0 $authMethod"; } >> "$PGDATA/pg_hba.conf"
    chown postgres "$PGDATA/pg_hba.conf"

}

if [ "${1:0:1}" = '-' ]; then
	set -- postgres "$@"
fi

if [ "$1" = 'postgres' ] && [ "$(id -u)" = '0' ]; then
    mkdir -p "$PGDATA"
    chown -R postgres "$PGDATA"
    chmod 700 "$PGDATA"

    mkdir -p /var/run/postgresql
    chown -R postgres /var/run/postgresql
    chmod 775 /var/run/postgresql

    configure_wale

    echo
    echo 'PostgreSQL configure to /etc/postgres/postgresql.conf'
    echo
    envtpl /etc/postgres/postgresql.conf.tpl --allow-missing --keep-template

    # Create the transaction log directory before initdb is run (below) so the directory is owned by the correct user
    if [ "$POSTGRES_INITDB_XLOGDIR" ]; then
    	mkdir -p "$POSTGRES_INITDB_XLOGDIR"
    	chown -R postgres "$POSTGRES_INITDB_XLOGDIR"
    	chmod 700 "$POSTGRES_INITDB_XLOGDIR"
    fi

    exec gosu postgres "$BASH_SOURCE" "$@" -c config_file=/etc/postgres/postgresql.conf
fi

if [ "$1" = 'postgres' ]; then
  mkdir -p "$PGDATA"
  chown -R "$(id -u)" "$PGDATA" 2>/dev/null || :
  chmod 700 "$PGDATA" 2>/dev/null || :

  # look specifically for PG_VERSION, as it is expected in the DB dir
  if [ ! -s "$PGDATA/PG_VERSION" ]; then
    # First we check if we can recover from WALE
    if [ "$RECOVER_WALE" = 'True' ]; then
        echo
        echo "Restoring PostgreSQL from Wal-e backup: $RECOVER_WALE_BACKUP_FETCH"
        echo "The point in time to recover is: $RECOVER_WALE_RECOVERY_TARGET_TIME"
        echo
        /usr/bin/envdir /etc/wal-e.d/env_recover /usr/local/bin/wal-e backup-fetch $PGDATA $RECOVER_WALE_BACKUP_FETCH

        echo "restore_command = 'envdir /etc/wal-e.d/env_recover wal-e wal-fetch \"%f\" \"%p\"'" > $PGDATA/recovery.conf
        if [ "$RECOVER_WALE_RECOVERY_TARGET_TIME" != 'latest' ]; then
            echo "recovery_target_time = '$RECOVER_WALE_RECOVERY_TARGET_TIME'" >> $PGDATA/recovery.conf
        fi

        chown postgres:postgres "$PGDATA/recovery.conf"
        chmod 700 -R $PGDATA

        echo
        echo "Finished restore Postgresql from Wal-e backup"
        echo

    else
        echo 'Initiating PostgreSQL Database.'
        file_env 'POSTGRES_INITDB_ARGS'
    		if [ "$POSTGRES_INITDB_XLOGDIR" ]; then
    			export POSTGRES_INITDB_ARGS="$POSTGRES_INITDB_ARGS --xlogdir $POSTGRES_INITDB_XLOGDIR"
    		fi
    		eval "initdb --username=postgres $POSTGRES_INITDB_ARGS"
    fi

    configure_pg_hba

    # internal start of server in order to allow set-up using psql-client
		# does not listen on external TCP/IP and waits until start finishes
		PGUSER="${PGUSER:-postgres}" \
		pg_ctl -D "$PGDATA" \
			-o "-c listen_addresses='localhost' -c config_file=/etc/postgres/postgresql.conf" \
			-w start

    if [ "$RECOVER_WALE" = 'True' ]; then
        echo "Nothing to do, just wait..."
    else
      file_env 'POSTGRES_USER' 'postgres'
  		file_env 'POSTGRES_DB' "$POSTGRES_USER"

  		psql=( psql -v ON_ERROR_STOP=1 )

  		if [ "$POSTGRES_DB" != 'postgres' ]; then
  			"${psql[@]}" --username postgres <<-EOSQL
  				CREATE DATABASE "$POSTGRES_DB" ;
EOSQL
  			echo
  		fi

  		if [ "$POSTGRES_USER" = 'postgres' ]; then
  			op='ALTER'
  		else
  			op='CREATE'
  		fi
  		"${psql[@]}" --username postgres <<-EOSQL
  			$op USER "$POSTGRES_USER" WITH SUPERUSER $pass ;
EOSQL
  		echo

  		psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

      		echo
      		for f in /docker-entrypoint-initdb.d/*; do
      			case "$f" in
      				*.sh)     echo "$0: running $f"; . "$f" ;;
      				*.sql)    echo "$0: running $f"; "${psql[@]}" -f "$f"; echo ;;
      				*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${psql[@]}"; echo ;;
      				*)        echo "$0: ignoring $f" ;;
      			esac
      			echo
      		done
    fi

    PGUSER="${PGUSER:-postgres}" \
    pg_ctl -D "$PGDATA" \
    -o "-c config_file=/etc/postgres/postgresql.conf" \
    -m fast -w stop
  fi

  echo
  echo 'PostgreSQL init process complete; ready for start up.'
  echo


  # echo
  # echo 'Initiating PostgreSQL'
  # echo
  # exec gosu postgres "$@" -c config_file=/etc/postgres/postgresql.conf

elif [ "$1" = 'cron' ]; then
    configure_wale
    exec go-cron -file="/etc/postgres/crontab"
fi

exec "$@"
