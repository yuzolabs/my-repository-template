FROM mcr.microsoft.com/devcontainers/javascript-node:24-trixie

# Install basic tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    sudo \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install uv (Python package manager) globally
ENV UV_INSTALL_DIR=/usr/local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install bun (required for this project)
ENV BUN_INSTALL=/home/node/.bun
RUN mkdir -p /home/node/.bun /home/node/.local/share/opencode \
    && curl -fsSL https://bun.com/install | bash \
    && chown -R node:node /home/node /home/node/.bun
ENV PATH=${BUN_INSTALL}/bin:${PATH}

# Install opencode(global)
USER node
RUN bun add -g opencode-ai
