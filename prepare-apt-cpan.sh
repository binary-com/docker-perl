#!/bin/bash
# Prepare dependencies by installing anything found in `aptfile`
# then applying CPAN modules from `cpanfile`.

set -e

DEBIAN_DEPS="make gcc git openssh-client libc6-dev libssl-dev zlib1g-dev patch"

if [ -n "$http_proxy" ]; then
    echo "Acquire::http::Proxy \"$http_proxy\";" > /etc/apt/apt.conf.d/30proxy
else
    echo "No local Debian proxy configured"
fi
apt-get -y -q update
apt-get -y -q --no-install-recommends install $(cat /app/aptfile || :) $DEBIAN_DEPS

cpanm --notest --installdeps --with-recommends .

# a convention to allow developers to include non-standard code modules in 
# the vendors directory as git submodules 

if [ -d /app/vendors ]; then
    # /app/vendors/* will give us canonical paths
    # but if the vendors directory is empty it'll 
    # cause an issue it's nicer to let the build
    # pass if vendors is empty
    PERL5LIB=''
    for dir in `ls /app/vendors`; do
        if [ -z "$(ls -A /app/vendors/$dir)" ]; then
            echo -e "It seems that your git submodules are not initialized correctly\nif you are not using submodules please delete 'vendors' subdirctory" 1>&2
            exit 1
        fi

        PERL5LIB=$PERL5LIB:/app/vendors/$dir/lib
        cd /app/vendors/$dir

        if [ -e cpanfile ]; then
            cpanm --notest --installdeps --with-recommends .
        fi
    done

    echo "export PERL5LIB=$PERL5LIB" >> ~/.bashrc
fi

rm -rf ~/.cpanm

# Remove any development dependencies we installed, with the exception of those explicitly listed in `aptfile`
apt-get purge -y -q $(perl -le'@seen{split " ", "" . do { local ($/, @ARGV) = (undef, "/app/aptfile"); <> }} = () if -r "/app/aptfile"; print for grep { !exists $seen{$_} } qw('"$DEBIAN_DEPS"')')
rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cpanm /tmp/* /etc/apt/apt.conf.d/30proxy
