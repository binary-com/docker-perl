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
            cpanm --notest --installdeps .
            rm -r ~/.cpanm
        fi
    done

    echo "export PERL5LIB=$PERL5LIB" >> ~/.bashrc
fi

apt-get purge -y -q $(perl -le'@seen{split " ", "" . do { local ($/, @ARGV) = (undef, "/app/aptfile"); <> }} = () if -r "aptfile"; print for grep { !exists $seen{$_} } qw(make gcc git openssh-client libc6-dev libssl-dev zlib1g-dev patch)')
rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cpanm /tmp/*

