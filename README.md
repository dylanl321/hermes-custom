# hermes-custom

Custom Docker image for Hermes Agent on TrueNAS, pre-loaded with all dependencies so upgrades don't lose tooling.

## What's included (on top of upstream `ghcr.io/nousresearch/hermes-agent`)

| Tool | Purpose |
|------|---------|
| **Claude Code** (`@anthropic-ai/claude-code`) | Anthropic CLI coding agent |
| **1Password CLI** (`op` v2.30.3) | Secrets management via service account |
| **Node.js 22 LTS** | Runtime for Claude Code and user-space tools |
| **AWS CLI v2** | Bedrock provider authentication |
| **paho-mqtt** | Python MQTT client (Frigate bridge) |
| **boto3** | AWS SDK (Bedrock, etc.) |
| **blogwatcher-cli** | RSS/blog monitoring |
| **tmux, jq, wget, unzip** | General utilities |

## Usage

### Pull the image

```bash
docker pull ghcr.io/dylanl321/hermes-custom:latest
```

### Update on TrueNAS

In TrueNAS Custom App config, set the image to:
```
ghcr.io/dylanl321/hermes-custom:latest
```

Or pin to a specific version:
```
ghcr.io/dylanl321/hermes-custom:v1.0.0
```

### Build locally

```bash
docker build -t hermes-custom .

# With a specific upstream version:
docker build --build-arg HERMES_VERSION=v0.12.0 -t hermes-custom .
```

## Updating

1. **Upstream Hermes update:** Push a new tag or trigger the workflow manually with the desired `hermes_version`
2. **Add new tools:** Edit `Dockerfile`, push to `main` — image rebuilds automatically
3. **TrueNAS:** Pull the new image and redeploy the app

## CI/CD

GitHub Actions builds and pushes to `ghcr.io` on:
- Every push to `main` (tagged as `latest` + `main`)
- Every git tag matching `v*` (tagged with the version)
- Manual workflow dispatch (with optional upstream version override)
