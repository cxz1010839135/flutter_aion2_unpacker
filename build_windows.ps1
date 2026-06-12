#Requires -Version 5.1
<#
.SYNOPSIS
  一键打包 AION2 解包工具 Windows Release 版本
#>

$ErrorActionPreference = 'Stop'

$SourcePath   = $PSScriptRoot
$AppName      = 'aion2_unpacker'
$DistRoot     = Join-Path $SourcePath 'dist'
$DistDir      = Join-Path $DistRoot "${AppName}_win64"
$ReleaseDir   = Join-Path $SourcePath "build\windows\x64\runner\Release"
$JunctionPath = 'D:\Adroid_ws\LpRobt_Flutter\aion2_unpacker'

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

Write-Host ''
Write-Host '  ========================================' -ForegroundColor Yellow
Write-Host '    AION2 Unpacker - Windows Build' -ForegroundColor Yellow
Write-Host '  ========================================' -ForegroundColor Yellow

# 中文路径时使用英文 junction（与 run_windows.ps1 相同）
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

Write-Step 'Packaging to dist/'
if (Test-Path $DistDir) { Remove-Item $DistDir -Recurse -Force }
New-Item -ItemType Directory -Path $DistDir -Force | Out-Null

Copy-Item -Path (Join-Path $ReleaseDir '*') -Destination $DistDir -Recurse -Force

# 附带依赖安装脚本
$scriptsDest = Join-Path $DistDir 'scripts'
New-Item -ItemType Directory -Path $scriptsDest -Force | Out-Null
Copy-Item (Join-Path $SourcePath 'scripts\*.ps1') $scriptsDest -Force
Copy-Item (Join-Path $SourcePath 'install_tools.bat') $DistDir -Force
New-Item -ItemType Directory -Path (Join-Path $DistDir 'tools') -Force | Out-Null
Copy-Item (Join-Path $SourcePath 'tools\.gitkeep') (Join-Path $DistDir 'tools\.gitkeep') -Force -ErrorAction SilentlyContinue

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
Write-Host ''
Write-Host '  首次使用请运行 install_tools.bat 安装 retoc / repak' -ForegroundColor Cyan
Write-Host ''
