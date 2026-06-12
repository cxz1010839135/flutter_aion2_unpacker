import 'dart:convert';
import 'dart:io';

/// 从 tools/installed_paths.json 加载外部工具路径（由 install_tools.ps1 生成）
class ToolPathsLoader {
  static const configFileName = 'installed_paths.json';

  static Future<ToolPaths?> load() async {
    for (final path in _candidateConfigPaths()) {
      final file = File(path);
      if (!file.existsSync()) continue;
      try {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final retoc = json['retocPath'] as String?;
        final repak = json['repakPath'] as String?;
        final unrealPak = json['unrealPakPath'] as String?;
        if (retoc == null && repak == null && unrealPak == null) continue;
        return ToolPaths(
          retocPath: retoc,
          repakPath: repak,
          unrealPakPath: unrealPak,
        );
      } catch (_) {
        continue;
      }
    }
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
