import 'dart:io';

import '../models/extract_task.dart';

/// 调用外部 CLI 工具 (retoc / repak / UnrealPak) 进行解包
class ExternalToolService {
  ExternalToolService({
    this.retocPath,
    this.repakPath,
    this.unrealPakPath,
    this.aesKey,
  });

  String? retocPath;
  String? repakPath;
  String? unrealPakPath;
  String? aesKey;

  bool get hasRetoc => retocPath != null && File(retocPath!).existsSync();
  bool get hasRepak => repakPath != null && File(repakPath!).existsSync();
  bool get hasUnrealPak =>
      unrealPakPath != null && File(unrealPakPath!).existsSync();
  bool get hasPakTool => hasRepak || hasUnrealPak;

  /// 使用 retoc 列出 utoc 容器内容
  Future<List<String>> retocList(String utocPath) async {
    _ensureRetoc();
    final result = await Process.run(
      retocPath!,
      _aesArgs(['list', utocPath]),
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        retocPath!,
        ['list'],
        result.stderr.toString(),
        result.exitCode,
      );
    }
    return result.stdout
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
  }

  /// 使用 retoc 解包 utoc 容器
  Future<void> retocUnpack(
    String utocPath,
    String outputDir, {
    void Function(String line)? onLog,
  }) async {
    _ensureRetoc();
    await Directory(outputDir).create(recursive: true);

    final process = await Process.start(
      retocPath!,
      _aesArgs(['unpack', utocPath, outputDir]),
      runInShell: true,
    );

    await for (final line in process.stdout.transform(SystemEncoding().decoder)) {
      onLog?.call(line.toString().trimRight());
    }
    await for (final line in process.stderr.transform(SystemEncoding().decoder)) {
      onLog?.call('[ERR] ${line.toString().trimRight()}');
    }

    final code = await process.exitCode;
    if (code != 0) throw ProcessException(retocPath!, ['unpack'], '', code);
  }

  /// 使用 retoc 将 IoStore 转为 Legacy PAK
  Future<void> retocToLegacy(
    String paksDir,
    String outputPak, {
    void Function(String line)? onLog,
  }) async {
    _ensureRetoc();

    final process = await Process.start(
      retocPath!,
      _aesArgs(['to-legacy', paksDir, outputPak]),
      runInShell: true,
    );

    await for (final line in process.stdout.transform(SystemEncoding().decoder)) {
      onLog?.call(line.toString().trimRight());
    }
    await for (final line in process.stderr.transform(SystemEncoding().decoder)) {
      onLog?.call('[ERR] ${line.toString().trimRight()}');
    }

    final code = await process.exitCode;
    if (code != 0) throw ProcessException(retocPath!, ['to-legacy'], '', code);
  }

  /// 使用 repak 或 UnrealPak 解包 .pak
  Future<void> pakExtract(
    String pakPath,
    String outputDir, {
    void Function(String line)? onLog,
  }) async {
    if (hasRepak) {
      await repakExtract(pakPath, outputDir, onLog: onLog);
    } else if (hasUnrealPak) {
      await unrealPakExtract(pakPath, outputDir, onLog: onLog);
    } else {
      throw StateError('未配置 repak.exe 或 UnrealPak.exe，请在设置中指定路径或运行一键安装');
    }
  }

  /// 使用 repak 解包
  Future<void> repakExtract(
    String pakPath,
    String outputDir, {
    void Function(String line)? onLog,
  }) async {
    _ensureRepak();
    await Directory(outputDir).create(recursive: true);

    final args = <String>[
      ..._repakAesArgs(),
      'unpack',
      pakPath,
      '-o',
      outputDir,
      '-f',
    ];

    final process = await Process.start(
      repakPath!,
      args,
      runInShell: true,
    );

    await for (final line in process.stdout.transform(SystemEncoding().decoder)) {
      onLog?.call(line.toString().trimRight());
    }
    await for (final line in process.stderr.transform(SystemEncoding().decoder)) {
      onLog?.call('[ERR] ${line.toString().trimRight()}');
    }

    final code = await process.exitCode;
    if (code != 0) throw ProcessException(repakPath!, args, '', code);
  }

  /// 使用 UnrealPak 解包
  Future<void> unrealPakExtract(
    String pakPath,
    String outputDir, {
    void Function(String line)? onLog,
  }) async {
    _ensureUnrealPak();
    await Directory(outputDir).create(recursive: true);

    final args = <String>[pakPath, '-Extract', outputDir];
    if (aesKey != null && aesKey!.isNotEmpty) {
      args.addAll(['-cryptokeys=$aesKey']);
    }

    final process = await Process.start(
      unrealPakPath!,
      args,
      runInShell: true,
    );

    await for (final line in process.stdout.transform(SystemEncoding().decoder)) {
      onLog?.call(line.toString().trimRight());
    }
    await for (final line in process.stderr.transform(SystemEncoding().decoder)) {
      onLog?.call('[ERR] ${line.toString().trimRight()}');
    }

    final code = await process.exitCode;
    if (code != 0) {
      throw ProcessException(unrealPakPath!, args, '', code);
    }
  }

  /// 获取 retoc 容器信息
  Future<String> retocInfo(String utocPath) async {
    _ensureRetoc();
    final result = await Process.run(
      retocPath!,
      _aesArgs(['info', utocPath]),
      runInShell: true,
    );
    return result.stdout.toString();
  }

  List<String> _aesArgs(List<String> args) {
    if (aesKey != null && aesKey!.isNotEmpty) {
      return ['--aes-key', aesKey!, ...args];
    }
    return args;
  }

  List<String> _repakAesArgs() {
    if (aesKey != null && aesKey!.isNotEmpty) {
      return ['--aes-key', aesKey!];
    }
    return const [];
  }

  void _ensureRetoc() {
    if (!hasRetoc) {
      throw StateError('未配置 retoc.exe，请在设置中指定路径');
    }
  }

  void _ensureRepak() {
    if (!hasRepak) {
      throw StateError('未配置 repak.exe，请在设置中指定路径');
    }
  }

  void _ensureUnrealPak() {
    if (!hasUnrealPak) {
      throw StateError('未配置 UnrealPak.exe，请在设置中指定路径');
    }
  }
}

class ExtractorService {
  ExtractorService(this._toolService);

  final ExternalToolService _toolService;

  /// 执行解包任务
  Future<ExtractTask> runTask(
    ExtractTask task, {
    void Function(ExtractTask)? onUpdate,
  }) async {
    task.status = ExtractStatus.running;
    task.message = '正在解包...';
    onUpdate?.call(task);

    try {
      final source = task.sourcePath.toLowerCase();
      if (source.endsWith('.utoc')) {
        await _toolService.retocUnpack(
          task.sourcePath,
          task.outputPath,
          onLog: (line) {
            task.logs = [...task.logs, line];
            onUpdate?.call(task);
          },
        );
      } else if (source.endsWith('.pak')) {
        await _toolService.pakExtract(
          task.sourcePath,
          task.outputPath,
          onLog: (line) {
            task.logs = [...task.logs, line];
            onUpdate?.call(task);
          },
        );
      } else {
        throw UnsupportedError('不支持的文件类型: ${task.sourcePath}');
      }

      task.status = ExtractStatus.success;
      task.progress = 1.0;
      task.message = '解包完成';
    } catch (e) {
      task.status = ExtractStatus.failed;
      task.message = '解包失败: $e';
      task.logs = [...task.logs, 'ERROR: $e'];
    }

    onUpdate?.call(task);
    return task;
  }
}
