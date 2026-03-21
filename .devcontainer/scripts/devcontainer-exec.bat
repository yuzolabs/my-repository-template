@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "WORKSPACE_PATH=%CD%"
set "COMMAND_TEXT=bash"

:parse_args
if "%~1"=="" goto after_args
if /I "%~1"=="-WorkspacePath" (
    if "%~2"=="" (
        echo [ERROR] -WorkspacePath requires a value.
        exit /b 1
    )
    set "WORKSPACE_PATH=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="-Command" (
    if "%~2"=="" (
        echo [ERROR] -Command requires a value.
        exit /b 1
    )
    set "COMMAND_TEXT=%~2"
    shift
    shift
    goto parse_args
)

echo [ERROR] Unknown argument: %~1
exit /b 1

:after_args
for %%I in ("%WORKSPACE_PATH%") do set "WORKSPACE_PATH=%%~fI"
echo [INFO] Workspace: %WORKSPACE_PATH%

where wsl >nul 2>&1
if errorlevel 1 (
    echo [ERROR] WSL2 not found. DevContainer requires WSL2.
    echo [INFO] Please install WSL2 and Docker Desktop.
    echo [INFO] Alternatively, use VS Code 'Reopen in Container' feature.
    exit /b 1
)

wsl --status >nul 2>&1
if errorlevel 1 (
    echo [ERROR] WSL2 is not properly configured.
    echo [INFO] Please run 'wsl --install' to set up WSL2.
    exit /b 1
)

for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$p=(Resolve-Path '%WORKSPACE_PATH%').Path; $n=$p -replace '\\','/'; if($n -match '^([A-Za-z]):/(.*)$'){ '/mnt/' + $matches[1].ToLower() + '/' + $matches[2] } else { $n }"`) do set "WSL_WORKSPACE_PATH=%%I"
if not defined WSL_WORKSPACE_PATH (
    echo [ERROR] Failed to convert workspace path for WSL.
    exit /b 1
)

call :is_interactive "%COMMAND_TEXT%"
set "IS_INTERACTIVE=%ERRORLEVEL%"

set "INITIAL_COMMAND=%COMMAND_TEXT%"
if "%IS_INTERACTIVE%"=="0" set "INITIAL_COMMAND=true"

call :run_wsl_capture "%INITIAL_COMMAND%"
set "EXEC_EXIT_CODE=!RUN_EXIT_CODE!"

if not "!EXEC_EXIT_CODE!"=="0" (
    findstr /I /C:"Dev container not found" /C:"Container not found" /C:"Shell server terminated" /C:"is not running" "!RUN_OUTPUT_FILE!" >nul 2>&1
    if not errorlevel 1 (
        echo [WARNING] Dev container is unavailable. Starting container...
        call :start_container
        if errorlevel 1 exit /b %ERRORLEVEL%
        echo [INFO] Container started. Retrying exec command...
        call :run_wsl_capture "%INITIAL_COMMAND%"
        set "EXEC_EXIT_CODE=!RUN_EXIT_CODE!"
    )
)

if "%IS_INTERACTIVE%"=="0" goto interactive_wsl

type "!RUN_OUTPUT_FILE!"
if not "!EXEC_EXIT_CODE!"=="0" (
    echo [ERROR] Command execution failed ^(exit code: !EXEC_EXIT_CODE!^)
    del "!RUN_OUTPUT_FILE!" >nul 2>&1
    exit /b !EXEC_EXIT_CODE!
)
del "!RUN_OUTPUT_FILE!" >nul 2>&1
exit /b 0

:interactive_wsl
if exist "!RUN_OUTPUT_FILE!" del "!RUN_OUTPUT_FILE!" >nul 2>&1
echo [INFO] Entering interactive shell. Type 'exit' to return to Command Prompt.
echo [INFO] Running interactive shell via WSL2...
echo Execute: wsl devcontainer exec --workspace-folder "%WSL_WORKSPACE_PATH%" bash
wsl devcontainer exec --workspace-folder "%WSL_WORKSPACE_PATH%" bash
exit /b %ERRORLEVEL%

:run_wsl_capture
set "RUN_OUTPUT_FILE=%TEMP%\devcontainer-exec-%RANDOM%%RANDOM%.log"
echo [INFO] Running via WSL2...
echo Execute: wsl devcontainer exec --workspace-folder "%WSL_WORKSPACE_PATH%" bash -lc "%~1"
wsl devcontainer exec --workspace-folder "%WSL_WORKSPACE_PATH%" bash -lc "%~1" >"%RUN_OUTPUT_FILE%" 2>&1
set "RUN_EXIT_CODE=%ERRORLEVEL%"
exit /b 0

:start_container
echo [INFO] Starting DevContainer...

wsl bash -c "command -v devcontainer" >nul 2>&1
if errorlevel 1 (
    echo [INFO] Installing DevContainer CLI in WSL2...
    wsl bash -c "npm install -g @devcontainers/cli"
    if errorlevel 1 (
        echo [ERROR] Failed to install DevContainer CLI
        exit /b 1
    )
)

wsl docker version --format '{{.Server.Version}}' >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running. Please start Docker Desktop.
    exit /b 1
)

for %%I in ("%WORKSPACE_PATH%") do set "WORKSPACE_NAME=%%~nxI"
echo [INFO] Workspace name: %WORKSPACE_NAME%

set "INIT_SCRIPT=%WSL_WORKSPACE_PATH%/.devcontainer/host-initialize.sh"
echo [INFO] Initializing Git worktree settings...
wsl bash -c "if [ -f '%INIT_SCRIPT%' ]; then bash '%INIT_SCRIPT%' '%WSL_WORKSPACE_PATH%' '%WORKSPACE_NAME%' '/workspace'; else echo 'host-initialize.sh not found, skipping initialization'; fi"

echo [INFO] Running devcontainer up...
echo Execute: wsl devcontainer up --workspace-folder "%WSL_WORKSPACE_PATH%"
wsl devcontainer up --workspace-folder "%WSL_WORKSPACE_PATH%"
if errorlevel 1 (
    echo [ERROR] Failed to start DevContainer
    exit /b 1
)
echo [INFO] Container started successfully
exit /b 0

:is_interactive
if /I "%~1"=="bash" exit /b 0
if /I "%~1"=="bash -i" exit /b 0
if /I "%~1"=="bash -l" exit /b 0
if /I "%~1"=="sh" exit /b 0
if /I "%~1"=="sh -i" exit /b 0
if /I "%~1"=="sh -l" exit /b 0
if /I "%~1"=="zsh" exit /b 0
if /I "%~1"=="zsh -i" exit /b 0
if /I "%~1"=="zsh -l" exit /b 0
exit /b 1
