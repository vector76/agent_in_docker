@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: %0 ^<version^> ^(e.g., v3^)
    exit /b 1
)

set VERSION=%~1

:: Load .env file
if not exist .env (
    echo .env file not found. Create it with IMAGE_NAME, CONTAINER_NAME, AMP_API_KEY.
    exit /b 1
)
for /f "tokens=1,2 delims==" %%a in (.env) do (
    if "%%a"=="IMAGE_NAME" set IMAGE_NAME=%%b
    if "%%a"=="CONTAINER_NAME" set CONTAINER_NAME=%%b
    if "%%a"=="AMP_API_KEY" set AMP_API_KEY=%%b
)
if not defined IMAGE_NAME (
    echo IMAGE_NAME not set in .env.
    exit /b 1
)
if not defined CONTAINER_NAME (
    echo CONTAINER_NAME not set in .env.
    exit /b 1
)
if not defined AMP_API_KEY (
    echo AMP_API_KEY not set in .env.
    exit /b 1
)

:: Get absolute host directory and replace \ with / for Docker volume format
set HOST_DIR=%CD%
set VOLUME_MOUNT=!HOST_DIR:\=/!:/home/devuser/work

set ENV_VARS=-e AMP_API_KEY=%AMP_API_KEY%
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