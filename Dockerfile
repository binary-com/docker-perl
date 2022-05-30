# This is the layer that can run things
FROM debian:stable
LABEL maintainer="Deriv Services Ltd <DERIV@cpan.org>"

# Some standard server-like config used everywhere
ENV TZ=UTC
ENV DEBIAN_FRONTEND=noninteractive
ENV PERL_VERSION=5.36.0
ENV PERL_SHA256=0f386dccbee8e26286404b2cca144e1005be65477979beb9b1ba272d4819bcf0
ENV CPANM_VERSION=1.7045
ENV CPANM_SHA256=ac4e4adc23fec0ab54f088aca511f5a57d95e6c97a12a1cb98eed1fe0fe0e99c

# Use an apt-cacher-ng or similar proxy when available during builds
ARG http_proxy

WORKDIR /usr/src/perl

RUN [ -n "$http_proxy" ] \
 && (echo "Acquire::http::Proxy \"$http_proxy\";" > /etc/apt/apt.conf.d/30proxy) \
 || echo "No local Debian proxy configured" \
 && apt-get update \
 && apt-get dist-upgrade -y -q --no-install-recommends \
 && apt-get install -y -q --no-install-recommends \
    git openssh-client curl socat ca-certificates gcc make libc6-dev libssl-dev zlib1g-dev xz-utils dumb-init patch \
# Plain HTTP here so that we can cache - we're verifying SHA256 anyway
 && curl -SLO http://www.cpan.org/src/5.0/"perl-${PERL_VERSION}".tar.xz \
 && sha256sum perl-${PERL_VERSION}.tar.xz \
 && echo "${PERL_SHA256} *perl-${PERL_VERSION}.tar.xz" | sha256sum -c - \
 && tar --strip-components=1 -xaf "perl-${PERL_VERSION}".tar.xz -C /usr/src/perl \
 && rm "perl-${PERL_VERSION}".tar.xz \
 && ./Configure -Duse64bitall -Duseshrplib -Dprefix=/opt/"perl-${PERL_VERSION}" -Dman1dir=none -Dman3dir=none -DSILENT_NO_TAINT_SUPPORT -des \
 && make -j$(nproc) \
 && make install \
 && cd /usr/src \
# Plain HTTP here so that we can cache - we're verifying SHA256 anyway
 && curl -SLO http://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-${CPANM_VERSION}.tar.gz \
 && echo "${CPANM_SHA256} *App-cpanminus-${CPANM_VERSION}.tar.gz" | sha256sum -c - \
 && tar -xzf "App-cpanminus-${CPANM_VERSION}".tar.gz \
 && rm "App-cpanminus-${CPANM_VERSION}".tar.gz \
 && cd "App-cpanminus-${CPANM_VERSION}" && /opt/"perl-${PERL_VERSION}"/bin/perl bin/cpanm . \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /etc/apt/apt.conf.d/30proxy \
 && rm -fr ./cpanm /root/.cpanm /usr/src/perl /usr/src/"App-cpanminus-${CPANM_VERSION}"* /tmp/* \
 && mkdir -p /etc/ssh/ \
 && ssh-keyscan github.com >> /etc/ssh/ssh_known_hosts \
 && mkdir -p /app

WORKDIR /app/
COPY prepare-apt-cpan.sh /usr/local/bin/

ENV PATH="/opt/perl-${PERL_VERSION}/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin"

ONBUILD ARG HTTP_PROXY
ONBUILD WORKDIR /app/
ONBUILD COPY cpanfile aptfile /app/

# Install everything in the aptfile first, as system deps, then
# go through the CPAN deps. Once those are all done, remove anything
# that we would have pulled in as a build dep (compilers, for example)
# unless they happened to be in the aptfile.
ONBUILD RUN prepare-apt-cpan.sh
ONBUILD COPY . /app/

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]

CMD [ "perl", "app.pl" ]
