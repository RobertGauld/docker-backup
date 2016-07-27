FROM ubuntu:16.04

MAINTAINER Robert Gauld <robert@robertgauld.co.uk>

RUN apt-get update -y
RUN apt-get install -y ruby2.3 rsync openssh-client
RUN apt-get clean -y

COPY backup.rb /root/backup.rb

VOLUME /root/backup.yml
VOLUME /root/.ssh
VOLUME /media/target
