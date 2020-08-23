#!/bin/bash
# Prepare dependencies by installing anything found in `aptfile`
# then applying CPAN modules from `cpanfile`.

set -e

if [ -r /app/aptfile ]; then
    apt-get -y -q update
    apt-get -y -q --no-install-recommends install $(cat /app/aptfile)
fi
cpanm --notest --installdeps .
apt-get purge -y -q $(perl -le'@seen{split " ", "" . do { local ($/, @ARGV) = (undef, "/app/aptfile"); <> }} = () if -r "aptfile"; print for grep { !exists $seen{$_} } qw(make gcc git openssh-client libc6-dev libssl-dev zlib1g-dev patch)')
rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cpanm /tmp/*

