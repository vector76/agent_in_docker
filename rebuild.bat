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
    if "%%a"=="WORK_FOLDER" set WORK_FOLDER=%%b
    if "%%a"=="INITIAL_REPO_CHECKOUT" set INITIAL_REPO_CHECKOUT=%%b
)
if not defined IMAGE_NAME (
    echo IMAGE_NAME not set in .env.container.
    exit /b 1
)
if not defined CONTAINER_NAME (
    echo CONTAINER_NAME not set in .env.container.
    exit /b 1
)
if not defined WORK_FOLDER (
    echo WORK_FOLDER not set in .env.container.
    exit /b 1
)

:: Load secrets from secrets.bat if it exists
if exist secrets.bat (
    echo Loading secrets from secrets.bat...
    call secrets.bat
) else (
    echo Note: secrets.bat not found. Set environment variables manually or create secrets.bat from secrets.bat.example
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
if defined GIT_USER_NAME (
    set ENV_VARS=!ENV_VARS! -e "GIT_USER_NAME=!GIT_USER_NAME!"
)
if defined GIT_USER_EMAIL (
    set ENV_VARS=!ENV_VARS! -e "GIT_USER_EMAIL=!GIT_USER_EMAIL!"
)
if defined GITHUB_USERNAME (
    set ENV_VARS=!ENV_VARS! -e "GITHUB_USERNAME=!GITHUB_USERNAME!"
)
if defined INITIAL_REPO_CHECKOUT (
    set ENV_VARS=!ENV_VARS! -e "INITIAL_REPO_CHECKOUT=!INITIAL_REPO_CHECKOUT!"
)

:: Auto-detect Windows timezone and convert to IANA format (unless TZ is explicitly set)
if not defined TZ (
    :: Use PowerShell to get Windows timezone and convert to IANA using TimeZoneInfo
    for /f "delims=" %%t in ('powershell -NoProfile -Command "$tz = [TimeZoneInfo]::Local; $tzId = $tz.Id; $mapping = @{'Eastern Standard Time'='America/New_York'; 'Central Standard Time'='America/Chicago'; 'Mountain Standard Time'='America/Denver'; 'Pacific Standard Time'='America/Los_Angeles'; 'Alaska Standard Time'='America/Anchorage'; 'Hawaiian Standard Time'='Pacific/Honolulu'; 'Atlantic Standard Time'='America/Halifax'; 'Central European Standard Time'='Europe/Berlin'; 'GMT Standard Time'='Europe/London'; 'W. Europe Standard Time'='Europe/Amsterdam'; 'Tokyo Standard Time'='Asia/Tokyo'; 'China Standard Time'='Asia/Shanghai'; 'India Standard Time'='Asia/Kolkata'; 'AUS Eastern Standard Time'='Australia/Sydney'; 'New Zealand Standard Time'='Pacific/Auckland'}; if ($mapping.ContainsKey($tzId)) { $mapping[$tzId] } else { $tzId }"') do set TZ=%%t
    if not defined TZ (
        echo Warning: Could not detect timezone. Set TZ environment variable manually if needed.
    )
)
if defined TZ (
    set ENV_VARS=!ENV_VARS! -e "TZ=!TZ!"
)
:: Add more variables here following the same pattern:
:: if defined ANOTHER_VAR (
::     set ENV_VARS=!ENV_VARS! -e "ANOTHER_VAR=!ANOTHER_VAR!"
:: )

:: Create work folder if it doesn't exist
if not exist "!WORK_FOLDER!" (
    echo Creating work folder: !WORK_FOLDER!
    mkdir "!WORK_FOLDER!"
)

:: Get absolute host directory and replace \ with / for Docker volume format
set HOST_DIR=%CD%
set WORK_PATH=!HOST_DIR!\!WORK_FOLDER!
set VOLUME_MOUNT=!WORK_PATH:\=/!:/home/devuser/work

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

endlocal