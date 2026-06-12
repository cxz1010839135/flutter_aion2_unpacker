#Requires -Version 5.1
<#
.SYNOPSIS
  将 tools/installed_paths.json 中的路径同步到 Flutter SharedPreferences
#>

param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$RetocPath,
    [string]$RepakPath,
    [string]$UnrealPakPath
)

$ConfigFile = Join-Path $ProjectRoot 'tools\installed_paths.json'

if (-not $RetocPath -and -not $RepakPath -and -not $UnrealPakPath -and (Test-Path $ConfigFile)) {
    $cfg = Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $RetocPath     = $cfg.retocPath
    $RepakPath     = $cfg.repakPath
    $UnrealPakPath = $cfg.unrealPakPath
}

# Flutter Windows shared_preferences 存储位置
$prefsDirs = @(
    (Join-Path $env:APPDATA 'com.aion2.tools\aion2_unpacker'),
    (Join-Path $env:APPDATA 'aion2_unpacker')
)

$prefsFile = $null
foreach ($dir in $prefsDirs) {
    $f = Join-Path $dir 'shared_preferences.json'
    if (Test-Path $f) { $prefsFile = $f; break }
}

# 若不存在则创建默认目录
if (-not $prefsFile) {
    $dir = $prefsDirs[0]
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $prefsFile = Join-Path $dir 'shared_preferences.json'
}

$prefs = @{}
if (Test-Path $prefsFile) {
    try {
        $raw = Get-Content $prefsFile -Raw -Encoding UTF8
        if ($raw) {
            $obj = $raw | ConvertFrom-Json
            $obj.PSObject.Properties | ForEach-Object { $prefs[$_.Name] = $_.Value }
        }
    } catch {
        $prefs = @{}
    }
}

if ($RetocPath -and (Test-Path $RetocPath)) {
    $prefs['flutter.retoc_path'] = $RetocPath
}
if ($RepakPath -and (Test-Path $RepakPath)) {
    $prefs['flutter.repak_path'] = $RepakPath
}
if ($UnrealPakPath -and (Test-Path $UnrealPakPath)) {
    $prefs['flutter.unrealpak_path'] = $UnrealPakPath
}

($prefs | ConvertTo-Json) | Set-Content -Path $prefsFile -Encoding UTF8
Write-Host "  [OK] 已同步到应用配置: $prefsFile" -ForegroundColor Green
