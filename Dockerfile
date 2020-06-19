# This is the layer that can run things
FROM perl:5.30-slim-buster

# Some standard server-like config used everywhere
ENV TZ=UTC
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get -y -q --no-install-recommends install \
    git openssh-client curl socat ca-certificates gcc make libc6-dev libssl-dev zlib1g-dev bzip2 dumb-init \
 && apt-get -y -q --no-install-recommends dist-upgrade \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/* \
# Locale support is probably quite useful in some cases, but
# let's let individual builds decide that via aptfile config
# && echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen \
# && locale-gen \
 && mkdir -p /etc/ssh/ \
 && ssh-keygen -F github.com || ssh-keyscan github.com >> /etc/ssh/ssh_known_hosts \
 && mkdir -p /app

WORKDIR /app/

ONBUILD ADD cpanfile aptfile /app/

# Install everything in the aptfile first, as system deps, then
# go through the CPAN deps. Once those are all done, remove anything
# that we would have pulled in as a build dep (compilers, for example)
# unless they happened to be in the aptfile.
ONBUILD RUN if [ -s /app/aptfile ]; then \
    apt-get -y -q update \
    && apt-get -y -q --no-install-recommends install $(cat /app/aptfile); \
  fi \
  && cpanm -n --installdeps --with-recommends . \
  && apt-get purge -y -q $(perl -le'@seen{split " ", "" . do { local ($/, @ARGV) = (undef, "/app/aptfile"); <> }} = () if -r "aptfile"; print for grep { !exists $seen{$_} } qw(make gcc git openssh-client libc6-dev libssl-dev zlib1g-dev)') \
  && apt-get -y  --purge autoremove \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cpanm

ONBUILD ADD . /app/

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]

CMD [ "perl", "app.pl" ]
