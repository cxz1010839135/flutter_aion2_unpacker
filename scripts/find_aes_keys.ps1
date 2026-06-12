#Requires -Version 5.1
<#
.SYNOPSIS
  扫描 AION2 游戏文件 / 进程内存，提取并验证 AES 密钥

.EXAMPLE
  .\find_aes_keys.ps1 -GamePath "C:\...\Aion2" -RepakPath "...\repak.exe"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,
    [string]$RepakPath,
    [string]$RetocPath
)

$ErrorActionPreference = 'SilentlyContinue'

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WinMem {
    [Flags] public enum ProcessAccess : uint { VMRead = 0x0010, QueryInformation = 0x0400 }
    [StructLayout(LayoutKind.Sequential)]
    public struct MEMORY_BASIC_INFORMATION {
        public IntPtr BaseAddress;
        public IntPtr AllocationBase;
        public uint AllocationProtect;
        public IntPtr RegionSize;
        public uint State;
        public uint Protect;
        public uint Type;
    }
    public const uint MEM_COMMIT = 0x1000;
    public const uint PAGE_NOACCESS = 0x01;
    public const uint PAGE_GUARD = 0x100;
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(ProcessAccess access, bool inherit, int pid);
    [DllImport("kernel32.dll")] public static extern int VirtualQueryEx(IntPtr proc, IntPtr addr, out MEMORY_BASIC_INFORMATION mbi, uint len);
    [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr proc, IntPtr addr, byte[] buf, int size, out int read);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
}
'@

function Test-PotentialKeyBytes([byte[]]$bytes) {
    if ($bytes.Length -ne 32) { return $false }
    $unique = ($bytes | Select-Object -Unique).Count
    if ($unique -lt 8) { return $false }
    $zeros = ($bytes | Where-Object { $_ -eq 0 }).Count
    if ($zeros -gt 24) { return $false }
    return $true
}

function Add-KeyFromBytes([byte[]]$data, [hashtable]$store, [string]$source) {
    for ($i = 0; $i -le $data.Length - 32; $i++) {
        $chunk = $data[$i..($i + 31)]
        if (-not (Test-PotentialKeyBytes $chunk)) { continue }
        $hex = '0x' + (($chunk | ForEach-Object { $_.ToString('X2') }) -join '')
        if (-not $store.ContainsKey($hex)) {
            $store[$hex] = @{ source = $source; verified = $false; label = $null }
        }
    }
    try {
        $text = [System.Text.Encoding]::ASCII.GetString($data)
        foreach ($m in [regex]::Matches($text, '0x([0-9A-Fa-f]{64})')) {
            $hex = '0x' + $m.Groups[1].Value.ToUpper()
            if (-not $store.ContainsKey($hex)) {
                $store[$hex] = @{ source = $source; verified = $false; label = $null }
            }
        }
    } catch {}
}

function Scan-File($path, [hashtable]$store, [string]$source) {
    if (-not (Test-Path $path)) { return }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        Add-KeyFromBytes $bytes $store $source
    } catch {}
}

function Scan-ProcessMemory([hashtable]$store) {
    $proc = Get-Process -Name Aion2 -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) { return }

    $handle = [WinMem]::OpenProcess([WinMem+ProcessAccess]::VMRead -bor [WinMem+ProcessAccess]::QueryInformation, $false, $proc.Id)
    if ($handle -eq [IntPtr]::Zero) { return }

    try {
        $addr = [IntPtr]::Zero
        $mbi = New-Object WinMem+MEMORY_BASIC_INFORMATION
        while ([WinMem]::VirtualQueryEx($handle, $addr, [ref]$mbi, [System.Runtime.InteropServices.Marshal]::SizeOf($mbi)) -ne 0) {
            $size = [int64]$mbi.RegionSize
            if ($mbi.State -eq [WinMem]::MEM_COMMIT -and
                ($mbi.Protect -band [WinMem]::PAGE_NOACCESS) -eq 0 -and
                ($mbi.Protect -band [WinMem]::PAGE_GUARD) -eq 0 -and
                $size -ge 4096 -and $size -le 64MB) {
                $buf = New-Object byte[] ([Math]::Min($size, 16MB))
                $read = 0
                if ([WinMem]::ReadProcessMemory($handle, $mbi.BaseAddress, $buf, $buf.Length, [ref]$read) -and $read -ge 32) {
                    Add-KeyFromBytes $buf[0..($read - 1)] $store 'Aion2.exe 进程内存 (游戏需正在运行)'
                }
            }
            $addr = [IntPtr]([int64]$mbi.BaseAddress + $size)
        }
    } finally {
        [WinMem]::CloseHandle($handle) | Out-Null
    }
}

