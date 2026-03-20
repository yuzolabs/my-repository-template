# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/devcontainers/javascript-node:24-trixie

# Install system tools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    unzip fd-find ripgrep \
    && ln -s $(which fdfind) /usr/local/bin/fd

# Install GitHub CLI (kept for now)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y --no-install-recommends gh

# Install uv
ENV UV_INSTALL_DIR=/usr/local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install bun
ENV BUN_INSTALL=/home/node/.bun
RUN mkdir -p /home/node/.bun /home/node/.local/share/opencode \
    && curl -fsSL https://bun.com/install | bash \
    && mkdir -p /home/node/.bun/install/cache /home/node/.bun/bin /home/node/.bun/install/global \
    && chown -R node:node /home/node /home/node/.bun
ENV PATH=${BUN_INSTALL}/bin:${PATH}

# Install opencode as node user
USER node
RUN --mount=type=cache,id=bun-cache-v2,target=/home/node/.bun/install/cache,uid=1000,gid=1000 \
    --mount=type=cache,id=bun-global-v2,target=/home/node/.bun/install/global,uid=1000,gid=1000 \
    bun add -g opencode-ai

# Install agent-browser and TypeScript LSP (combined into one RUN)
RUN --mount=type=cache,target=/home/node/.npm,uid=1000,gid=1000 \
    npm install -g agent-browser \
    && agent-browser install --with-deps \
    && npm install -g typescript-language-server typescript
