FROM postgres:9.5
MAINTAINER Edu Herraiz <eherraiz@apsl.net>
# Based on : https://github.com/appropriate/docker-postgis

ENV POSTGIS_MAJOR 2.2
ENV POSTGIS_VERSION 2.2.1+dfsg-2.pgdg80+1
ENV WALE_VERSION 0.8.1

RUN apt-get update \
      && apt-get install -y --no-install-recommends \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR=$POSTGIS_VERSION \
           postgis=$POSTGIS_VERSION \
           lzop \
           python-pip \
           pv \
           python-dev \
           libevent-dev \
           build-essential \
           daemontools \
      && rm -rf /var/lib/apt/lists/*

RUN pip install pip --upgrade
RUN pip install wal-e==$WALE_VERSION requests==2.8.1 envtpl==0.4.1
# exit 0 is necessary to bypass a problem in docker with overlay: https://github.com/pypa/pip/issues/2953
RUN pip install six==1.10.0; true

RUN apt-get purge -y build-essential libevent-dev python-dev 
      
RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/postgis.sh

COPY postgresql.conf.tpl /etc/postgres/postgresql.conf.tpl
COPY backup-list.sh /usr/local/bin/backup-list.sh
COPY backup-wale.sh /usr/local/bin/backup-wale.sh
COPY clean-wale.sh /usr/local/bin/clean-wale.sh
COPY crontab /etc/postgres/crontab
COPY go-cron /sbin/

# Necessary overwrite to configure postgres via env vars
# Original https://github.com/docker-library/postgres/blob/443c7947d548b1c607e06f7a75ca475de7ff3284/9.5/docker-entrypoint.sh
COPY docker-entrypoint.sh /
