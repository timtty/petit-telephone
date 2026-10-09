# Yate as a minimal SIP PBX (registrar + call routing for a few softphones)
FROM debian:bookworm-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git ca-certificates \
        autoconf automake libtool pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Pinned yate master (official GitHub mirror), 2026-09
ARG YATE_COMMIT=7d86cb173a7b19a051cecb63f905919f4b93df01
RUN git clone https://github.com/yatevoip/yate.git /usr/src/yate \
    && cd /usr/src/yate && git checkout "$YATE_COMMIT"

WORKDIR /usr/src/yate
RUN ./autogen.sh \
    # the webrtc-based codecs pull in miniwebrtc, which doesn't compile on
    # arm64; G.711 (built in) is all the softphones need
    && ./configure --prefix=/usr --sysconfdir=/etc \
        --disable-ilbc-webrtc --disable-isac-float --disable-g722-webrtc \
    # yate's Makefiles are not parallel-safe; build serially
    && make \
    && make install-noapi DESTDIR=/stage

# Fail the build early if the PBX modules are missing
RUN test -f /stage/usr/lib/yate/server/regfile.yate \
    && test -f /stage/usr/lib/yate/extmodule.yate


FROM debian:bookworm-slim

COPY --from=build /stage/ /

EXPOSE 5060/udp

# -vv: debug level "info"; logs go to stderr (docker logs)
CMD ["yate", "-vv"]
