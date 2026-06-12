#Requires -Version 5.1
<#
.SYNOPSIS
  Install retoc + repak for AION2 unpacker (both download to tools/)

.EXAMPLE
  .\install_tools.ps1
  .\install_tools.ps1 -UseUnrealPak   # optional: use UE's UnrealPak instead of repak
#>

param(
    [switch]$UseUnrealPak,
    [switch]$SkipRetoc,
    [switch]$SkipRepak
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $ProjectRoot 'pubspec.yaml'))) {
    $ProjectRoot = $PSScriptRoot
}

$ToolsDir     = Join-Path $ProjectRoot 'tools'
$RetocDir     = Join-Path $ToolsDir 'retoc'
$RepakDir     = Join-Path $ToolsDir 'repak'
$UnrealPakDir = Join-Path $ToolsDir 'UnrealPak'
$ConfigFile   = Join-Path $ToolsDir 'installed_paths.json'

$RetocVersion = '0.1.5'
$RepakVersion = '0.2.3'
$RetocZipUrl  = "https://github.com/trumank/retoc/releases/download/v$RetocVersion/retoc_cli-x86_64-pc-windows-msvc.zip"
$RepakZipUrl  = "https://github.com/trumank/repak/releases/download/v$RepakVersion/repak_cli-x86_64-pc-windows-msvc.zip"
$RetocExePath = Join-Path $RetocDir 'retoc.exe'
$RepakExePath = Join-Path $RepakDir 'repak.exe'

function Write-Step($msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "  [!!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "  [XX] $msg" -ForegroundColor Red }

function Save-Config($retocPath, $repakPath, $unrealPakPath) {
    $config = [ordered]@{
        retocPath     = $retocPath
        repakPath     = $repakPath
        unrealPakPath = $unrealPakPath
        installedAt   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        retocVersion  = $RetocVersion
        repakVersion  = $RepakVersion
    }
    New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
    $config | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
    Write-Ok "Config saved: $ConfigFile"
}

function Install-CliTool {
    param(
        [string]$Name,
        [string]$Version,
        [string]$ZipUrl,
        [string]$TargetDir,
        [string]$ExePath,
        [string]$ExeName
    )

    Write-Step "Installing $Name v$Version"

    if (Test-Path $ExePath) {
        Write-Ok "$Name already exists: $ExePath"
        return $ExePath
    }

    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    $tempZip = Join-Path $env:TEMP "${Name}_cli-$Version.zip"
    $tempExtract = Join-Path $env:TEMP "${Name}_cli_extract_$Version"

    Write-Host "  Downloading..."
    Invoke-WebRequest -Uri $ZipUrl -OutFile $tempZip -UseBasicParsing

    if (Test-Path $tempExtract) { Remove-Item -Recurse -Force $tempExtract }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

    $exe = Get-ChildItem -Path $tempExtract -Filter $ExeName -Recurse | Select-Object -First 1
    if (-not $exe) { throw "$ExeName not found in archive" }

    Copy-Item $exe.FullName $ExePath -Force
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

    $ver = & $ExePath --version 2>&1
    Write-Ok "$Name installed: $ExePath ($ver)"
    return $ExePath
}

function Install-Retoc {
    Install-CliTool -Name 'retoc' -Version $RetocVersion -ZipUrl $RetocZipUrl `
        -TargetDir $RetocDir -ExePath $RetocExePath -ExeName 'retoc.exe'
}

function Install-Repak {
    Install-CliTool -Name 'repak' -Version $RepakVersion -ZipUrl $RepakZipUrl `
        -TargetDir $RepakDir -ExePath $RepakExePath -ExeName 'repak.exe'
}

function Find-UnrealPak {
    Write-Step 'Searching UnrealPak.exe (UE 5.x)'

    $candidates = New-Object System.Collections.Generic.List[string]

    $epicRoot = 'C:\Program Files\Epic Games'
    if (Test-Path $epicRoot) {
        Get-ChildItem $epicRoot -Directory -Filter 'UE_5.*' -ErrorAction SilentlyContinue | ForEach-Object {
            $candidates.Add((Join-Path $_.FullName 'Engine\Binaries\Win64\UnrealPak.exe'))
        }
    }

    $regPaths = @(
        'HKLM:\SOFTWARE\EpicGames\Unreal Engine',
        'HKLM:\SOFTWARE\WOW6432Node\EpicGames\Unreal Engine'
    )
    foreach ($reg in $regPaths) {
        if (-not (Test-Path $reg)) { continue }
        Get-ChildItem $reg -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $installed = (Get-ItemProperty $_.PSPath -ErrorAction Stop).InstalledDirectory
                if ($installed) {
                    $candidates.Add((Join-Path $installed 'Engine\Binaries\Win64\UnrealPak.exe'))
                }
            } catch {}
        }
    }

    foreach ($drive in @('C', 'D', 'E', 'F')) {
        $candidates.Add("${drive}:\Program Files\Epic Games\UE_5.3\Engine\Binaries\Win64\UnrealPak.exe")
        $candidates.Add("${drive}:\Epic Games\UE_5.3\Engine\Binaries\Win64\UnrealPak.exe")
    }

    $found = $candidates | Select-Object -Unique | Where-Object { Test-Path $_ } |
        Sort-Object { if ($_ -match 'UE_5\.3') { 0 } elseif ($_ -match 'UE_5\.4') { 1 } else { 2 } }

    return $found | Select-Object -First 1
}

