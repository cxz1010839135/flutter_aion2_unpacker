import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/aes_key_candidate.dart';
import '../models/container_file.dart';
import '../models/extract_task.dart';
import '../models/pak_entry.dart';
import '../services/aes_key_finder.dart';
import '../services/container_scanner.dart';
import '../services/external_tool_service.dart';
import '../services/pak_parser.dart';
import '../services/settings_service.dart';
import '../services/tool_paths_loader.dart';

class AppState extends ChangeNotifier {
  AppState(this._settings);

  final SettingsService _settings;
  late final ExternalToolService _toolService;
  late final ExtractorService _extractor;

  String? _gamePath;
  String? _outputPath;
  List<ContainerFile> _containers = [];
  ContainerFile? _selectedContainer;
  List<PakEntry> _pakEntries = [];
  List<String> _utocEntries = [];
  bool _loading = false;
  String _statusMessage = '就绪';
  ExtractTask? _currentTask;
  String _searchQuery = '';

  String? get gamePath => _gamePath;
  String? get outputPath => _outputPath;
  List<ContainerFile> get containers => _containers;
  ContainerFile? get selectedContainer => _selectedContainer;
  List<PakEntry> get pakEntries => _filteredPakEntries();
  List<String> get utocEntries => _filteredUtocEntries();
  bool get loading => _loading;
  String get statusMessage => _statusMessage;
  ExtractTask? get currentTask => _currentTask;
  String get searchQuery => _searchQuery;
  ExternalToolService get toolService => _toolService;
  SettingsService get settings => _settings;

  String? get paksDir =>
      _gamePath != null ? ContainerScanner.paksPath(_gamePath!) : null;

  Future<void> _loadToolPathsFromConfig() async {
    final tools = await ToolPathsLoader.load();
    if (tools == null) return;

    var changed = false;
    if (tools.retocPath != null &&
        tools.retocPath!.isNotEmpty &&
        File(tools.retocPath!).existsSync() &&
        _settings.retocPath != tools.retocPath) {
      _settings.retocPath = tools.retocPath;
      changed = true;
    }
    if (tools.repakPath != null &&
        tools.repakPath!.isNotEmpty &&
        File(tools.repakPath!).existsSync() &&
        _settings.repakPath != tools.repakPath) {
      _settings.repakPath = tools.repakPath;
      changed = true;
    }
    if (tools.unrealPakPath != null &&
        tools.unrealPakPath!.isNotEmpty &&
        File(tools.unrealPakPath!).existsSync() &&
        _settings.unrealPakPath != tools.unrealPakPath) {
      _settings.unrealPakPath = tools.unrealPakPath;
      changed = true;
    }
    if (changed) {
      _toolService.retocPath = _settings.retocPath;
      _toolService.repakPath = _settings.repakPath;
      _toolService.unrealPakPath = _settings.unrealPakPath;
    }
  }

  /// 重新加载 install_tools.ps1 写入的工具路径
  Future<void> reloadToolPaths() async {
    await _loadToolPathsFromConfig();
    notifyListeners();
  }

