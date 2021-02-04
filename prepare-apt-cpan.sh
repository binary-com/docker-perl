#!/bin/bash
# Prepare dependencies by installing anything found in `aptfile`
# then applying CPAN modules from `cpanfile`.

set -e

if [ -r /app/aptfile ]; then
    apt-get -y -q update
    apt-get -y -q --no-install-recommends install $(cat /app/aptfile)
fi

cpanm --notest --installdeps .

rm -r ~/.cpanm

if [ -d /app/vendors ]; then
    for dir in /app/vendors/*; do
        if [ ~ `ls -A $dir` ]; then
            echo -e "It seems that your git submodules are not initialized correctly\nif you are not using submodules please delete 'vendors' subdirctory" 1>&2
            exit 1
        fi
        cd $dir
        dzil authordeps --missing | cpanm
        cpanm --notest --installdeps .
        rm -r ~/.cpanm
        dzil install
        dzil clean
    done
fi

apt-get purge -y -q $(perl -le'@seen{split " ", "" . do { local ($/, @ARGV) = (undef, "/app/aptfile"); <> }} = () if -r "aptfile"; print for grep { !exists $seen{$_} } qw(make gcc git openssh-client libc6-dev libssl-dev zlib1g-dev patch)')
rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cpanm /tmp/*

