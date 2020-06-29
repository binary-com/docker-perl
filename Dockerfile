# This is the layer that can run things
FROM debian:buster
LABEL maintainer="Binary.com <binary@cpan.org>"

# Some standard server-like config used everywhere
ENV TZ=UTC
ENV DEBIAN_FRONTEND=noninteractive

# Use an apt-cacher-ng or similar proxy when available during builds
ARG DEBIAN_PROXY

WORKDIR /usr/src/perl

RUN [ -n "$DEBIAN_PROXY" ] \
 && (echo "Acquire::http::Proxy \"http://$DEBIAN_PROXY\";" > /etc/apt/apt.conf.d/30proxy) \
 && (echo "Acquire::http::Proxy::ppa.launchpad.net DIRECT;" >> /etc/apt/apt.conf.d/30proxy) \
 || echo "No local Debian proxy configured" \
 && apt-get update \
 && apt-get dist-upgrade -y -q --no-install-recommends \
 && apt-get install -y -q --no-install-recommends \
    git openssh-client curl socat ca-certificates gcc make libc6-dev libssl-dev zlib1g-dev xz-utils dumb-init \
 && curl -SL https://www.cpan.org/src/5.0/perl-5.32.0.tar.xz -o perl-5.32.0.tar.xz \
 && echo '6f436b447cf56d22464f980fac1916e707a040e96d52172984c5d184c09b859b *perl-5.32.0.tar.xz' | sha256sum -c - \
 && tar --strip-components=1 -xaf perl-5.32.0.tar.xz -C /usr/src/perl \
 && rm perl-5.32.0.tar.xz \
 && ./Configure -Duse64bitall -Duseshrplib -Dprefix=/opt/perl-5.32.0 -Dman1dir=none -Dman3dir=none -des \
 && make -j$(nproc) \
 && make install \
 && cd /usr/src \
 && curl -LO https://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7044.tar.gz \
 && echo '9b60767fe40752ef7a9d3f13f19060a63389a5c23acc3e9827e19b75500f81f3 *App-cpanminus-1.7044.tar.gz' | sha256sum -c - \
 && tar -xzf App-cpanminus-1.7044.tar.gz \
 && rm App-cpanminus-1.7044.tar.gz \
 && cd App-cpanminus-1.7044 && /opt/perl-5.32.0/bin/perl bin/cpanm . \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/* \
 && rm -fr ./cpanm /root/.cpanm /usr/src/perl /usr/src/App-cpanminus-1.7044* /tmp/* \
# Locale support is probably quite useful in some cases, but
# let's let individual builds decide that via aptfile config
# && echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen \
# && locale-gen \
 && mkdir -p /etc/ssh/ \
 && ssh-keyscan github.com >> /etc/ssh/ssh_known_hosts \
 && mkdir -p /app

WORKDIR /app/

ENV PATH="/opt/perl-5.32.0/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin"

ONBUILD ADD cpanfile aptfile /app/

# Install everything in the aptfile first, as system deps, then
# go through the CPAN deps. Once those are all done, remove anything
# that we would have pulled in as a build dep (compilers, for example)
# unless they happened to be in the aptfile.
ONBUILD RUN if [ -s /app/aptfile ]; then \
    apt-get -y -q update \
    && apt-get -y -q --no-install-recommends install $(cat /app/aptfile); \
  fi \
  && cpanm --notest --quiet --installdeps --with-recommends . \
  && apt-get purge -y -q $(perl -le'@seen{split " ", "" . do { local ($/, @ARGV) = (undef, "/app/aptfile"); <> }} = () if -r "aptfile"; print for grep { !exists $seen{$_} } qw(make gcc git openssh-client libc6-dev libssl-dev zlib1g-dev)') \
  && apt-get -y --purge autoremove \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cpanm /tmp/*

ONBUILD ADD . /app/

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]

CMD [ "perl", "app.pl" ]
