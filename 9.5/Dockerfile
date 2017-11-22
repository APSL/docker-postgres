# https://hub.docker.com/_/postgres/
FROM postgres:9.5
MAINTAINER Edu Herraiz <eherraiz@apsl.net>
# Based on : https://github.com/appropriate/docker-postgis

ENV POSTGIS_MAJOR 2.2
ENV POSTGIS_VERSION 2.2.2+dfsg-7~137.gite11228b.pgdg80+1
ENV WALE_VERSION 1.0.1

#ENV POSTGIS_MAJOR 2.3
#ENV POSTGIS_VERSION 2.3.0+dfsg-2.pgdg80+1
#ENV WALE_VERSION 1.0.1
# useful for security updates
ENV LAST_UPDATE 2016-11-08

RUN apt-get update \
    && apt-get dist-upgrade -yd \
    && apt-get install -y --no-install-recommends \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts \
           postgis \
           lzop \
           python3 \
           python3-dev \
           libevent-dev \
           build-essential \
           daemontools \
           wget \
           pv \
      && rm -rf /var/lib/apt/lists/*

RUN wget https://bootstrap.pypa.io/get-pip.py --no-check-certificate; python3 get-pip.py;
RUN pip install wal-e==$WALE_VERSION requests==2.10.0 envtpl==0.4.1 boto==2.43.0
# exit 0 is necessary to bypass a problem in docker with overlay: https://github.com/pypa/pip/issues/2953
RUN pip install six==1.10.0; true

RUN apt-get purge -y build-essential libevent-dev python3-dev

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
COPY docker-entrypoint.sh /usr/local/bin/
