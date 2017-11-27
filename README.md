Minimal Usage
================
```
$ docker run -p 5432:5432  apsl/postgres:10.1
```

Docker postgres
========================

[![Docker Pulls](https://img.shields.io/docker/pulls/apsl/postgres.svg)](https://hub.docker.com/r/apsl/postgres/)
[![Docker Stars](https://img.shields.io/docker/stars/apsl/postgres.svg)](https://hub.docker.com/r/apsl/postgres/)
[![Build Status](https://travis-ci.org/APSL/docker-postgres.svg?branch=master)](https://travis-ci.org/APSL/docker-postgres)

* Docker image for postgresql
* Based on official postgres image and extended.  
* Wal-e backup and restore builtin.  
* Separated command with cron service to push the backups.

Ports
=====

* 5432: postgres

Env vars and default value:
=========
