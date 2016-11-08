#!/bin/bash
set -e
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

    
    chown root:postgres -R /etc/wal-e.d
    chmod 755 -R /etc/wal-e.d
}

if [ "$1" = 'postgres' ]; then
        mkdir -p "$PGDATA"
        chmod 700 "$PGDATA"
        chown -R postgres "$PGDATA"

        chmod g+s /run/postgresql
        chown -R postgres /run/postgresql

        configure_wale
        
        # look specifically for PG_VERSION, as it is expected in the DB dir
        if [ ! -s "$PGDATA/PG_VERSION" ]; then
                
            # First we check if we can recover from WALE
            if [ "$RECOVER_WALE" = 'True' ]; then
                echo
                echo 'Restoring PostgreSQL from Wal-e latest backup.'
                echo
                /usr/bin/envdir /etc/wal-e.d/env_recover /usr/local/bin/wal-e backup-fetch $PGDATA LATEST
                #echo "restore_command = 'envdir /etc/wal-e.d/env_recover wal-e wal-fetch \"%f\" \"%p\"'" > $PGDATA/recovery.conf
                # check password first so we can output the warning before postgres
                # messes it up
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

                { echo; echo "host all all 0.0.0.0/0 $authMethod"; } >> "$PGDATA/pg_hba.conf"
                                
            else
                gosu postgres initdb

                # check password first so we can output the warning before postgres
                # messes it up
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

                { echo; echo "host all all 0.0.0.0/0 $authMethod"; } >> "$PGDATA/pg_hba.conf"

                # internal start of server in order to allow set-up using psql-client           
                # does not listen on TCP/IP and waits until start finishes
                gosu postgres pg_ctl -D "$PGDATA" \
                        -o "-c listen_addresses=''" \
                        -w start

                : ${POSTGRES_USER:=postgres}
                : ${POSTGRES_DB:=$POSTGRES_USER}
                export POSTGRES_USER POSTGRES_DB

                if [ "$POSTGRES_DB" != 'postgres' ]; then
                        psql --username postgres <<-EOSQL
                                CREATE DATABASE "$POSTGRES_DB" ;
EOSQL
                        echo
                fi

                if [ "$POSTGRES_USER" = 'postgres' ]; then
                        op='ALTER'
                else
                        op='CREATE'
                fi

                psql --username postgres <<-EOSQL
                        $op USER "$POSTGRES_USER" WITH SUPERUSER $pass ;
EOSQL
                echo

                echo
                for f in /docker-entrypoint-initdb.d/*; do
                        case "$f" in
                                *.sh)  echo "$0: running $f"; . "$f" ;;
                                *.sql) 
                                        echo "$0: running $f"; 
                                        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < "$f"
                                        echo 
                                        ;;
                                *)     echo "$0: ignoring $f" ;;
                        esac
                        echo
                done

                gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop

                echo
                echo 'PostgreSQL init process complete; ready for start up.'
                echo
            fi
        fi

        
        echo
        echo 'PostgreSQL configure to /etc/postgres/postgresql.conf'
        echo
        envtpl /etc/postgres/postgresql.conf.tpl --allow-missing --keep-template

        echo
        echo 'Initiating PostgreSQL'
        echo
        exec gosu postgres "$@" -c config_file=/etc/postgres/postgresql.conf

elif [ "$1" = 'cron' ]; then
    configure_wale
    exec go-cron -file="/etc/postgres/crontab"
fi

exec "$@" 
