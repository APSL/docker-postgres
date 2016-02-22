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
RUN pip install wal-e==$WALE_VERSION requests==2.8.1 six==1.10.0

RUN apt-get purge -y build-essential libevent-dev python-dev 
      
RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/postgis.sh
COPY ./initdb-wale.sh /docker-entrypoint-initdb.d/wale.sh