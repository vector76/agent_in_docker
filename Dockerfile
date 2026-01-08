# Use a recent Ubuntu base for Linux dev
FROM ubuntu:24.04

# Install base system tools and dev essentials (customize as needed)
# as of 2026-01-03, add-apt-repository needed for golang-go to have a newer version that 1.22.2
#   (and software-properties-common is needed for add-apt-repository)
# as of 2026-01-03, this installs version 1.25.5 of golang-go
RUN apt-get update && \
    apt-get install -y software-properties-common ca-certificates gnupg && \
    add-apt-repository ppa:longsleep/golang-backports && \
    apt-get update && \
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
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x LTS from NodeSource (required for Convex)
# As of 2026-01-04, Node.js is v20.19.6 and npm is 10.8.2
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user for security with fixed UID/GID
# Using UID 2000 to avoid conflicts (1000 is taken by ubuntu user in base image)
RUN groupadd -g 2000 devuser 2>/dev/null || true && \
    useradd -m -s /bin/bash -u 2000 -g 2000 devuser
WORKDIR /home/devuser/work
USER devuser

# Install Amp CLI (AI coding agent) only if AMP_API_KEY is provided
# This runs the install script non-interactively; first run may prompt for login if no key is set
ARG INSTALL_AMP=false
RUN if [ "$INSTALL_AMP" = "true" ]; then curl -fsSL https://ampcode.com/install.sh | bash; fi

# Install Claude Code only if CLAUDE_CODE_OAUTH_TOKEN is provided
ARG INSTALL_CLAUDE=false
RUN if [ "$INSTALL_CLAUDE" = "true" ]; then curl -fsSL https://claude.ai/install.sh | bash; fi

# Install Cursor agent only if CURSOR_API_KEY is provided
ARG INSTALL_CURSOR=false
RUN if [ "$INSTALL_CURSOR" = "true" ]; then curl https://cursor.com/install -fsS | bash; fi

# Add path for various tools (including bd and others) in bashrc
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

RUN echo 'export GOPATH="$HOME/go"' >> ~/.bashrc
RUN echo 'export PATH="$PATH:$GOPATH/bin"' >> ~/.bashrc

# install bd (beads):
#RUN go install github.com/steveyegge/beads/cmd/bd@latest

# install gt (gas town):
#RUN go install github.com/steveyegge/gastown/cmd/gt@latest

# install bv (beads viewer):
#RUN go install github.com/Dicklesworthstone/beads_viewer/cmd/bv@latest

# Set timezone from TZ environment variable if provided
RUN echo 'if [ -n "$TZ" ]; then export TZ; fi' >> ~/.bashrc

# Configure git from environment variables if set
RUN echo 'if [ -n "$GIT_USER_NAME" ]; then git config --global user.name "$GIT_USER_NAME"; fi' >> ~/.bashrc
RUN echo 'if [ -n "$GIT_USER_EMAIL" ]; then git config --global user.email "$GIT_USER_EMAIL"; fi' >> ~/.bashrc

# Set up GitHub token authentication if GITHUB_TOKEN is available
# Uses "git" as username (standard for GitHub PATs) or GITHUB_USERNAME if set
RUN echo 'if [ -n "$GITHUB_TOKEN" ]; then' >> ~/.bashrc && \
    echo '  if [ -z "$GITHUB_USERNAME" ]; then' >> ~/.bashrc && \
    echo '    echo "GITHUB_USERNAME is required for GitHub authentication" >&2' >> ~/.bashrc && \
    echo '  else' >> ~/.bashrc && \
    echo '    git config --global credential.helper store' >> ~/.bashrc && \
    echo '    echo "https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com" > ~/.git-credentials' >> ~/.bashrc && \
    echo '    chmod 600 ~/.git-credentials' >> ~/.bashrc && \
    echo '  fi' >> ~/.bashrc && \
    echo 'fi' >> ~/.bashrc

# Switch to root temporarily to create entrypoint that can fix ownership
USER root

# Create entrypoint script that fixes Windows mount ownership issue, then switches to devuser
# The work directory itself is often owned by root due to Windows->Linux mount translation
# This is a false positive - we only fix root ownership, preserving warnings for real issues
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo '# Fix work directory ownership if owned by root (Windows mount artifact)' >> /entrypoint.sh && \
    echo '# Only fix root ownership - preserve warnings for legitimate cross-platform issues' >> /entrypoint.sh && \
    echo 'if [ -d /home/devuser/work ] && [ "$(stat -c %u /home/devuser/work 2>/dev/null)" = "0" ]; then' >> /entrypoint.sh && \
    echo '  chown 2000:2000 /home/devuser/work 2>/dev/null || true' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo '# Disable exit on error for optional repository checkout' >> /entrypoint.sh && \
    echo 'set +e' >> /entrypoint.sh && \
    echo '# Switch to devuser for repository checkout and command execution' >> /entrypoint.sh && \
    echo 'if [ -n "$INITIAL_REPO_CHECKOUT" ]; then' >> /entrypoint.sh && \
    echo '  if [ -n "$REPO_SUBFOLDER" ]; then' >> /entrypoint.sh && \
    echo '    # Checkout to subfolder' >> /entrypoint.sh && \
    echo '    REPO_DIR="/home/devuser/work/$REPO_SUBFOLDER"' >> /entrypoint.sh && \
    echo '    if [ ! -d "$REPO_DIR" ] || [ -z "$(ls -A \"$REPO_DIR\" 2>/dev/null)" ]; then' >> /entrypoint.sh && \
    echo '      su - devuser -c "mkdir -p \"$REPO_DIR\" && cd \"$REPO_DIR\" && git clone \"$INITIAL_REPO_CHECKOUT\" ." || true' >> /entrypoint.sh && \
    echo '    fi' >> /entrypoint.sh && \
    echo '  else' >> /entrypoint.sh && \
    echo '    # Checkout to work folder (default behavior)' >> /entrypoint.sh && \
    echo '    if [ -z "$(ls -A /home/devuser/work 2>/dev/null)" ]; then' >> /entrypoint.sh && \
    echo '      su - devuser -c "cd /home/devuser/work && git clone \"$INITIAL_REPO_CHECKOUT\" ." || true' >> /entrypoint.sh && \
    echo '    fi' >> /entrypoint.sh && \
    echo '  fi' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo '# Re-enable exit on error for main command' >> /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'exec gosu devuser "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Optional: Install additional Python packages or tools here via pip
# RUN pip3 install --user requests numpy  # Example

# Use entrypoint to handle ownership fix and repository checkout, then run the keep-alive command
ENTRYPOINT ["/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
