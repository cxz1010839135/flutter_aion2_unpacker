import 'dart:io';

import '../core/constants.dart';
import '../models/container_file.dart';

class ContainerScanner {
  /// 扫描 Paks 目录下的所有容器文件
  static Future<List<ContainerFile>> scanDirectory(String paksDir) async {
    final dir = Directory(paksDir);
    if (!dir.existsSync()) return [];

    final containers = <ContainerFile>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
      if (!name.endsWith('.pak') &&
          !name.endsWith('.utoc') &&
          !name.endsWith('.ucas')) {
        continue;
      }
      final relative = entity.path
          .substring(paksDir.length)
          .replaceFirst(Platform.pathSeparator, '');
      containers.add(ContainerFile.fromFile(entity, relativePath: relative));
    }

    containers.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return containers;
  }

  /// 自动检测 AION2 游戏安装路径
  static Future<String?> detectGamePath() async {
    for (final base in Aion2Constants.defaultGamePaths) {
      final paksDir = '$base${Platform.pathSeparator}${Aion2Constants.paksSubPath}';
      if (Directory(paksDir).existsSync()) return base;
    }
    return null;
  }

  /// 获取 Paks 目录路径
  static String paksPath(String gamePath) {
    return '$gamePath${Platform.pathSeparator}${Aion2Constants.paksSubPath}';
  }

  /// 按类型分组统计
  static Map<ContainerType, int> groupByType(List<ContainerFile> files) {
    final map = <ContainerType, int>{};
    for (final f in files) {
      map[f.type] = (map[f.type] ?? 0) + 1;
    }
    return map;
  }

  /// 计算总大小
  static int totalSize(List<ContainerFile> files) {
    return files.fold(0, (sum, f) => sum + f.size);
  }
}
