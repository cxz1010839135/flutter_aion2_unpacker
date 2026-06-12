#Requires -Version 5.1
<#
.SYNOPSIS
  一键打包 AION2 解包工具 Windows Release 版本（内置 retoc + repak）
#>

$ErrorActionPreference = 'Stop'

$SourcePath   = $PSScriptRoot
$AppName      = 'aion2_unpacker'
$DistRoot     = Join-Path $SourcePath 'dist'
$DistDir      = Join-Path $DistRoot "${AppName}_win64"
$ReleaseDir   = Join-Path $SourcePath "build\windows\x64\runner\Release"
$JunctionPath = 'D:\Adroid_ws\LpRobt_Flutter\aion2_unpacker'
$RetocVersion = '0.1.5'
$RepakVersion = '0.2.3'

function Write-Step($msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Err($msg)   { Write-Host "  [XX] $msg" -ForegroundColor Red }

function Test-NonAsciiPath([string]$path) {
    return $path.ToCharArray() | Where-Object { [int][char]$_ -gt 127 } | Select-Object -First 1
}

function Resolve-BuildPath {
    if (Test-Path (Join-Path $SourcePath 'pubspec.yaml')) {
        if (-not (Test-NonAsciiPath $SourcePath)) {
            return $SourcePath
        }
    }

    if (-not (Test-Path $JunctionPath) -or -not (Test-Path (Join-Path $JunctionPath 'pubspec.yaml'))) {
        Write-Step 'Creating English junction path'
        if (Test-Path $JunctionPath) { cmd /c "rmdir `"$JunctionPath`"" | Out-Null }
        cmd /c "mklink /J `"$JunctionPath`" `"$SourcePath`""
        if ($LASTEXITCODE -ne 0) {
            Write-Err '无法创建 junction，请将项目放在纯英文路径下再打包'
            exit 1
        }
    }

    return $JunctionPath
}

function Ensure-BundledTools {
    Write-Step 'Downloading retoc + repak for bundle'
    $installScript = Join-Path $SourcePath 'scripts\install_tools.ps1'
    if (-not (Test-Path $installScript)) {
        Write-Err "未找到 $installScript"
        exit 1
    }

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $installScript 2>&1 | Out-Host
    $ErrorActionPreference = $prevEap

    $retoc = Join-Path $SourcePath 'tools\retoc\retoc.exe'
    $repak = Join-Path $SourcePath 'tools\repak\repak.exe'
    if (-not (Test-Path $retoc)) { Write-Err "retoc 未就绪: $retoc"; exit 1 }
    if (-not (Test-Path $repak)) { Write-Err "repak 未就绪: $repak"; exit 1 }
    Write-Ok 'retoc + repak ready'
}

function Write-DistToolConfig($distToolsDir) {
    $config = [ordered]@{
        retocPath     = Join-Path $distToolsDir 'retoc\retoc.exe'
        repakPath     = Join-Path $distToolsDir 'repak\repak.exe'
        unrealPakPath = $null
        bundled       = $true
        retocVersion  = $RetocVersion
        repakVersion  = $RepakVersion
        note          = 'Portable bundle; app also auto-detects tools next to exe'
    }
    $config | ConvertTo-Json | Set-Content (Join-Path $distToolsDir 'installed_paths.json') -Encoding UTF8
}

Write-Host ''
Write-Host '  ========================================' -ForegroundColor Yellow
Write-Host '    AION2 Unpacker - Windows Build' -ForegroundColor Yellow
Write-Host '  ========================================' -ForegroundColor Yellow

Ensure-BundledTools

$BuildPath = Resolve-BuildPath
Set-Location $BuildPath
Write-Ok "Build from: $BuildPath"

Write-Step 'Checking Flutter'
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Write-Err '未找到 flutter，请先安装 Flutter SDK 并加入 PATH'
    exit 1
}
Write-Ok "Flutter: $(flutter --version | Select-Object -First 1)"

Write-Step 'Building Windows Release'
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Test-Path $ReleaseDir)) {
    Write-Err "未找到输出目录: $ReleaseDir"
    exit 1
}

Write-Step 'Packaging to dist/ (with bundled tools)'
if (Test-Path $DistDir) { Remove-Item $DistDir -Recurse -Force }
New-Item -ItemType Directory -Path $DistDir -Force | Out-Null

Copy-Item -Path (Join-Path $ReleaseDir '*') -Destination $DistDir -Recurse -Force

# 内置 retoc / repak（新电脑解压即用，无需联网安装）
$distTools = Join-Path $DistDir 'tools'
New-Item -ItemType Directory -Path $distTools -Force | Out-Null
Copy-Item (Join-Path $SourcePath 'tools\retoc') (Join-Path $distTools 'retoc') -Recurse -Force
Copy-Item (Join-Path $SourcePath 'tools\repak') (Join-Path $distTools 'repak') -Recurse -Force
Write-DistToolConfig $distTools
Write-Ok 'Bundled tools/retoc + tools/repak'

# 可选：保留安装脚本供更新工具版本
$scriptsDest = Join-Path $DistDir 'scripts'
New-Item -ItemType Directory -Path $scriptsDest -Force | Out-Null
Copy-Item (Join-Path $SourcePath 'scripts\*.ps1') $scriptsDest -Force
Copy-Item (Join-Path $SourcePath 'install_tools.bat') $DistDir -Force

$version = (Select-String -Path (Join-Path $SourcePath 'pubspec.yaml') -Pattern '^version:\s*(.+)$').Matches.Groups[1].Value.Trim()
$zipName = "${AppName}_win64_v$($version -replace '\+.*','').zip"
$zipPath = Join-Path $DistRoot $zipName

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $DistDir -DestinationPath $zipPath -Force

Write-Host ''
Write-Host '  --- Result ---' -ForegroundColor Yellow
Write-Ok "EXE     : $(Join-Path $DistDir "$AppName.exe")"
Write-Ok "Folder  : $DistDir"
Write-Ok "ZIP     : $zipPath"
Write-Ok "Tools   : $distTools (retoc + repak included)"
Write-Host ''
Write-Host '  复制 dist 文件夹或 ZIP 到新电脑即可直接使用，无需安装依赖' -ForegroundColor Cyan
Write-Host ''
