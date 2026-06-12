# AION2 解包工具 - Windows 启动脚本
# 原因：项目路径含中文时 Flutter/MSBuild 无法正确生成 ephemeral 文件
# 请使用英文 junction 路径运行

$JunctionPath = "D:\Adroid_ws\LpRobt_Flutter\aion2_unpacker"
$SourcePath   = $PSScriptRoot

# 若 junction 不存在则创建
if (-not (Test-Path $JunctionPath)) {
    cmd /c "mklink /J `"$JunctionPath`" `"$SourcePath`""
    if ($LASTEXITCODE -ne 0) {
        Write-Error "无法创建 junction，请手动将项目移到纯英文路径，例如 D:\Adroid_ws\LpRobt_Flutter\aion2_unpacker"
        exit 1
    }
}

Set-Location $JunctionPath
Write-Host ">>> 从英文路径启动: $JunctionPath" -ForegroundColor Cyan

# 支持 run / build 等 flutter 子命令，默认 run -d windows
if ($args.Count -eq 0) {
    flutter run -d windows
} else {
    flutter @args
}
