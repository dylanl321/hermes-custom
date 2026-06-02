# Custom Hermes Agent image with pre-installed dependencies
# Base: official hermes-agent Docker image (Debian Trixie, Python 3.13, Node 20)
#
# This extends the upstream image with tools that would otherwise need
# manual installation after every container rebuild:
#   - Claude Code (Anthropic CLI agent)
#   - 1Password CLI (op)
#   - Node.js 22 LTS (separate prefix for user-space tools)
#   - paho-mqtt (Python MQTT client)
#   - blogwatcher-cli (RSS/blog monitor)
#   - AWS CLI v2 (for Bedrock)

ARG HERMES_VERSION=main
FROM nousresearch/hermes-agent:${HERMES_VERSION}

USER root

# ============================================================
# System packages we need beyond what upstream provides
# ============================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        jq \
        tmux \
        unzip \
        wget \
        ca-certificates \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Node.js 22 LTS — separate prefix at /opt/data/node
# Used for Claude Code and other user-space Node tools.
# The system Node 20 (from upstream) remains for Hermes itself.
# ============================================================
ENV NODE_PREFIX=/opt/data/node
RUN mkdir -p ${NODE_PREFIX} && \
    curl -fsSL https://nodejs.org/dist/v22.22.2/node-v22.22.2-linux-x64.tar.xz | \
    tar -xJ --strip-components=1 -C ${NODE_PREFIX} && \
    # Install Claude Code globally into this prefix
    ${NODE_PREFIX}/bin/npm install -g @anthropic-ai/claude-code@latest && \
    # Verify node works (claude --version requires a TTY/config, skip it)
    ${NODE_PREFIX}/bin/node --version

# ============================================================
# 1Password CLI (op) — for secrets management
# ============================================================
RUN curl -fsSL https://cache.agilebits.com/dist/1P/op2/pkg/v2.30.3/op_linux_amd64_v2.30.3.zip -o /tmp/op.zip && \
    unzip -o /tmp/op.zip -d /tmp/op && \
    mv /tmp/op/op /usr/local/bin/op && \
    chmod +x /usr/local/bin/op && \
    rm -rf /tmp/op /tmp/op.zip && \
    op --version

# ============================================================
# AWS CLI v2 — needed for Bedrock provider
# ============================================================
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscli.zip && \
    unzip -q /tmp/awscli.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscli.zip && \
    aws --version

# ============================================================
# Python packages (installed into the Hermes venv)
# ============================================================
RUN . /opt/hermes/.venv/bin/activate && \
    uv pip install --no-cache-dir \
        paho-mqtt \
        boto3 \
        "discord.py>=2.3" \
        "python-telegram-bot>=21.0" \
        "playwright>=1.40,<2" \
        openpyxl \
    && python3 -c "import paho.mqtt; import boto3; import discord; import telegram; import playwright; print('Python deps OK')"

# ============================================================
# blogwatcher-cli (Go binary — bundled in this repo under bin/)
# Copy the pre-built binary. To update: replace bin/blogwatcher-cli
# and rebuild.
# ============================================================
COPY bin/blogwatcher-cli /usr/local/bin/blogwatcher-cli
RUN chmod +x /usr/local/bin/blogwatcher-cli

# ============================================================
# Ensure PATH includes our custom prefixes at runtime
# ============================================================
ENV PATH="/opt/data/node/bin:/opt/data/home/.local/bin:/usr/local/bin:${PATH}"

# ============================================================
# Fix permissions so the hermes user can access everything
# ============================================================
RUN chown -R hermes:hermes /opt/data/node 2>/dev/null || true

# Keep the upstream entrypoint and volume
VOLUME ["/opt/data"]

# ============================================================
# Build trigger: pull latest upstream (2026-06-02 update to v0.15.2)
# ============================================================