function Get-TestPak($gamePath) {
    $paksDir = Join-Path $gamePath 'Content\Paks'
    if (-not (Test-Path $paksDir)) { return $null }
    $paks = Get-ChildItem $paksDir -Filter '*.pak' -Recurse -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending
    return $paks | Select-Object -First 1
}

function Get-TestUtoc($gamePath) {
    $paksDir = Join-Path $gamePath 'Content\Paks'
    if (-not (Test-Path $paksDir)) { return $null }
    $utocs = Get-ChildItem $paksDir -Filter '*.utoc' -Recurse -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending
    return $utocs | Select-Object -First 1
}

function Test-KeyWithRepak($key, $pakFile, $repakExe) {
    if (-not $repakExe -or -not (Test-Path $repakExe) -or -not $pakFile) { return $false }
    & $repakExe --aes-key $key list $pakFile.FullName 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

function Test-KeyWithRetoc($key, $utocFile, $retocExe) {
    if (-not $retocExe -or -not (Test-Path $retocExe) -or -not $utocFile) { return $false }
    & $retocExe --aes-key $key list $utocFile.FullName 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

$keys = @{}

# 1. 配置文件
$configDirs = @(
    (Join-Path $GamePath 'Config'),
    (Join-Path $GamePath 'Saved\Config\Windows'),
    (Join-Path $GamePath 'Saved\Config\WindowsClient')
)
foreach ($dir in $configDirs) {
    if (-not (Test-Path $dir)) { continue }
    Get-ChildItem $dir -Include '*.ini', '*.json', '*.cfg' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        Scan-File $_.FullName $keys "配置文件: $($_.Name)"
    }
}

# 2. 游戏二进制
$binDir = Join-Path $GamePath 'Binaries\Win64'
if (Test-Path $binDir) {
    Get-ChildItem $binDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.exe', '.dll' } |
        ForEach-Object {
            Scan-File $_.FullName $keys "二进制: $($_.Name)"
        }
}

# 3. Process memory
Scan-ProcessMemory $keys

# 4. Validate (cap candidates to keep UI responsive)
$testPak = Get-TestPak $GamePath
$testUtoc = Get-TestUtoc $GamePath
$maxValidate = 120
$toValidate = @($keys.Keys | Select-Object -First $maxValidate)
foreach ($hex in $toValidate) {
    $verified = $false
    if (Test-KeyWithRepak $hex $testPak $RepakPath) { $verified = $true }
    elseif (Test-KeyWithRetoc $hex $testUtoc $RetocPath) { $verified = $true }
    $keys[$hex].verified = $verified
}

$result = @($keys.GetEnumerator() | ForEach-Object {
    [ordered]@{
        key      = $_.Key
        source   = $_.Value.source
        verified = [bool]$_.Value.verified
        label    = if ($_.Value.verified) { 'verified' } else { $null }
    }
} | Sort-Object { -not $_.verified }, key)

if ($result.Count -eq 0) {
    '[]'
} else {
    $verified = @($result | Where-Object { $_.verified })
    $others = @($result | Where-Object { -not $_.verified } | Select-Object -First 80)
    @($verified + $others) | ConvertTo-Json -Depth 4 -Compress
}
