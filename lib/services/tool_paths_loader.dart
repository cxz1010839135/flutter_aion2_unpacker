import 'dart:convert';
import 'dart:io';

/// 从 tools/installed_paths.json 或 exe 同级 tools/ 加载外部工具路径
class ToolPathsLoader {
  static const configFileName = 'installed_paths.json';

  static Future<ToolPaths?> load() async {
    ToolPaths? fromConfig;
    for (final path in _candidateConfigPaths()) {
      final file = File(path);
      if (!file.existsSync()) continue;
      try {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        fromConfig = ToolPaths(
          retocPath: json['retocPath'] as String?,
          repakPath: json['repakPath'] as String?,
          unrealPakPath: json['unrealPakPath'] as String?,
        );
        break;
      } catch (_) {
        continue;
      }
    }

    final bundled = bundledTools();
    final merged = ToolPaths(
      retocPath: _resolveExisting(fromConfig?.retocPath) ?? bundled.retocPath,
      repakPath: _resolveExisting(fromConfig?.repakPath) ?? bundled.repakPath,
      unrealPakPath:
          _resolveExisting(fromConfig?.unrealPakPath) ?? bundled.unrealPakPath,
    );

    if (merged.retocPath == null &&
        merged.repakPath == null &&
        merged.unrealPakPath == null) {
      return null;
    }
    return merged;
  }

  /// 打包版默认路径：与 aion2_unpacker.exe 同级的 tools/retoc、tools/repak
  static ToolPaths bundledTools() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    final toolsDir = '$exeDir${sep}tools';

    String? pick(String subPath) {
      final path = '$toolsDir$sep$subPath';
      return File(path).existsSync() ? path : null;
    }

    return ToolPaths(
      retocPath: pick('retoc${sep}retoc.exe'),
      repakPath: pick('repak${sep}repak.exe'),
      unrealPakPath: pick('UnrealPak${sep}UnrealPak.exe'),
    );
  }

  static String? _resolveExisting(String? path) {
    if (path == null || path.isEmpty) return null;
    if (File(path).existsSync()) return path;

    // installed_paths.json 里可能是旧机器的绝对路径，尝试按文件名在 bundled 目录找
    final name = path.split(Platform.pathSeparator).last.toLowerCase();
    final bundled = bundledTools();
    if (name == 'retoc.exe') return bundled.retocPath;
    if (name == 'repak.exe') return bundled.repakPath;
    if (name == 'unrealpak.exe') return bundled.unrealPakPath;
    return null;
  }

  static List<String> _candidateConfigPaths() {
    final paths = <String>[];

    // 可执行文件同级 tools/
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    paths.add('$exeDir${Platform.pathSeparator}tools${Platform.pathSeparator}$configFileName');

    // 开发模式：从当前工作目录向上查找
    var dir = Directory.current;
    for (var i = 0; i < 6; i++) {
      paths.add('${dir.path}${Platform.pathSeparator}tools${Platform.pathSeparator}$configFileName');
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    return paths;
  }
}

class ToolPaths {
  const ToolPaths({this.retocPath, this.repakPath, this.unrealPakPath});

  final String? retocPath;
  final String? repakPath;
  final String? unrealPakPath;
}
