# This is the layer that can run things
FROM debian:stable
LABEL maintainer="Deriv Services Ltd. <DERIV@cpan.org>"

# Some standard server-like config used everywhere
ENV TZ=UTC
ENV DEBIAN_FRONTEND=noninteractive
ENV PERL_VERSION=5.34.0
ENV PERL_SHA256=82c2e5e5c71b0e10487a80d79140469ab1f8056349ca8545140a224dbbed7ded
ENV CPANM_VERSION=1.7044
ENV CPANM_SHA256=9b60767fe40752ef7a9d3f13f19060a63389a5c23acc3e9827e19b75500f81f3

# Use an apt-cacher-ng or similar proxy when available during builds
ARG DEBIAN_PROXY
ARG HTTP_PROXY

WORKDIR /usr/src/perl

RUN [ -n "$DEBIAN_PROXY" ] \
 && (echo "Acquire::http::Proxy \"http://$DEBIAN_PROXY\";" > /etc/apt/apt.conf.d/30proxy) \
 || echo "No local Debian proxy configured" \
 && apt-get update \
 && apt-get dist-upgrade -y -q --no-install-recommends \
 && apt-get install -y -q --no-install-recommends \
    git openssh-client curl socat ca-certificates gcc make libc6-dev libssl-dev zlib1g-dev xz-utils dumb-init patch \
 && curl -SL https://www.cpan.org/src/5.0/"perl-${PERL_VERSION}".tar.xz -o "perl-${PERL_VERSION}".tar.xz \
 && sha256sum perl-${PERL_VERSION}.tar.xz \
 && echo "${PERL_SHA256} *perl-${PERL_VERSION}.tar.xz" | sha256sum -c - \
 && tar --strip-components=1 -xaf "perl-${PERL_VERSION}".tar.xz -C /usr/src/perl \
 && rm "perl-${PERL_VERSION}".tar.xz \
 && ./Configure -Duse64bitall -Duseshrplib -Dprefix=/opt/"perl-${PERL_VERSION}" -Dman1dir=none -Dman3dir=none -des \
 && make -j$(nproc) \
 && make install \
 && cd /usr/src \
 && curl -LO https://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-${CPANM_VERSION}.tar.gz \
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