  Future<void> init() async {
    await _settings.init();
    _gamePath = _settings.gamePath;
    _outputPath = _settings.outputPath;

    _toolService = ExternalToolService(
      retocPath: _settings.retocPath,
      repakPath: _settings.repakPath,
      unrealPakPath: _settings.unrealPakPath,
      aesKey: _settings.aesKey,
    );
    _extractor = ExtractorService(_toolService);

    await _loadToolPathsFromConfig();

    if (_gamePath == null) {
      _gamePath = await ContainerScanner.detectGamePath();
      if (_gamePath != null) {
        _settings.gamePath = _gamePath;
      }
    }

    if (_gamePath != null) {
      await scanContainers();
    }
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> setGamePath(String path) async {
    _gamePath = path;
    _settings.gamePath = path;
    await scanContainers();
  }

  void setOutputPath(String path) {
    _outputPath = path;
    _settings.outputPath = path;
    notifyListeners();
  }

  void updateToolSettings({
    String? retocPath,
    String? repakPath,
    String? unrealPakPath,
    String? aesKey,
  }) {
    if (retocPath != null) _settings.retocPath = retocPath;
    if (repakPath != null) _settings.repakPath = repakPath;
    if (unrealPakPath != null) _settings.unrealPakPath = unrealPakPath;
    if (aesKey != null) _settings.aesKey = aesKey;

    _toolService.retocPath = _settings.retocPath;
    _toolService.repakPath = _settings.repakPath;
    _toolService.unrealPakPath = _settings.unrealPakPath;
    _toolService.aesKey = _settings.aesKey;
    notifyListeners();
  }

  Future<List<AesKeyCandidate>> findAesKeys() {
    return AesKeyFinder.find(
      gamePath: _gamePath,
      repakPath: _settings.repakPath,
      retocPath: _settings.retocPath,
    );
  }

  Future<void> scanContainers() async {
    if (_gamePath == null) return;
    _loading = true;
    _statusMessage = '正在扫描资源文件...';
    notifyListeners();

    try {
      final paksDir = ContainerScanner.paksPath(_gamePath!);
      _containers = await ContainerScanner.scanDirectory(paksDir);
      _statusMessage = '找到 ${_containers.length} 个容器文件';
    } catch (e) {
      _statusMessage = '扫描失败: $e';
      _containers = [];
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> selectContainer(ContainerFile container) async {
    _selectedContainer = container;
    _pakEntries = [];
    _utocEntries = [];
    _loading = true;
    _statusMessage = '正在读取 ${container.name}...';
    notifyListeners();

    try {
      switch (container.type) {
        case ContainerType.pak:
          final parser = PakParser(container.path);
          _pakEntries = await parser.readIndex();
          _statusMessage = '共 ${_pakEntries.length} 个文件';
        case ContainerType.utoc:
          if (_toolService.hasRetoc) {
            _utocEntries = await _toolService.retocList(container.path);
            _statusMessage = '共 ${_utocEntries.length} 个条目';
          } else {
            _statusMessage = '需要配置 retoc.exe 才能浏览 .utoc 内容';
          }
        case ContainerType.ucas:
          _statusMessage = '.ucas 是数据块文件，请选择对应的 .utoc 文件';
        case ContainerType.unknown:
          _statusMessage = '未知文件类型';
      }
    } catch (e) {
      _statusMessage = '读取失败: $e';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> extractContainer() async {
    final container = _selectedContainer;
    if (container == null || _outputPath == null) return;

    final outputDir =
        '$_outputPath/${container.name.replaceAll(RegExp(r'\.[^.]+$'), '')}';

    _currentTask = ExtractTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sourcePath: container.path,
      outputPath: outputDir,
    );
    notifyListeners();

    await _extractor.runTask(_currentTask!, onUpdate: (_) => notifyListeners());
    notifyListeners();
  }

  Future<void> extractPakEntry(PakEntry entry) async {
    final container = _selectedContainer;
    if (container == null || _outputPath == null) return;

    _loading = true;
    _statusMessage = '正在提取 ${entry.filename}...';
    notifyListeners();

    try {
      final parser = PakParser(container.path);
      await parser.extractEntry(entry, _outputPath!);
      _statusMessage = '已提取: ${entry.filename}';
    } catch (e) {
      _statusMessage = '提取失败: $e';
    }

    _loading = false;
    notifyListeners();
  }

  List<PakEntry> _filteredPakEntries() {
    if (_searchQuery.isEmpty) return _pakEntries;
    final q = _searchQuery.toLowerCase();
    return _pakEntries.where((e) => e.filename.toLowerCase().contains(q)).toList();
  }

  List<String> _filteredUtocEntries() {
    if (_searchQuery.isEmpty) return _utocEntries;
    final q = _searchQuery.toLowerCase();
    return _utocEntries.where((e) => e.toLowerCase().contains(q)).toList();
  }
}
