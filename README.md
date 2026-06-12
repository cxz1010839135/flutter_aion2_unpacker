# flutter_aion2_unpacker

AION2 游戏资源解包工具（Flutter Windows 桌面版），支持 UE 5.3 IoStore 格式（`.pak` / `.utoc` / `.ucas`）。

## 功能

- 扫描 AION2 `Content/Paks` 目录下的资源容器
- 浏览 `.pak` 索引与 `.utoc` 条目列表
- 一键解包到指定输出目录
- 自动安装外部工具 **retoc**（IoStore）和 **repak**（.pak）
- 自动扫描 / 验证 AES 加密密钥（支持多密钥选择）

## 环境要求

- Windows 10/11 x64
- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows)（含 Windows 桌面支持）
- Visual Studio 2022（含「使用 C++ 的桌面开发」工作负载）

## 快速开始（开发）

```powershell
# 克隆项目
git clone https://github.com/cxz1010839135/flutter_aion2_unpacker.git
cd flutter_aion2_unpacker

# 安装外部工具（retoc + repak）
.\install_tools.bat

# 运行（Debug）
.\run_windows.bat
```

## 一键打包 EXE

双击或在终端运行：

```powershell
.\build_windows.bat
```

打包完成后输出：

| 输出 | 路径 |
|------|------|
| 可运行目录 | `dist/aion2_unpacker_win64/` |
| 压缩包 | `dist/aion2_unpacker_win64_v1.0.0.zip` |

将 `dist/aion2_unpacker_win64/` 整个文件夹（或 ZIP）复制到新电脑即可运行。

**已内置 retoc + repak**，解压后打开 EXE 即可使用，无需联网、无需点「一键安装依赖」。

目录结构：

```
aion2_unpacker_win64/
  aion2_unpacker.exe
  tools/
    retoc/retoc.exe
    repak/repak.exe
  install_tools.bat   # 可选，用于更新工具版本
```

> 若项目路径含中文，脚本会自动创建英文 junction 路径（`D:\Adroid_ws\LpRobt_Flutter\aion2_unpacker`）再编译，与 `run_windows.bat` 行为一致。

## 使用说明

1. **设置游戏目录** — 选择 AION2 安装路径（例如 `NCSOFT\AION2_TW\Aion2`）
2. **一键安装依赖** — 在设置页安装 retoc / repak
3. **AES 密钥**（可选）— 加密资源需配置密钥；可点「自动获取」（建议先启动游戏）
4. **扫描并解包** — 选择容器文件后执行解包

典型资源路径：

```
NCSOFT\AION2_TW\Aion2\Content\Paks\
NCSOFT\AION2_TW\Aion2\Content\Paks\L10N\Text\en-US\pakchunk502000-Windows_0_P.pak
```

## 脚本说明

| 脚本 | 说明 |
|------|------|
| `run_windows.bat` | 开发模式运行 |
| `build_windows.bat` | 一键打包 Release EXE |
| `install_tools.bat` | 下载安装 retoc / repak 到 `tools/` |
| `scripts/find_aes_keys.ps1` | AES 密钥扫描（由应用内「自动获取」调用） |

## 外部工具

- [retoc](https://github.com/trumank/retoc) — IoStore（`.utoc` / `.ucas`）解包
- [repak](https://github.com/trumank/repak) — `.pak` 解包（替代 UnrealPak，可一键安装）
- [FModel](https://fmodel.app/) — 资源浏览 / 获取 AES 密钥参考

## License

本项目仅供学习与研究使用。请遵守 NCSOFT 及游戏相关服务条款。
