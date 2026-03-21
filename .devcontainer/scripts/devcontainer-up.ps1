#Requires -Version 5.1
<#
.SYNOPSIS
    Windows TerminalからDevContainerを起動するPowerShellスクリプト

.DESCRIPTION
    WSL2を使用してDevContainer CLIを実行し、開発コンテナ環境を起動します。
    このリポジトリはgit worktree構造を使用しているため、適切なパス解決を行います。

.PARAMETER WorkspacePath
    ワークスペースのパス（省略時はカレントディレクトリ）

.PARAMETER NoCache
    ビルドキャッシュを使用しない

.PARAMETER BuildOnly
    ビルドのみ実行し、コンテナを起動しない

.PARAMETER SkipWSL
    WSL2を使用せず、Windowsネイティブで実行

.EXAMPLE
    .\devcontainer-up.ps1
    カレントディレクトリのDevContainerを起動

.EXAMPLE
    .\devcontainer-up.ps1 -WorkspacePath "C:\Users\name\project"
    指定パスのDevContainerを起動

.EXAMPLE
    .\devcontainer-up.ps1 -NoCache
    キャッシュなしでビルドして起動
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$WorkspacePath = $PWD.Path,

    [Parameter()]
    [switch]$NoCache,

    [Parameter()]
    [switch]$BuildOnly,

    [Parameter()]
    [switch]$SkipWSL
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
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

function Resolve-RepoName {
    param([string]$WorkspacePath)

    $repoName = ""

    try {
        $gitCommonDirRaw = git -C $WorkspacePath rev-parse --path-format=absolute --git-common-dir 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitCommonDirRaw) {
            $gitCommonDir = $gitCommonDirRaw.Trim()
            $repoDir = Split-Path -Parent $gitCommonDir
            $repoName = Split-Path -Leaf $repoDir
        }
    }
    catch {
    }

    if (-not $repoName) {
        try {
            $originUrlRaw = git -C $WorkspacePath remote get-url origin 2>$null
            if ($LASTEXITCODE -eq 0 -and $originUrlRaw) {
                $originUrl = $originUrlRaw.Trim()
                if ($originUrl -match '/([^/]+?)(?:\.git)?$') {
                    $repoName = $matches[1]
                }
            }
        }
        catch {
        }
    }

    if (-not $repoName) {
        try {
            $ghNameRaw = gh repo view --json name -q .name 2>$null
            if ($LASTEXITCODE -eq 0 -and $ghNameRaw) {
                $repoName = $ghNameRaw.Trim()
            }
        }
        catch {
        }
    }

    if (-not $repoName) {
        throw "Could not resolve repository name via git or gh."
    }

    return $repoName
}

Write-Info "Checking prerequisites..."

$useWSL = !$SkipWSL
if ($useWSL) {
    if (-not (Test-CommandExists "wsl")) {
        Write-Warning "WSL2 not found. Running in Windows native mode."
        $useWSL = $false
    }
    else {
        $wslStatus = wsl --status 2>&1
        $wslVersionMatch = $wslStatus | Select-String "Default Version: (\d+)"
        if ($wslVersionMatch -and $wslVersionMatch.Matches.Groups.Count -gt 1) {
            $wslDefaultVersion = $wslVersionMatch.Matches.Groups[1].Value
            if ($wslDefaultVersion -ne "2") {
                Write-Warning "WSL default version is not 2 (current: $wslDefaultVersion)"
            }
        }

        $wslList = wsl -l -v 2>&1
        if ($wslList -notmatch "docker-desktop") {
            Write-Warning "Docker Desktop WSL2 distro not found"
        }
    }
}

if (-not (Test-CommandExists "docker")) {
    throw "Docker not installed. Please install Docker Desktop."
}

$dockerVersion = docker version --format '{{.Server.Version}}' 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Docker Daemon not running. Please start Docker Desktop."
}
Write-Info "Docker version: $dockerVersion"

