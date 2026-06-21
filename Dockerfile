FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libegl1 \
        libgl1 \
        libgtk-3-0 \
        libwebkit2gtk-4.1-0 \
        libxkbcommon-x11-0 \
        unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/klibgen-gt

COPY .tool-versions-or-lock/ .tool-versions-or-lock/
COPY scripts/bootstrap-gt.sh scripts/bootstrap-gt.sh

RUN ./scripts/bootstrap-gt.sh

RUN mkdir -p /workspace \
        /tmp/gt-cache \
        /tmp/gt-config \
        /tmp/gt-home \
        /opt/klibgen-gt/vendor/gt/pharo-local \
    && chmod 1777 /workspace \
        /tmp/gt-cache \
        /tmp/gt-config \
        /tmp/gt-home \
        /opt/klibgen-gt/vendor/gt/pharo-local

ENV HOME=/tmp/gt-home
ENV XDG_CONFIG_HOME=/tmp/gt-config
ENV XDG_CACHE_HOME=/tmp/gt-cache

WORKDIR /workspace

ENTRYPOINT ["/opt/klibgen-gt/vendor/gt/bin/GlamorousToolkit-cli", "/opt/klibgen-gt/vendor/gt/GlamorousToolkit.image"]
CMD ["eval", "1 + 2"]
