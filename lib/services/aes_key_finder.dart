import 'dart:convert';
import 'dart:io';

import '../models/aes_key_candidate.dart';

/// 自动扫描游戏文件 / 进程内存，提取 AES 密钥候选
class AesKeyFinder {
  static Future<List<AesKeyCandidate>> find({
    required String? gamePath,
    String? repakPath,
    String? retocPath,
  }) async {
    if (gamePath == null || gamePath.isEmpty) {
      throw StateError('请先在设置中配置 AION2 游戏目录');
    }
    if (!Directory(gamePath).existsSync()) {
      throw StateError('游戏目录不存在: $gamePath');
    }

    final script = _locateScript();
    if (script == null) {
      throw StateError('未找到 scripts/find_aes_keys.ps1');
    }

    final args = <String>[
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script,
      '-GamePath',
      gamePath,
    ];
    if (repakPath != null && repakPath.isNotEmpty) {
      args.addAll(['-RepakPath', repakPath]);
    }
    if (retocPath != null && retocPath.isNotEmpty) {
      args.addAll(['-RetocPath', retocPath]);
    }

    final result = await Process.run(
      'powershell',
      args,
      runInShell: true,
    );

    if (result.exitCode != 0 && (result.stdout as String).trim().isEmpty) {
      throw ProcessException(
        'powershell',
        args,
        result.stderr.toString(),
        result.exitCode,
      );
    }

    return _parseOutput(result.stdout.toString());
  }

  static List<AesKeyCandidate> _parseOutput(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return [];

    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(AesKeyCandidate.fromJson)
            .toList();
      }
      if (decoded is Map<String, dynamic>) {
        return [AesKeyCandidate.fromJson(decoded)];
      }
    } catch (_) {}

    return [];
  }

  static String? _locateScript() {
    var dir = Directory.current;
    for (var i = 0; i < 6; i++) {
      final script = File(
        '${dir.path}${Platform.pathSeparator}scripts${Platform.pathSeparator}find_aes_keys.ps1',
      );
      if (script.existsSync()) return script.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final bundled = File(
      '$exeDir${Platform.pathSeparator}scripts${Platform.pathSeparator}find_aes_keys.ps1',
    );
    if (bundled.existsSync()) return bundled.path;
    return null;
  }
}
