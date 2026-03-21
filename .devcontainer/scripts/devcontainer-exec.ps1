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
    [string]$Command = "bash",

    [Parameter()]
    [switch]$SkipWSL
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-CommandPath {
    param([string]$Command)

    $resolved = Get-Command $Command -ErrorAction SilentlyContinue
    if ($null -eq $resolved) {
        return $null
    }

    return $resolved.Source
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

function Get-WSLPassthroughCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandToRun
    )

    $escapedWorkspace = $wslWorkspacePath -replace "'", "'\''"
    return "devcontainer exec --workspace-folder '$escapedWorkspace' $CommandToRun"
}

function Get-ConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Fallback
    )

    if (-not (Test-Path $Path)) {
        return $Fallback
    }

    $content = Get-Content -Raw -Path $Path
    $match = [regex]::Match($content, $Pattern)
    if ($match.Success -and $match.Groups.Count -gt 1) {
        return $match.Groups[1].Value
    }

    return $Fallback
}

function Get-NormalizedInteractiveShellCommand {
    param([string]$CommandText)

    $trimmed = $CommandText.Trim()
    if ($trimmed -match '^(bash|sh|zsh)(?: -[il])?$') {
        return $matches[1]
    }

    return $trimmed
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
            # WSL2経由でユーザー確認済みの直接実行パターンを使う
            Write-Info "Running interactive shell via WSL2..."
            $wslExecArgs = @("devcontainer", "exec", "--workspace-folder", $wslWorkspacePath, $CommandToRun)
            Write-Host "Execute: wsl $($wslExecArgs -join ' ')" -ForegroundColor DarkGray
            & wsl @wslExecArgs
        }
        else {
            # WSL2がない場合はエラー（Windowsネイティブでは対話的シェルをサポートしない）
            Write-Err "Interactive shell requires WSL2."
            Write-Host "Please enable WSL2 or use VS Code 'Reopen in Container' instead." -ForegroundColor Yellow
            return 1
        }

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
    return $trimmed -match '^(bash|sh|zsh)( -[il])?$'
}

$isInteractiveShellCommand = Test-InteractiveShellCommand -CommandText $Command
$interactiveCommand = if ($isInteractiveShellCommand) { Get-NormalizedInteractiveShellCommand -CommandText $Command } else { $Command }
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
    Write-Warn "Dev container is unavailable. Starting container..."

    $upScriptPath = Join-Path $PSScriptRoot "devcontainer-up.ps1"
    if (-not (Test-Path $upScriptPath)) {
        Write-Err "devcontainer-up.ps1 not found at: $upScriptPath"
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
        Write-Err "Failed to start container (exit code: $upExitCode)"
        exit $upExitCode
    }

    Write-Info "Container started. Retrying exec command..."
    $retryCommand = if ($isInteractiveShellCommand) { "true" } else { $Command }
    $retryResult = Invoke-DevContainerExec -CommandToRun $retryCommand
    Write-CommandOutput -Lines $retryResult.Output

    if ($retryResult.ExitCode -ne 0) {
        Write-Err "Command execution failed after retry (exit code: $($retryResult.ExitCode))"
        exit $retryResult.ExitCode
    }

    if ($isInteractiveShellCommand) {
        $interactiveExitCode = Invoke-DevContainerExecPassthrough -CommandToRun $interactiveCommand
        exit $interactiveExitCode
    }

    exit 0
}

if ($isInteractiveShellCommand -and -not $hasError) {
    Write-Info "Entering interactive shell. Type 'exit' to return to PowerShell."
    $interactiveExitCode = Invoke-DevContainerExecPassthrough -CommandToRun $interactiveCommand
    exit $interactiveExitCode
}

Write-CommandOutput -Lines $result.Output

if ($hasError) {
    Write-Err "Command execution failed (exit code: $($result.ExitCode))"
    exit $result.ExitCode
}
