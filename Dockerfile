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

# Create entrypoint script for one-time repository checkout
RUN echo '#!/bin/bash' > /home/devuser/entrypoint.sh && \
    echo 'set -e' >> /home/devuser/entrypoint.sh && \
    echo 'if [ -n "$INITIAL_REPO_CHECKOUT" ] && [ -z "$(ls -A /home/devuser/work 2>/dev/null)" ]; then' >> /home/devuser/entrypoint.sh && \
    echo '  echo "Cloning repository: $INITIAL_REPO_CHECKOUT"' >> /home/devuser/entrypoint.sh && \
    echo '  cd /home/devuser/work && git clone "$INITIAL_REPO_CHECKOUT" .' >> /home/devuser/entrypoint.sh && \
    echo 'fi' >> /home/devuser/entrypoint.sh && \
    echo 'exec "$@"' >> /home/devuser/entrypoint.sh && \
    chmod +x /home/devuser/entrypoint.sh

# Optional: Install additional Python packages or tools here via pip
# RUN pip3 install --user requests numpy  # Example

# Use entrypoint to handle repository checkout, then run the keep-alive command
ENTRYPOINT ["/home/devuser/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
