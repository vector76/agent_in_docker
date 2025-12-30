@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: %0 ^<version^> ^(e.g., v3^)
    exit /b 1
)

set VERSION=%~1

:: Load container config from .env.container
if not exist .env.container (
    echo .env.container file not found. Copy .env.container.example to .env.container and customize.
    exit /b 1
)
for /f "tokens=1,2 delims==" %%a in (.env.container) do (
    if "%%a"=="IMAGE_NAME" set IMAGE_NAME=%%b
    if "%%a"=="CONTAINER_NAME" set CONTAINER_NAME=%%b
)
if not defined IMAGE_NAME (
    echo IMAGE_NAME not set in .env.container.
    exit /b 1
)
if not defined CONTAINER_NAME (
    echo CONTAINER_NAME not set in .env.container.
    exit /b 1
)

:: Build -e flags from host environment variables
:: List of environment variable names to propagate to container (hard-coded for security)
:: Add more variable names to this list as needed, separated by spaces
set ENV_VARS=
if defined AMP_API_KEY (
    set ENV_VARS=!ENV_VARS! -e "AMP_API_KEY=!AMP_API_KEY!"
)
if defined ANTHROPIC_API_KEY (
    set ENV_VARS=!ENV_VARS! -e "ANTHROPIC_API_KEY=!ANTHROPIC_API_KEY!"
)
if defined CURSOR_API_KEY (
    set ENV_VARS=!ENV_VARS! -e "CURSOR_API_KEY=!CURSOR_API_KEY!"
)
if defined GITHUB_TOKEN (
    set ENV_VARS=!ENV_VARS! -e "GITHUB_TOKEN=!GITHUB_TOKEN!"
)
if defined CLAUDE_CODE_OAUTH_TOKEN (
    set ENV_VARS=!ENV_VARS! -e "CLAUDE_CODE_OAUTH_TOKEN=!CLAUDE_CODE_OAUTH_TOKEN!"
)
:: Add more variables here following the same pattern:
:: if defined ANOTHER_VAR (
::     set ENV_VARS=!ENV_VARS! -e "ANOTHER_VAR=!ANOTHER_VAR!"
:: )

:: Get absolute host directory and replace \ with / for Docker volume format
set HOST_DIR=%CD%
set VOLUME_MOUNT=!HOST_DIR:\=/!:/home/devuser/work

:: ENV_VARS is built above from host environment variables
set WORKDIR=/home/devuser/work
set KEEP_ALIVE=tail -f /dev/null

:: Stop and remove existing container (show errors for debugging)
echo Stopping and removing container %CONTAINER_NAME% if exists...
docker stop %CONTAINER_NAME%
docker rm %CONTAINER_NAME%

:: Build new image
echo Building new image %IMAGE_NAME%:%VERSION%...
docker build -t %IMAGE_NAME%:%VERSION% .
if errorlevel 1 (
    echo Build failed.
    pause
    exit /b 1
)

:: Tag as latest
docker tag %IMAGE_NAME%:%VERSION% %IMAGE_NAME%:latest

:: Create (but don't start) new container
echo Creating new container %CONTAINER_NAME% from %IMAGE_NAME%:latest...
docker create --name %CONTAINER_NAME% %ENV_VARS% -v %VOLUME_MOUNT% --workdir %WORKDIR% %IMAGE_NAME%:latest %KEEP_ALIVE%
if errorlevel 1 (
    echo Create failed.
    pause
    exit /b 1
)

:: Optional cleanup of old images (uncomment if desired)
:: docker rmi %IMAGE_NAME%:old-version  :: Replace with specific old tag
:: docker system prune -f

echo Rebuild complete. Use cbash.bat to open a shell.
pause

endlocal