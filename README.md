# OpenClaw Node Workstation Container

This repository builds a GitHub-safe container image for an **OpenClaw node/workstation** running on Fedora CoreOS / bootc hosts.

The container starts an OpenClaw node process and a browser workstation in the same runtime environment, so OpenClaw can use local build tools and browser automation while you can still open noVNC and manually log into websites that require human authentication.

Runtime state is kept under `/opt/openclaw-node` and real tokens are intentionally kept out of Git.

## What this image starts

The default `node` entry mode starts:

- OpenClaw node process
- Chromium inside a virtual X display
- Chromium DevTools Protocol on port `9222`
- Xvfb virtual display
- x11vnc VNC server
- noVNC browser-accessible desktop on port `6080`
- software build tools such as git, Node.js, Python, Go, compiler tools, and shell utilities

The browser flow is:

```text
Xvfb virtual display
  -> Chromium
  -> x11vnc
  -> noVNC
  -> your browser at http://127.0.0.1:6080/vnc.html
```

The expected OpenClaw topology is:

```text
OpenClaw Gateway
  ^
  | OPENCLAW_GATEWAY_URL
  | OPENCLAW_NODE_TOKEN
  |
OpenClaw Node Workstation Container
  |- OpenClaw node process
  |- Chromium / CDP
  |- Xvfb
  |- x11vnc
  `- noVNC
```

## Repository safety model

This repository is safe to upload to GitHub as long as real token files are not added.

Safe to commit:

```text
Containerfile
bin/
etc/openclaw-node.env.example
etc/openclaw-node.json.template
systemd/
compose.yaml
.github/workflows/
README.md
build.sh
run.sh
```

Do **not** commit:

```text
.env
openclaw-node.env
openclaw-node-sensitive.env
any file containing real OpenClaw tokens
any browser profile directory
any runtime state directory
```

The `.gitignore` and `.dockerignore` files are set up to help prevent accidental commits of secrets and runtime state.

## Required runtime secret file

Real values should live on the FCOS/bootc host in:

```bash
/opt/openclaw-node/secrets/openclaw-node.env
```

Create it with:

```bash
sudo mkdir -p /opt/openclaw-node/secrets
sudo cp etc/openclaw-node.env.example /opt/openclaw-node/secrets/openclaw-node.env
sudo chmod 600 /opt/openclaw-node/secrets/openclaw-node.env
sudo vi /opt/openclaw-node/secrets/openclaw-node.env
```

Required values:

```bash
OPENCLAW_GATEWAY_URL=ws://your-openclaw-gateway:18789
OPENCLAW_NODE_TOKEN=your-node-join-token
VNC_PASSWORD=your-vnc-password
```

`NODE_TOKEN` is accepted for compatibility with the original files, but `OPENCLAW_NODE_TOKEN` is preferred.

Optional values:

```bash
OPENCLAW_HOME=/opt/openclaw-node
OPENCLAW_WORKSPACE=/opt/openclaw-node/workspace
OPENCLAW_WEB_PORT=18789
CHROME_DEBUG_PORT=9222
VNC_PORT=5900
NOVNC_PORT=6080
DISPLAY=:1
```

## Build locally

```bash
./build.sh
```

or directly:

```bash
podman build -t localhost/openclaw-node-workstation:latest -f Containerfile .
```

If your OpenClaw CLI package name differs from the default, build with:

```bash
podman build \
  --build-arg OPENCLAW_NPM_PACKAGE='the-real-package-name' \
  -t localhost/openclaw-node-workstation:latest \
  -f Containerfile .
