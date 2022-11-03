FROM deriv/perl
ARG http_proxy

WORKDIR /app/
# Note that this happens after the `cpanfile` installation step due to ONBUILD in deriv/perl
COPY pod-inherit.patch .
RUN patch -p0 $(perldoc -lm Pod::Inherit) < pod-inherit.patch

ONBUILD RUN prepare-apt-cpan.sh \
 && dzil authordeps | cpanm -n
# Conditional copy - we want whichever files exist, and we'd typically expect to see at least one
ONBUILD COPY aptfil[e] cpanfil[e] dist.in[i] /app/
ONBUILD COPY . /app/
