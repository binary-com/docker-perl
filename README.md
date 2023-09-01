#docker-perl

Up-to-date Perl image with support for cpanfile and Debian dependencies

For a cross-platform build, supporting arm+x64 architectures, we recommend using buildx:

```
docker buildx build --build-arg http_proxy="$http_proxy" --pull --platform linux/arm/v7,linux/arm64/v8,linux/amd64 --tag deriv/perl:latest .
```
