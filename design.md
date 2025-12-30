# Docker Workflow Quick Reference

This reference outlines your preferred Docker workflow for a Linux dev environment container on Windows. It emphasizes declarative updates via Dockerfile, versioned images, persistent containers for day-to-day use, and periodic rebuilds for dependency freshness or major changes. The workflow separates container starting from shell attachment to prevent accidental shutdowns when closing shells—all interactions use `exec` for shells, and the container runs a keep-alive process (e.g., `tail -f /dev/null`) to stay active independently.

## Key Principles
- **Images**: Immutable and versioned (e.g., `my-dev-env:v1`). Rebuild for changes; tag `:latest` after verification.
- **Containers**: Persistent (no `--rm`); use `stop/start` for sessions. Create new ones only after image updates. Container runs detached with a keep-alive command to avoid shutdown on shell exits.
- **Persistence**: Use volume mounts (e.g., `-v C:/dev/work:/home/devuser/work`) for work files.
- **Updates**: Rebuild image periodically (e.g., to refresh pip packages) or for major additions (e.g., new tools in Dockerfile).
- **Shells**: Always attach via `exec -it`; no "original" shell that can kill the container.
- **Commands**: Run from host terminal (PowerShell/Command Prompt).

## 1. Initial Setup: Build and Run
- **Build Image**:
```
docker build -t my-dev-env:v1 .
docker tag my-dev-env:v1 my-dev-env:latest  # Optional: Set as latest after build
```
- **Run Container** (creates and starts detached; do this once per image version):
```
docker run -d --name my-dev-container -v .:/home/devuser/work -e AMP_API_KEY=sk-your-amp-key-here --workdir /home/devuser/work my-dev-env:latest tail -f /dev/null
```
  - This starts the container in the background without attaching a shell.

## 2. Attaching Shells
- From a host terminal (for first or additional shells):
```
docker exec -it my-dev-container bash
```
- Repeat in new host terminals for more shells (all share state; closing any doesn't stop the container).
- Runtime changes (e.g., temp `pip install`) persist across stop/start but reset on new `run`.

## 3. Day-to-Day Use: Stop/Start
- **Stop Container** (pauses, preserves runtime changes):
```
docker stop my-dev-container
```
- **Start Container** (resumes exactly as before; no attachment):
```
docker start my-dev-container
```
- After start, attach shells via `exec -it my-dev-container bash` (as in Section 2).
- The keep-alive process ensures the container stays running even if all shells are closed.

## 4. Updating the Image (for Dependencies or Changes)
- **When to Update**: Periodically (e.g., to refresh pip packages) or for major additions (e.g., new tools in Dockerfile).
- **Steps**:
  1. Stop and remove current container:
```
docker stop my-dev-container
docker rm my-dev-container
```
  1. Edit `Dockerfile` if adding/changing installs.
  2. Rebuild with new version:
```
docker build -t my-dev-env:v2 .
docker tag my-dev-env:v2 my-dev-env:latest
```
1. Run new container from updated image (as in Section 1).
- **Cleanup Old Resources** (after verification):
```
docker rmi my-dev-env:v1  # Remove old image
docker system prune  # Prune dangling items (confirm prompt)
```

## 5. Troubleshooting Tips
- List containers: `docker ps -a`
- List images: `docker images`
- Logs: `docker logs my-dev-container`
- If runtime changes need saving: Update Dockerfile instead of committing (avoid `docker commit`).
- For Docker Compose alternative: Define in `docker-compose.yml` and use `docker compose up/down/build`.