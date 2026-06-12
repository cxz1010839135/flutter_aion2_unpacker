import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../widgets/aes_key_picker_dialog.dart';
import '../providers/app_state.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late TextEditingController _aesKeyController;
  late TextEditingController _retocController;
  late TextEditingController _repakController;
  bool _fetchingAesKey = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppState>().settings;
    _aesKeyController = TextEditingController(text: settings.aesKey ?? '');
    _retocController = TextEditingController(text: settings.retocPath ?? '');
    _repakController = TextEditingController(text: settings.repakPath ?? '');
  }

  @override
  void dispose() {
    _aesKeyController.dispose();
    _retocController.dispose();
    _repakController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('游戏路径'),
          _pathField(
            label: 'AION2 游戏目录',
            value: state.gamePath ?? '未设置',
            onBrowse: () async {
              final result = await FilePicker.platform.getDirectoryPath(
                dialogTitle: '选择 AION2 游戏根目录 (Aion2 文件夹)',
              );
              if (result != null) await state.setGamePath(result);
            },
          ),
          if (state.paksDir != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Paks: ${state.paksDir}',
                style: const TextStyle(fontSize: 11, color: Aion2Theme.textSecondary),
              ),
            ),
          const SizedBox(height: 24),
          _sectionTitle('输出路径'),
          _pathField(
            label: '解包输出目录',
            value: state.outputPath ?? '未设置',
            onBrowse: () async {
              final result = await FilePicker.platform.getDirectoryPath(
                dialogTitle: '选择解包输出目录',
              );
              if (result != null) state.setOutputPath(result);
            },
          ),
          const SizedBox(height: 24),
          _sectionTitle('外部工具'),
          _toolStatus(state),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _runInstallScript(context),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('一键安装依赖'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _refreshToolPaths(state),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新状态'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _exeField(
            label: 'retoc.exe 路径',
            hint: '用于 .utoc/.ucas IoStore 解包',
            controller: _retocController,
            onBrowse: () => _pickExe(_retocController),
          ),
          const SizedBox(height: 12),
          _exeField(
            label: 'repak.exe 路径',
            hint: '用于 .pak 解包 (一键安装到 tools/repak/)',
            controller: _repakController,
            onBrowse: () => _pickExe(_repakController),
          ),
          const SizedBox(height: 24),
          _sectionTitle('加密密钥'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _aesKeyController,
                  decoration: const InputDecoration(
                    labelText: 'AES 密钥 (可选)',
                    hintText: '0x... 格式的十六进制密钥',
                    helperText: 'AION2 资源可能使用 AES 加密，可自动扫描游戏文件或进程内存',
                  ),
                  obscureText: true,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: _fetchingAesKey ? null : () => _autoFetchAesKey(context, state),
                  icon: _fetchingAesKey
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.key, size: 18),
                  label: Text(_fetchingAesKey ? '扫描中...' : '自动获取'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              state.updateToolSettings(
                retocPath: _retocController.text.trim(),
                repakPath: _repakController.text.trim(),
                aesKey: _aesKeyController.text.trim(),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('设置已保存'), duration: Duration(seconds: 2)),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text('保存设置'),
          ),
          const SizedBox(height: 32),
          _sectionTitle('工具下载'),
          _toolLink(
            'retoc - IoStore 解包工具',
            'https://github.com/trumank/retoc/releases',
          ),
          _toolLink(
            'FModel - 资源浏览器 (获取 AES 密钥)',
            'https://fmodel.app/',
          ),
          _toolLink(
            'repak - .pak 解包工具',
            'https://github.com/trumank/repak/releases',
          ),
          const SizedBox(height: 24),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Aion2Theme.gold),
      ),
    );
  }

  Widget _pathField({
    required String label,
    required String value,
    required VoidCallback onBrowse,
  }) {
    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(labelText: label),
            child: Text(value, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onBrowse, child: const Text('浏览')),
      ],
    );
  }

  Widget _exeField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required VoidCallback onBrowse,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label, hintText: hint),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onBrowse, child: const Text('浏览')),
      ],
    );
  }

  Widget _toolStatus(AppState state) {
    return Row(
      children: [
        _statusChip('retoc', state.toolService.hasRetoc),
        const SizedBox(width: 8),
        _statusChip('repak', state.toolService.hasRepak),
      ],
    );
  }

  Widget _statusChip(String name, bool available) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (available ? Aion2Theme.successGreen : Aion2Theme.errorRed).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (available ? Aion2Theme.successGreen : Aion2Theme.errorRed).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: available ? Aion2Theme.successGreen : Aion2Theme.errorRed,
          ),
          const SizedBox(width: 4),
          Text(name, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _toolLink(String title, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(url)),
        child: Row(
          children: [
            const Icon(Icons.open_in_new, size: 14, color: Aion2Theme.gold),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Aion2Theme.gold)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('关于 AION2 资源格式', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'AION2 基于 Unreal Engine 5.3 构建，资源存储在 Content/Paks 目录下，'
              '使用 IoStore 容器格式 (.utoc + .ucas + .pak)。\n\n'
              '典型路径:\n'
              'NCSOFT\\AION2_TW\\Aion2\\Content\\Paks\\\n\n'
              '本地化文本位于:\n'
              'Paks\\L10N\\Text\\en-US\\pakchunk502000-Windows_0_P.pak',
              style: TextStyle(fontSize: 12, color: Aion2Theme.textSecondary.withValues(alpha: 0.9), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _autoFetchAesKey(BuildContext context, AppState state) async {
    setState(() => _fetchingAesKey = true);
    try {
      final keys = await state.findAesKeys();
      if (!context.mounted) return;

      if (keys.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未找到密钥。请先启动 AION2 再试（exe 有加密，需从内存读取）'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final verified = keys.where((k) => k.verified).toList();
      final candidates = verified.isNotEmpty ? verified : keys;

      if (candidates.length == 1) {
        _aesKeyController.text = candidates.first.key;
        state.updateToolSettings(aesKey: candidates.first.key);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              candidates.first.verified ? '已自动填入已验证密钥' : '已填入候选密钥，解包失败请换其他密钥',
            ),
          ),
        );
        return;
      }

      final selected = await AesKeyPickerDialog.show(context, candidates);
      if (!context.mounted || selected == null) return;

      _aesKeyController.text = selected.key;
      state.updateToolSettings(aesKey: selected.key);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密钥已选择并应用')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取密钥失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _fetchingAesKey = false);
    }
  }

  Future<void> _pickExe(TextEditingController controller) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择可执行文件',
      type: FileType.custom,
      allowedExtensions: ['exe'],
    );
    if (result != null && result.files.single.path != null) {
      controller.text = result.files.single.path!;
    }
  }

  Future<void> _runInstallScript(BuildContext context) async {
    final bat = _findInstallScript();
    if (bat == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到 install_tools.bat，请在项目根目录双击运行')),
      );
      return;
    }

    final projectRoot = File(bat).parent.path;
    final ps1 = '$projectRoot${Platform.pathSeparator}scripts${Platform.pathSeparator}install_tools.ps1';

    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1],
        runInShell: true,
        workingDirectory: projectRoot,
      );

      if (!context.mounted) return;
      final state = context.read<AppState>();
      await _refreshToolPaths(state);

      final ok = result.exitCode == 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '依赖安装完成' : '安装过程有警告，请查看输出'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('启动安装脚本失败: $e')),
      );
    }
  }

  String? _findInstallScript() {
    final roots = <String>{
      File(Platform.resolvedExecutable).parent.path,
      Directory.current.path,
    };

    var dir = Directory.current;
    for (var i = 0; i < 6; i++) {
      roots.add(dir.path);
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    for (final root in roots) {
      final bat = File('$root${Platform.pathSeparator}install_tools.bat');
      if (bat.existsSync()) return bat.path;
    }
    return null;
  }

  Future<void> _refreshToolPaths(AppState state) async {
    await state.reloadToolPaths();
    _retocController.text = state.settings.retocPath ?? '';
    _repakController.text = state.settings.repakPath ?? '';
    if (mounted) setState(() {});
  }
}
