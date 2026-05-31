# Use a recent Ubuntu base for Linux dev
FROM ubuntu:26.04

# Install base system tools and dev essentials (customize as needed)
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    git \
    python3 \
    python3-pip \
    curl \
    vim \
    tzdata \
    gosu \
    tmux \
    golang-go \
    jq \
	pandoc texlive-latex-recommended texlive-fonts-recommended \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 24.x LTS from NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Enable pnpm via corepack (ships with Node.js; version matches CI)
RUN corepack enable && corepack prepare pnpm@9 --activate

# Install GitHub CLI (gh) only if INSTALL_GH=true (set when both GITHUB_USERNAME and GITHUB_TOKEN are configured)
ARG INSTALL_GH=false
RUN if [ "$INSTALL_GH" = "true" ]; then \
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
        apt-get update && \
        apt-get install -y gh && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Install Tauri Linux system dependencies and OCCT for local Rust/C++ builds
# Mirrors the apt-get block in .github/workflows/ci.yml so local builds match CI
RUN apt-get update && \
    apt-get install -y \
        pkg-config \
        cmake \
        libssl-dev \
        libgtk-3-dev \
        libwebkit2gtk-4.1-dev \
        libayatana-appindicator3-dev \
        librsvg2-dev \
        llvm \
        clang \
        libclang-dev \
        libocct-foundation-dev \
        libocct-modeling-data-dev \
        libocct-modeling-algorithms-dev \
        libocct-data-exchange-dev \
        libocct-ocaf-dev \
    && rm -rf /var/lib/apt/lists/*

# Environment variables required by the Rust build (bindgen + OCCT linking)
ENV OCCT_INCLUDE_DIR=/usr/include/opencascade \
    OCCT_LIB_DIR=/usr/lib/x86_64-linux-gnu
# Detect LLVM lib dir dynamically (Ubuntu 24.04 ships LLVM 18+)
RUN echo "LIBCLANG_PATH=$(llvm-config --libdir)" >> /etc/environment && \
    echo "export LIBCLANG_PATH=$(llvm-config --libdir)" >> /etc/bash.bashrc

# Create a non-root user for security with fixed UID/GID
# Using UID 2000 to avoid conflicts (1000 is taken by ubuntu user in base image)
RUN groupadd -g 2000 devuser 2>/dev/null || true && \
    useradd -m -s /bin/bash -u 2000 -g 2000 devuser
ARG WORK_FOLDER=work
WORKDIR /home/devuser/$WORK_FOLDER
USER devuser

# Install Claude Code only if CLAUDE_CODE_OAUTH_TOKEN is provided
ARG INSTALL_CLAUDE=false
RUN if [ "$INSTALL_CLAUDE" = "true" ]; then curl -fsSL https://claude.ai/install.sh | bash; fi

# Switch to root for global npm installs
USER root

# Install pi coding agent only if INSTALL_PI=true (set when PI_PERSIST_FOLDER is configured)
ARG INSTALL_PI=false
RUN if [ "$INSTALL_PI" = "true" ]; then npm install -g @earendil-works/pi-coding-agent@latest; fi
USER devuser

# Install Rust via rustup (stable toolchain)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
RUN echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc

RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

RUN echo 'export GOPATH="$HOME/go"' >> ~/.bashrc
RUN echo 'export PATH="$PATH:$GOPATH/bin"' >> ~/.bashrc

# Ray and friends..
RUN go install github.com/vector76/beads_server/cmd/bs@main
RUN go install github.com/vector76/raymond/cmd/ray@main
RUN go install github.com/vector76/cc_usage_dashboard/cmd/clusage-cli@main

# Colored bash prompt (overrides default PS1)
RUN echo "PS1='\[\033[01;32m\]\u\[\033[00m\]@\[\033[01;33m\]\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '" >> ~/.bashrc

# Set timezone from TZ environment variable if provided
RUN echo 'if [ -n "$TZ" ]; then export TZ; fi' >> ~/.bashrc

# Configure git from environment variables if set
RUN echo 'if [ -n "$GIT_USER_NAME" ]; then git config --global user.name "$GIT_USER_NAME"; fi' >> ~/.bashrc
RUN echo 'if [ -n "$GIT_USER_EMAIL" ]; then git config --global user.email "$GIT_USER_EMAIL"; fi' >> ~/.bashrc

# Set up git credentials. ~/.git-credentials is rebuilt on each shell to avoid append-growth,
# combining GitHub (GITHUB_TOKEN + GITHUB_USERNAME) and Azure DevOps (AZURE_DEVOPS_PAT) entries.
# Azure DevOps ignores the URL username; "azuredevops" is just a non-empty placeholder.
RUN echo 'rm -f ~/.git-credentials' >> ~/.bashrc && \
    echo 'if [ -n "$GITHUB_TOKEN" ] || [ -n "$AZURE_DEVOPS_PAT" ]; then' >> ~/.bashrc && \
    echo '  git config --global credential.helper store' >> ~/.bashrc && \
    echo 'fi' >> ~/.bashrc && \
    echo 'if [ -n "$GITHUB_TOKEN" ]; then' >> ~/.bashrc && \
    echo '  if [ -z "$GITHUB_USERNAME" ]; then' >> ~/.bashrc && \
    echo '    echo "GITHUB_USERNAME is required for GitHub authentication" >&2' >> ~/.bashrc && \
    echo '  else' >> ~/.bashrc && \
    echo '    echo "https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com" >> ~/.git-credentials' >> ~/.bashrc && \
    echo '  fi' >> ~/.bashrc && \
    echo 'fi' >> ~/.bashrc && \
    echo 'if [ -n "$AZURE_DEVOPS_PAT" ]; then' >> ~/.bashrc && \
    echo '  echo "https://azuredevops:${AZURE_DEVOPS_PAT}@dev.azure.com" >> ~/.git-credentials' >> ~/.bashrc && \
    echo '  if [ -n "$AZURE_DEVOPS_ORG" ]; then' >> ~/.bashrc && \
    echo '    echo "https://azuredevops:${AZURE_DEVOPS_PAT}@${AZURE_DEVOPS_ORG}.visualstudio.com" >> ~/.git-credentials' >> ~/.bashrc && \
    echo '  fi' >> ~/.bashrc && \
    echo 'fi' >> ~/.bashrc && \
    echo '[ -f ~/.git-credentials ] && chmod 600 ~/.git-credentials' >> ~/.bashrc

# Switch to root temporarily to create entrypoint that can fix ownership
USER root

# Create entrypoint script that fixes Windows mount ownership
# The work directory itself is often owned by root due to Windows->Linux mount translation
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'WORK_DIR="/home/devuser/${WORK_FOLDER:-work}"' >> /entrypoint.sh && \
    echo '# Fix work directory ownership if owned by root (Windows mount artifact)' >> /entrypoint.sh && \
    echo '# Only fix root ownership - preserve warnings for legitimate cross-platform issues' >> /entrypoint.sh && \
    echo 'if [ -d "$WORK_DIR" ] && [ "$(stat -c %u "$WORK_DIR" 2>/dev/null)" = "0" ]; then' >> /entrypoint.sh && \
    echo '  chown 2000:2000 "$WORK_DIR" 2>/dev/null || true' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo '# Start beads server in background if BS_TOKEN is set' >> /entrypoint.sh && \
    echo 'if [ -n "$BS_TOKEN" ]; then' >> /entrypoint.sh && \
    echo '  ( cd "$WORK_DIR" && gosu devuser nohup /home/devuser/go/bin/bs serve > /tmp/bs.log 2>&1 ) &' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo '# Switch to devuser for command execution' >> /entrypoint.sh && \
    echo 'exec gosu devuser "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Optional: Install additional Python packages or tools here via pip
# RUN pip3 install --user requests numpy  # Example

# Use entrypoint to handle ownership fix, then run the keep-alive command
ENTRYPOINT ["/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
