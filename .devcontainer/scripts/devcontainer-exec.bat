@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "WORKSPACE_PATH=%CD%"
set "COMMAND_TEXT=bash"
set "SKIP_WSL=0"

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
if /I "%~1"=="-SkipWSL" (
    set "SKIP_WSL=1"
    shift
    goto parse_args
)

echo [ERROR] Unknown argument: %~1
exit /b 1

:after_args
for %%I in ("%WORKSPACE_PATH%") do set "WORKSPACE_PATH=%%~fI"
echo [INFO] Workspace: %WORKSPACE_PATH%

if "%SKIP_WSL%"=="1" goto native_mode

where wsl >nul 2>&1
if errorlevel 1 goto native_mode

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
    echo [ERROR] Command execution failed (exit code: !EXEC_EXIT_CODE!)
    del "!RUN_OUTPUT_FILE!" >nul 2>&1
    exit /b !EXEC_EXIT_CODE!
)
del "!RUN_OUTPUT_FILE!" >nul 2>&1
exit /b 0

echo [INFO] Running via WSL2...
echo Execute: wsl devcontainer exec --workspace-folder "%WSL_WORKSPACE_PATH%" bash -lc "%COMMAND_TEXT%"
wsl devcontainer exec --workspace-folder "%WSL_WORKSPACE_PATH%" bash -lc "%COMMAND_TEXT%"
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" (
    echo [ERROR] Command execution failed (exit code: %EXIT_CODE%)
    exit /b %EXIT_CODE%
)
exit /b 0

:interactive_wsl
if exist "!RUN_OUTPUT_FILE!" del "!RUN_OUTPUT_FILE!" >nul 2>&1
echo [INFO] Entering interactive shell. Type 'exit' to return to Command Prompt.
echo [INFO] Running interactive shell via WSL2...
echo Execute: wsl devcontainer exec --workspace-folder "%WSL_WORKSPACE_PATH%" bash
wsl devcontainer exec --workspace-folder "%WSL_WORKSPACE_PATH%" bash
exit /b %ERRORLEVEL%

:native_mode
echo [INFO] Running in Windows native mode...
echo Execute: powershell -ExecutionPolicy Bypass -File "%~dp0devcontainer-exec.ps1" -WorkspacePath "%WORKSPACE_PATH%" -Command "%COMMAND_TEXT%" -SkipWSL
powershell -ExecutionPolicy Bypass -File "%~dp0devcontainer-exec.ps1" -WorkspacePath "%WORKSPACE_PATH%" -Command "%COMMAND_TEXT%" -SkipWSL
exit /b %ERRORLEVEL%

:run_wsl_capture
set "RUN_OUTPUT_FILE=%TEMP%\devcontainer-exec-%RANDOM%%RANDOM%.log"
echo [INFO] Running via WSL2...
echo Execute: wsl devcontainer exec --workspace-folder "%WSL_WORKSPACE_PATH%" bash -lc "%~1"
wsl devcontainer exec --workspace-folder "%WSL_WORKSPACE_PATH%" bash -lc "%~1" >"%RUN_OUTPUT_FILE%" 2>&1
set "RUN_EXIT_CODE=%ERRORLEVEL%"
exit /b 0

:start_container
set "UP_SCRIPT=%~dp0devcontainer-up.ps1"
if not exist "%UP_SCRIPT%" (
    echo [ERROR] devcontainer-up.ps1 not found at: %UP_SCRIPT%
    exit /b 1
)

echo [INFO] Running devcontainer-up.ps1 to start container...
powershell -ExecutionPolicy Bypass -File "%UP_SCRIPT%" -WorkspacePath "%WORKSPACE_PATH%"
exit /b %ERRORLEVEL%

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
