ARG HTTP_PROXY
FROM deriv/perl
ADD pod-inherit.patch .
RUN patch -p0 $(perldoc -lm Pod::Inherit) < pod-inherit.patch
ONBUILD ADD cpanfile aptfile dist.ini /app/
ONBUILD RUN prepare-apt-cpan.sh \
 && dzil authordeps | cpanm -n
ONBUILD ADD . /app/