```

## Run locally

The included `run.sh` expects the host secret file to exist at `/opt/openclaw-node/secrets/openclaw-node.env`.

```bash
./run.sh
```

Access noVNC:

```text
http://127.0.0.1:6080/vnc.html
```

Check Chromium DevTools Protocol:

```text
http://127.0.0.1:9222/json/version
```

## Install on Fedora CoreOS / bootc host

Copy the secret file into place:

```bash
sudo mkdir -p /opt/openclaw-node/secrets
sudo cp etc/openclaw-node.env.example /opt/openclaw-node/secrets/openclaw-node.env
sudo chmod 600 /opt/openclaw-node/secrets/openclaw-node.env
sudo vi /opt/openclaw-node/secrets/openclaw-node.env
```

Install and start the systemd unit:

```bash
sudo cp systemd/openclaw-node.service /etc/systemd/system/openclaw-node.service
sudo systemctl daemon-reload
sudo systemctl enable --now openclaw-node.service
```

Follow logs:

```bash
sudo journalctl -u openclaw-node.service -f
```

Container logs:

```bash
podman logs -f openclaw-node
```

Runtime logs inside the container:

```bash
podman exec -it openclaw-node sh -lc 'ls -la /opt/openclaw-node/logs && tail -n +1 /opt/openclaw-node/logs/*.log 2>/dev/null'
```

## Entry modes

The default mode is `node`.

```bash
podman run ... IMAGE node           # browser + OpenClaw node, default
podman run ... IMAGE browser-only   # only Chromium/noVNC/CDP
podman run ... IMAGE openclaw-only  # only OpenClaw node
podman run ... IMAGE shell          # interactive shell
podman run ... IMAGE sleep          # sleep forever for debugging
```

## Ports

The examples bind to localhost for safety.

| Port | Purpose |
| ---: | --- |
| `18789` | OpenClaw gateway/node UI/API, depending on your OpenClaw build |
| `6080` | noVNC browser desktop |
| `5900` | raw VNC |
| `9222` | Chromium DevTools Protocol |

Do **not** expose `9222`, `5900`, or `6080` directly to the internet. Put them behind SSH, WireGuard, Tailscale, Cloudflare Access, Traefik forward-auth, or another private access layer.

## GitHub Actions / GHCR

The included workflow builds the container image and pushes it to GitHub Container Registry when enabled in your repository.

Typical final image name:

```text
ghcr.io/<owner>/<repo>:latest
```

For example:

```bash
podman pull ghcr.io/YOUR_GITHUB_USER/YOUR_REPO:latest
```

Then update `systemd/openclaw-node.service` if you want the host to use the GHCR image instead of a locally built image.

## Verifying the image

Check required commands:

```bash
podman run --rm localhost/openclaw-node-workstation:latest shell -lc '
command -v openclaw || true
command -v chromium || true
command -v chromium-browser || true
command -v Xvfb || true
command -v x11vnc || true
command -v websockify || true
command -v hostname || true
locale -a | grep -i en_US || true
'
```

Check the running container:

```bash
podman exec -it openclaw-node sh -lc '
command -v openclaw || true
command -v chromium || true
command -v chromium-browser || true
command -v Xvfb || true
command -v x11vnc || true
command -v websockify || true
command -v hostname || true
curl -fsS http://127.0.0.1:9222/json/version || true
'
```

## Troubleshooting

### `exit status 127`

Exit code `127` means a command was not found.

Check which commands are available:

```bash
podman exec -it openclaw-node sh -lc '
command -v openclaw || true
command -v chromium || true
command -v chromium-browser || true
command -v Xvfb || true
command -v x11vnc || true
command -v websockify || true
command -v hostname || true
'
```

If `openclaw` is missing, the container built successfully but the OpenClaw CLI was not installed or copied into the image. Set the right `OPENCLAW_NPM_PACKAGE` build argument or copy your known-good OpenClaw binary/source into `/opt/openclaw-node`.

### Locale warning

If you see:

```text
setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
```

make sure the image contains the Fedora language pack. This bundle installs `glibc-langpack-en`.

### Browser does not start

Check browser logs:

```bash
podman exec -it openclaw-node sh -lc '
cat /opt/openclaw-node/logs/browser.err.log 2>/dev/null || true
cat /opt/openclaw-node/logs/chromium.log 2>/dev/null || true
cat /opt/openclaw-node/logs/xvfb.log 2>/dev/null || true
'
```

Check Chromium CDP:

```bash
curl http://127.0.0.1:9222/json/version
```

### noVNC opens but browser is blank

Check that Xvfb, x11vnc, websockify, and Chromium are running:

```bash
podman exec -it openclaw-node sh -lc '
ps aux | grep -E "Xvfb|x11vnc|websockify|chromium" | grep -v grep || true
'
```

### OpenClaw node does not connect

Check the host secret file:

```bash
sudo cat /opt/openclaw-node/secrets/openclaw-node.env
```

It should contain at least:

```bash
OPENCLAW_GATEWAY_URL=ws://your-openclaw-gateway:18789
OPENCLAW_NODE_TOKEN=your-node-join-token
VNC_PASSWORD=your-vnc-password
```

Then restart:

```bash
sudo systemctl restart openclaw-node.service
sudo journalctl -u openclaw-node.service -f
```

## Directory model

Inside the container:

```text
/opt/openclaw-node/bin              startup scripts
/opt/openclaw-node/etc              templates and supervisor config
/opt/openclaw-node/workspace        OpenClaw workspace volume
/opt/openclaw-node/browser-profile  persistent Chromium profile volume
/opt/openclaw-node/state            rendered config and runtime state volume
/opt/openclaw-node/logs             logs volume
```

On the host:

```text
/opt/openclaw-node/secrets/openclaw-node.env   host-provided secret file
```

The host secret file is mounted read-only into the container by the provided run/systemd examples.


## OpenClaw exits with `exit status 1`

`exit status 1` means the `openclaw` binary was found and started, but OpenClaw rejected something at runtime. The usual causes are:

- `OPENCLAW_NODE_TOKEN` is still a placeholder or is not a node/pairing token.
- `OPENCLAW_GATEWAY_URL` points to the wrong host, port, or scheme.
- the container cannot reach the gateway from its network namespace.
- the installed OpenClaw CLI uses different arguments than `openclaw node start --gateway ... --token ...`.
- you actually need gateway mode instead of node mode.

Run the built-in diagnostic:

```bash
podman exec -it openclaw-node /opt/openclaw-node/bin/diagnose-openclaw.sh
```

Useful direct log commands:

```bash
podman exec -it openclaw-node sh -lc '
cat /opt/openclaw-node/logs/openclaw-startup.log 2>/dev/null || true
tail -200 /opt/openclaw-node/logs/openclaw.err.log 2>/dev/null || true
tail -200 /opt/openclaw-node/logs/openclaw.log 2>/dev/null || true
'
```

### If the CLI arguments changed

Use the override variable in `/opt/openclaw-node/secrets/openclaw-node.env`:

```bash
OPENCLAW_COMMAND_OVERRIDE='openclaw node start --gateway ws://YOUR-GATEWAY:18789 --token YOURTOKEN --name openclaw-node-01 --workspace /opt/openclaw-node/workspace'
```

### If this container should run the gateway itself

Set:

```bash
OPENCLAW_MODE=gateway
OPENCLAW_GATEWAY_TOKEN=your-gateway-token
```

For a loopback-only local gateway:

```bash
OPENCLAW_MODE=local-gateway
```
