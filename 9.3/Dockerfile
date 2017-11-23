# https://hub.docker.com/_/postgres/
FROM postgres:9.3.20
MAINTAINER Edu Herraiz <eherraiz@apsl.net>
# Based on : https://github.com/appropriate/docker-postgis

ENV POSTGIS_MAJOR 2.3
ENV WALE_VERSION 1.0.1

# useful for security updates
ENV LAST_UPDATE 2017-11-23

# Install dependencies
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
RUN pip install six==1.10.0
RUN apt-get purge -y build-essential libevent-dev python3-dev

# Prepare scripts
RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/postgis.sh
COPY postgresql.conf.tpl /etc/postgres/postgresql.conf.tpl
COPY scripts/* /usr/local/bin/
COPY crontab /etc/postgres/crontab
COPY go-cron /sbin/
# Necessary overwrite entrypoint.sh to configure postgres via env vars
COPY docker-entrypoint.sh /usr/local/bin/

# Adjust execution permissions
RUN chmod +x /docker-entrypoint-initdb.d/postgis.sh \
  /usr/local/bin/* \
  /sbin/go-cron \
  /usr/local/bin/docker-entrypoint.sh