$devcontainerCmd = if ($useWSL) { "wsl devcontainer" } else { "devcontainer" }
if ($useWSL) {
    $wslCheck = wsl bash -c "command -v devcontainer 2>/dev/null"
    if (-not $wslCheck) {
        Write-Info "Installing DevContainer CLI in WSL2..."
        wsl bash -c "npm install -g @devcontainers/cli"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install DevContainer CLI in WSL2"
        }
    }
}
else {
    if (-not (Test-CommandExists "devcontainer")) {
        Write-Info "Installing DevContainer CLI..."
        npm install -g @devcontainers/cli
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install DevContainer CLI"
        }
    }
}

Write-Success "Prerequisites check completed"

Write-Info "Resolving workspace path..."

$workspaceFullPath = Resolve-Path $WorkspacePath | Select-Object -ExpandProperty Path
Write-Info "Workspace: $workspaceFullPath"

$devcontainerJsonPath = Join-Path (Join-Path $workspaceFullPath ".devcontainer") "devcontainer.json"
if (-not (Test-Path $devcontainerJsonPath)) {
    throw "devcontainer.json not found: $devcontainerJsonPath"
}
Write-Success "Found devcontainer.json: $devcontainerJsonPath"

$wslWorkspacePath = Convert-ToWSLPath $workspaceFullPath
Write-Info "WSL2 path: $wslWorkspacePath"

Write-Info "Starting DevContainer..."

$devcontainerArgs = @()

if ($BuildOnly) {
    $devcontainerArgs += "build"
}
else {
    $devcontainerArgs += "up"
}

$devcontainerArgs += "--workspace-folder"
$devcontainerArgs += $wslWorkspacePath

if ($NoCache) {
    $devcontainerArgs += "--no-cache"
}

if ($useWSL) {
    Write-Info "Running via WSL2..."

    Write-Info "Initializing Git worktree settings..."
    $workspaceName = Split-Path $workspaceFullPath -Leaf
    $repoName = Resolve-RepoName -WorkspacePath $workspaceFullPath
    Write-Info "Resolved repository name: $repoName"
    $mainRepoPath = Join-Path (Split-Path (Split-Path $workspaceFullPath -Parent) -Parent) $repoName
    $mainRepoWSLPath = Convert-ToWSLPath $mainRepoPath

    $initScriptPath = "$wslWorkspacePath/.devcontainer/host-initialize.sh"
    $initCmd = "bash '$initScriptPath' '$wslWorkspacePath' '$workspaceName' '$mainRepoWSLPath' '/workspace'"
    Write-Host "Init: wsl $initCmd" -ForegroundColor DarkGray
    wsl bash -c $initCmd

    if ($LASTEXITCODE -ne 0) {
        throw "Initialization script failed"
    }

    $devcontainerCmdLine = "devcontainer"
    foreach ($arg in $devcontainerArgs) {
        $devcontainerCmdLine += " `"$arg`""
    }
    $wslCommand = "cd `"$wslWorkspacePath`" && $devcontainerCmdLine"
    Write-Host "Command: wsl bash -c `"$wslCommand`"" -ForegroundColor DarkGray

    wsl bash -c $wslCommand
}
else {
    Write-Info "Running in Windows native mode..."

    $devcontainerArgs[1] = "`"$workspaceFullPath`""
    Write-Host "Command: devcontainer $($devcontainerArgs -join ' ')" -ForegroundColor DarkGray

    & devcontainer @devcontainerArgs
}

if ($LASTEXITCODE -eq 0) {
    Write-Success "DevContainer started successfully!"

    if (-not $BuildOnly) {
        Write-Host ""
        Write-Info "To connect to the container, run:"

        if ($useWSL) {
            Write-Host "    wsl devcontainer exec --workspace-folder `"$wslWorkspacePath`" bash" -ForegroundColor White
        }
        else {
            Write-Host "    devcontainer exec --workspace-folder `"$workspaceFullPath`" bash" -ForegroundColor White
        }

        Write-Host ""
        Write-Info "Or use VS Code 'Reopen in Container'"
    }
}
else {
    throw "DevContainer failed to start (exit code: $LASTEXITCODE)"
}