function Copy-UnrealPakBundle($sourceExe) {
    Write-Step 'Copying UnrealPak to tools/UnrealPak (with DLLs)'

    $sourceDir = Split-Path -Parent $sourceExe
    New-Item -ItemType Directory -Path $UnrealPakDir -Force | Out-Null

    Copy-Item $sourceExe $UnrealPakDir -Force
    Get-ChildItem $sourceDir -Filter '*.dll' -ErrorAction SilentlyContinue |
        Copy-Item -Destination $UnrealPakDir -Force

    $dest = Join-Path $UnrealPakDir 'UnrealPak.exe'
    Write-Ok "Copied to: $dest"
    return $dest
}

Write-Host ''
Write-Host '  ========================================' -ForegroundColor Yellow
Write-Host '    AION2 Unpacker - Tool Installer' -ForegroundColor Yellow
Write-Host '  ========================================' -ForegroundColor Yellow
Write-Host "  Project: $ProjectRoot" -ForegroundColor DarkGray

$retocPath = $null
$repakPath = $null
$unrealPakPath = $null

if (Test-Path $ConfigFile) {
    try {
        $existing = Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($existing.retocPath -and (Test-Path $existing.retocPath)) {
            $retocPath = $existing.retocPath
        }
        if ($existing.repakPath -and (Test-Path $existing.repakPath)) {
            $repakPath = $existing.repakPath
        }
        if ($existing.unrealPakPath -and (Test-Path $existing.unrealPakPath)) {
            $unrealPakPath = $existing.unrealPakPath
        }
    } catch {}
}

if (-not $SkipRetoc) {
    try {
        $retocPath = Install-Retoc
    } catch {
        Write-Err "retoc install failed: $_"
    }
}

if (-not $SkipRepak -and -not $UseUnrealPak) {
    try {
        $repakPath = Install-Repak
    } catch {
        Write-Err "repak install failed: $_"
    }
}

if ($UseUnrealPak) {
    if ($unrealPakPath -and (Test-Path $unrealPakPath)) {
        Write-Ok "UnrealPak already configured: $unrealPakPath"
    } else {
        $found = Find-UnrealPak
        if ($found) {
            Write-Ok "Found UnrealPak: $found"
            $unrealPakPath = Copy-UnrealPakBundle $found
        } else {
            Write-Warn 'UnrealPak not found. Install UE 5.x or omit -UseUnrealPak to use repak instead.'
        }
    }
}

if ($retocPath -or $repakPath -or $unrealPakPath) {
    Save-Config $retocPath $repakPath $unrealPakPath
}

$prefsScript = Join-Path $PSScriptRoot 'sync_tool_paths.ps1'
if (Test-Path $prefsScript) {
    Write-Step 'Syncing paths to app settings'
    & $prefsScript -ProjectRoot $ProjectRoot -RetocPath $retocPath -RepakPath $repakPath -UnrealPakPath $unrealPakPath
}

Write-Host ''
Write-Host '  --- Result ---' -ForegroundColor Yellow
if ($retocPath -and (Test-Path $retocPath)) {
    Write-Ok "retoc     : $retocPath"
} else {
    Write-Err 'retoc     : NOT installed'
}
if ($repakPath -and (Test-Path $repakPath)) {
    Write-Ok "repak     : $repakPath"
} else {
    Write-Err 'repak     : NOT installed'
}
if ($unrealPakPath -and (Test-Path $unrealPakPath)) {
    Write-Ok "UnrealPak : $unrealPakPath"
}

Write-Host ''
Write-Host '  Restart the app and click Refresh in Settings.' -ForegroundColor Cyan
Write-Host ''
