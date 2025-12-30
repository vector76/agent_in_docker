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
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd -m -s /bin/bash devuser
USER devuser
WORKDIR /home/devuser/work

# Install Amp CLI (AI coding agent)
# This runs the install script non-interactively; first run may prompt for login if no key is set
RUN curl -fsSL https://ampcode.com/install.sh | bash

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install Cursor agent
RUN curl https://cursor.com/install -fsS | bash

# Add Cursor to PATH in bashrc
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Optional: Install additional Python packages or tools here via pip
# RUN pip3 install --user requests numpy  # Example

# Default to bash shell for interactive use
CMD ["bash"]
