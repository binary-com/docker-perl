ARG HTTP_PROXY
FROM deriv/perl
COPY pod-inherit.patch .
RUN patch -p0 $(perldoc -lm Pod::Inherit) < pod-inherit.patch
ONBUILD COPY cpanfile aptfile dist.ini /app/
ONBUILD RUN prepare-apt-cpan.sh \
 && dzil authordeps | cpanm -n
ONBUILD COPY . /app/
