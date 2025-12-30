# Use a recent Ubuntu base for Linux dev
FROM ubuntu:24.04

# Install base system tools and dev essentials (customize as needed)
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    python3 \
    python3-pip \
    curl \
    vim \
    tzdata \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security with fixed UID/GID
# Using UID 2000 to avoid conflicts (1000 is taken by ubuntu user in base image)
RUN groupadd -g 2000 devuser 2>/dev/null || true && \
    useradd -m -s /bin/bash -u 2000 -g 2000 devuser
WORKDIR /home/devuser/work
USER devuser

# Install Amp CLI (AI coding agent)
# This runs the install script non-interactively; first run may prompt for login if no key is set
RUN curl -fsSL https://ampcode.com/install.sh | bash

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install Cursor agent
RUN curl https://cursor.com/install -fsS | bash

# Add Cursor to PATH in bashrc
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Set timezone from TZ environment variable if provided
RUN echo 'if [ -n "$TZ" ]; then export TZ; fi' >> ~/.bashrc

# Configure git from environment variables if set
RUN echo 'if [ -n "$GIT_USER_NAME" ]; then git config --global user.name "$GIT_USER_NAME"; fi' >> ~/.bashrc
RUN echo 'if [ -n "$GIT_USER_EMAIL" ]; then git config --global user.email "$GIT_USER_EMAIL"; fi' >> ~/.bashrc

# Set up GitHub token authentication if GITHUB_TOKEN is available
# Uses "git" as username (standard for GitHub PATs) or GITHUB_USERNAME if set
RUN echo 'if [ -n "$GITHUB_TOKEN" ]; then' >> ~/.bashrc && \
    echo '  git config --global credential.helper store' >> ~/.bashrc && \
    echo '  GITHUB_USER="${GITHUB_USERNAME:-git}"' >> ~/.bashrc && \
    echo '  echo "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com" > ~/.git-credentials' >> ~/.bashrc && \
    echo '  chmod 600 ~/.git-credentials' >> ~/.bashrc && \
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
    echo '# Switch to devuser for repository checkout and command execution' >> /entrypoint.sh && \
    echo 'if [ -n "$INITIAL_REPO_CHECKOUT" ]; then' >> /entrypoint.sh && \
    echo '  if [ -n "$REPO_SUBFOLDER" ]; then' >> /entrypoint.sh && \
    echo '    # Checkout to subfolder' >> /entrypoint.sh && \
    echo '    REPO_DIR="/home/devuser/work/$REPO_SUBFOLDER"' >> /entrypoint.sh && \
    echo '    if [ ! -d "$REPO_DIR" ] || [ -z "$(ls -A \"$REPO_DIR\" 2>/dev/null)" ]; then' >> /entrypoint.sh && \
    echo '      su - devuser -c "mkdir -p \"$REPO_DIR\" && cd \"$REPO_DIR\" && git clone \"$INITIAL_REPO_CHECKOUT\" ."' >> /entrypoint.sh && \
    echo '    fi' >> /entrypoint.sh && \
    echo '  else' >> /entrypoint.sh && \
    echo '    # Checkout to work folder (default behavior)' >> /entrypoint.sh && \
    echo '    if [ -z "$(ls -A /home/devuser/work 2>/dev/null)" ]; then' >> /entrypoint.sh && \
    echo '      su - devuser -c "cd /home/devuser/work && git clone \"$INITIAL_REPO_CHECKOUT\" ."' >> /entrypoint.sh && \
    echo '    fi' >> /entrypoint.sh && \
    echo '  fi' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo 'exec gosu devuser "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Optional: Install additional Python packages or tools here via pip
# RUN pip3 install --user requests numpy  # Example

# Use entrypoint to handle ownership fix and repository checkout, then run the keep-alive command
ENTRYPOINT ["/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
