# syntax=docker/dockerfile:1.7

# OpenClaw node workstation container
# Fedora-based image intended to run on Fedora CoreOS / bootc hosts.
# Runtime files and mutable state live under /opt/openclaw-node.

ARG FEDORA_VERSION=latest
FROM quay.io/fedora/fedora:${FEDORA_VERSION}

ARG OPENCLAW_NPM_PACKAGE=openclaw

ENV OPENCLAW_HOME=/opt/openclaw-node \
    OPENCLAW_CONFIG_DIR=/opt/openclaw-node/state/openclaw \
    OPENCLAW_WORKSPACE=/opt/openclaw-node/workspace \
    OPENCLAW_WEB_PORT=18789 \
    DISPLAY=:1 \
    CHROME_DEBUG_PORT=9222 \
    VNC_PORT=5900 \
    NOVNC_PORT=6080 \
    ENABLE_VNC=1 \
    ENABLE_NOVNC=1 \
    HEADLESS=0 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN dnf -y update && \
    dnf -y install \
      bash coreutils findutils procps-ng shadow-utils util-linux \
      ca-certificates curl wget git jq gettext sudo \
      dumb-init supervisor \
      openssh-clients rsync unzip zip tar gzip xz \
      iproute iputils bind-utils net-tools socat \
      ripgrep fd-find vim-minimal nano less htop file \
      gcc gcc-c++ make cmake ninja-build pkgconf-pkg-config \
      python3 python3-pip python3-devel python3-virtualenv \
      nodejs npm pnpm \
      golang rust cargo \
      podman buildah skopeo \
      xorg-x11-server-Xvfb x11vnc novnc websockify openbox xterm dbus-x11 \
      chromium \
      liberation-fonts google-noto-emoji-fonts google-noto-sans-cjk-fonts fontconfig \
    && dnf clean all

# Install OpenClaw CLI. Override OPENCLAW_NPM_PACKAGE at build time if your package/fork differs.
RUN npm install -g "${OPENCLAW_NPM_PACKAGE}"

RUN useradd -m -u 10001 -s /bin/bash nodeagent && \
    mkdir -p \
      /opt/openclaw-node/bin \
      /opt/openclaw-node/etc \
      /opt/openclaw-node/workspace \
      /opt/openclaw-node/browser-profile \
      /opt/openclaw-node/state/openclaw \
      /opt/openclaw-node/state/vnc \
      /opt/openclaw-node/logs \
      /opt/openclaw-node/tools && \
    chown -R nodeagent:nodeagent /opt/openclaw-node /home/nodeagent

COPY --chmod=755 bin/entrypoint.sh /opt/openclaw-node/bin/entrypoint.sh
COPY --chmod=755 bin/start-browser.sh /opt/openclaw-node/bin/start-browser.sh
COPY --chmod=755 bin/start-openclaw.sh /opt/openclaw-node/bin/start-openclaw.sh
COPY --chmod=755 bin/healthcheck.sh /opt/openclaw-node/bin/healthcheck.sh
COPY etc/supervisord.conf /opt/openclaw-node/etc/supervisord.conf
COPY etc/openclaw-node.json.template /opt/openclaw-node/etc/openclaw-node.json.template
COPY etc/openclaw-node.env.example /opt/openclaw-node/etc/openclaw-node.env.example

USER nodeagent
WORKDIR /opt/openclaw-node/workspace

EXPOSE 18789 9222 5900 6080

VOLUME ["/opt/openclaw-node/workspace", "/opt/openclaw-node/state", "/opt/openclaw-node/browser-profile", "/opt/openclaw-node/logs"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD /opt/openclaw-node/bin/healthcheck.sh

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/opt/openclaw-node/bin/entrypoint.sh"]
CMD ["node"]
