# OpenClaw Node Workstation Container

GitHub-safe build context for an OpenClaw node container with:

- OpenClaw node process
- Chromium with remote debugging
- Xvfb + x11vnc + noVNC for manual browser login
- development/build tools
- all runtime state under `/opt/openclaw-node`
- secrets separated into `/opt/openclaw-node/secrets/openclaw-node.env`

## Secret handling

The uploaded `.env` was intentionally not included. Put real values on the FCOS/bootc host in:

```bash
/opt/openclaw-node/secrets/openclaw-node.env
```

Create it from:

```bash
sudo mkdir -p /opt/openclaw-node/secrets
sudo cp etc/openclaw-node.env.example /opt/openclaw-node/secrets/openclaw-node.env
sudo chmod 600 /opt/openclaw-node/secrets/openclaw-node.env
sudo vi /opt/openclaw-node/secrets/openclaw-node.env
```

Required values:

```bash
OPENCLAW_GATEWAY_URL=ws://your-gateway:18789
OPENCLAW_NODE_TOKEN=your-node-join-token
VNC_PASSWORD=your-vnc-password
```

The initial uploaded `.env` used `NODE_TOKEN`; this build accepts that for compatibility, but the preferred variable is `OPENCLAW_NODE_TOKEN`.

## Build locally

```bash
./build.sh
```

or:

```bash
podman build -t localhost/openclaw-node-workstation:latest -f Containerfile .
```

## Run locally

```bash
./run.sh
```

Access noVNC:

```text
http://127.0.0.1:6080/vnc.html
```

Chrome DevTools Protocol:

```text
http://127.0.0.1:9222/json/version
```

## Install on FCOS / bootc host

```bash
sudo mkdir -p /opt/openclaw-node/secrets
sudo cp etc/openclaw-node.env.example /opt/openclaw-node/secrets/openclaw-node.env
sudo chmod 600 /opt/openclaw-node/secrets/openclaw-node.env
sudo vi /opt/openclaw-node/secrets/openclaw-node.env

sudo cp systemd/openclaw-node.service /etc/systemd/system/openclaw-node.service
sudo systemctl daemon-reload
sudo systemctl enable --now openclaw-node.service
```

## Entry modes

```bash
podman run ... IMAGE node           # browser + OpenClaw node, default
podman run ... IMAGE browser-only   # only Chromium/noVNC
podman run ... IMAGE openclaw-only  # only OpenClaw node
podman run ... IMAGE shell          # shell
podman run ... IMAGE sleep          # sleep forever
```

## Ports

All examples bind to localhost for safety:

- `18789` OpenClaw, if used by your CLI/build
- `9222` Chromium DevTools Protocol
- `5900` VNC
- `6080` noVNC

Do not expose `9222`, `5900`, or `6080` directly to the internet.
