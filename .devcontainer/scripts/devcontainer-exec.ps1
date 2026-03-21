#Requires -Version 5.1
<#
.SYNOPSIS
    Execute commands inside DevContainer

.DESCRIPTION
    Execute commands inside a running DevContainer.
    Can run via WSL2 or Windows native.

.PARAMETER WorkspacePath
    Workspace path (default: current directory)

.PARAMETER Command
    Command to execute (default: bash shell)

.PARAMETER SkipWSL
    Run in Windows native mode without WSL2

.EXAMPLE
    .\devcontainer-exec.ps1
    Launch bash shell in DevContainer

.EXAMPLE
    .\devcontainer-exec.ps1 -Command "npm install"
    Run npm install inside DevContainer
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$WorkspacePath = $PWD.Path,

    [Parameter()]
    [string]$Command = "bash -i",

    [Parameter()]
    [switch]$SkipWSL
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Convert-ToWSLPath {
    param([string]$WindowsPath)
    $normalized = $WindowsPath -replace '\\', '/'
    if ($normalized -match '^([A-Za-z]):/(.*)$') {
        $drive = $matches[1].ToLower()
        $path = $matches[2]
        return "/mnt/$drive/$path"
    }
    return $normalized
}

$useWSL = !$SkipWSL
if ($useWSL) {
    if (-not (Test-CommandExists "wsl")) {
        Write-Host "WSL2 not found, running in Windows native mode" -ForegroundColor Yellow
        $useWSL = $false
    }
}

$workspaceFullPath = Resolve-Path $WorkspacePath | Select-Object -ExpandProperty Path
Write-Info "Workspace: $workspaceFullPath"

$wslWorkspacePath = Convert-ToWSLPath $workspaceFullPath

function Get-ExitCode {
    if ($null -ne $global:LASTEXITCODE) {
        return [int]$global:LASTEXITCODE
    }
    if ($?) {
        return 0
    }
    return 1
}

function Invoke-CapturedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$CommandBlock
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $outputLines = & $CommandBlock 2>&1

        $exitCode = if ($null -ne $global:LASTEXITCODE) {
            [int]$global:LASTEXITCODE
        }
        elseif ($?) {
            0
        }
        else {
            1
        }

        return [PSCustomObject]@{
            Output = @($outputLines)
            ExitCode = $exitCode
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Invoke-DevContainerExec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandToRun
    )

    if ($useWSL) {
        Write-Info "Running via WSL2..."

        $escapedWorkspace = $wslWorkspacePath -replace "'", "'\''"
        $wslCommand = "devcontainer exec --workspace-folder '$escapedWorkspace' $CommandToRun"
        Write-Host "Execute: wsl bash -c `"$wslCommand`"" -ForegroundColor DarkGray

        return Invoke-CapturedCommand -CommandBlock { wsl bash -c $wslCommand }
    }
    else {
        Write-Info "Running in Windows native mode..."

        $localExecArgs = @("exec", "--workspace-folder", $workspaceFullPath, $CommandToRun)
        Write-Host "Execute: devcontainer $($localExecArgs -join ' ')" -ForegroundColor DarkGray

        return Invoke-CapturedCommand -CommandBlock { & devcontainer @localExecArgs }
    }
}

function Invoke-DevContainerExecPassthrough {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandToRun
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        if ($useWSL) {
            Write-Info "Running via WSL2..."

            $escapedWorkspace = $wslWorkspacePath -replace "'", "'\''"
            $wslCommand = "devcontainer exec --workspace-folder '$escapedWorkspace' $CommandToRun"
            Write-Host "Execute: wsl bash -c `"$wslCommand`"" -ForegroundColor DarkGray

            wsl bash -c $wslCommand
            return Get-ExitCode
        }

        Write-Info "Running in Windows native mode..."

        $localExecArgs = @("exec", "--workspace-folder", $workspaceFullPath, $CommandToRun)
        Write-Host "Execute: devcontainer $($localExecArgs -join ' ')" -ForegroundColor DarkGray

        & devcontainer @localExecArgs
        return Get-ExitCode
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Write-CommandOutput {
    param([object[]]$Lines)

    if (-not $Lines) {
        return
    }

    $Lines | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            $message = $_.Exception.Message
            if ($message -and $message -ne "System.Management.Automation.RemoteException") {
                Write-Host $message
            }
            return
        }

        $text = $_.ToString()
        if ($text -and $text -ne "System.Management.Automation.RemoteException") {
            Write-Host $text
        }
    }
}

function Test-InteractiveShellCommand {
    param([string]$CommandText)

    $trimmed = $CommandText.Trim()
    return $trimmed -match '^(bash|bash -i|sh|sh -i|zsh|zsh -i)$'
}

$isInteractiveShellCommand = Test-InteractiveShellCommand -CommandText $Command
$initialCommand = if ($isInteractiveShellCommand) { "true" } else { $Command }

$result = Invoke-DevContainerExec -CommandToRun $initialCommand
$hasError = ($result.ExitCode -ne 0)
$outputText = ($result.Output -join "`n")
$isContainerUnavailable = $hasError -and (
    $outputText -match "Error:.*Dev container not found" -or
    $outputText -match "Dev container not found" -or
    $outputText -match "Container not found" -or
    $outputText -match "Shell server terminated" -or
    $outputText -match "is not running"
)

if ($isContainerUnavailable) {
    Write-Warning "Dev container is unavailable. Starting container..."

    $upScriptPath = Join-Path $PSScriptRoot "devcontainer-up.ps1"
    if (-not (Test-Path $upScriptPath)) {
        Write-Error "devcontainer-up.ps1 not found at: $upScriptPath"
        exit 1
    }

    Write-Info "Running devcontainer-up.ps1 to start container..."
    $upArgs = @("-ExecutionPolicy", "Bypass", "-File", $upScriptPath, "-WorkspacePath", $workspaceFullPath)
    if (-not $useWSL) {
        $upArgs += "-SkipWSL"
    }

    $upResult = Invoke-CapturedCommand -CommandBlock { & powershell @upArgs }
    Write-CommandOutput -Lines $upResult.Output
    $upExitCode = $upResult.ExitCode

    if ($upExitCode -ne 0) {
        Write-Error "Failed to start container (exit code: $upExitCode)"
        exit $upExitCode
    }

    Write-Info "Container started. Retrying exec command..."
    $retryCommand = if ($isInteractiveShellCommand) { "true" } else { $Command }
    $retryResult = Invoke-DevContainerExec -CommandToRun $retryCommand
    Write-CommandOutput -Lines $retryResult.Output

    if ($retryResult.ExitCode -ne 0) {
        Write-Error "Command execution failed after retry (exit code: $($retryResult.ExitCode))"
        exit $retryResult.ExitCode
    }

    if ($isInteractiveShellCommand) {
        $interactiveExitCode = Invoke-DevContainerExecPassthrough -CommandToRun $Command
        exit $interactiveExitCode
    }

    exit 0
}

if ($isInteractiveShellCommand -and -not $hasError) {
    Write-Info "Entering interactive shell. Type 'exit' to return to PowerShell."
    $interactiveExitCode = Invoke-DevContainerExecPassthrough -CommandToRun $Command
    exit $interactiveExitCode
}

Write-CommandOutput -Lines $result.Output

if ($hasError) {
    Write-Error "Command execution failed (exit code: $($result.ExitCode))"
    exit $result.ExitCode
}
