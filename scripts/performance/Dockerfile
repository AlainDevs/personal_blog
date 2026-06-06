FROM alpine:3.20 AS build

RUN apk add --no-cache \
    build-base \
    ca-certificates \
    git \
    linux-headers \
    openssl-dev \
    perl \
    zlib-dev

RUN git clone --depth 1 https://github.com/wg/wrk.git /tmp/wrk \
    && make -C /tmp/wrk

FROM alpine:3.20

RUN apk add --no-cache \
    ca-certificates \
    curl \
    libgcc \
    openssl \
    zlib

COPY --from=build /tmp/wrk/wrk /usr/local/bin/wrk

RUN adduser -D -H -u 10001 wrk

USER wrk
WORKDIR /scripts/performance

ENTRYPOINT ["wrk"]
