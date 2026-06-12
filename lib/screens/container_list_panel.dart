import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/container_file.dart';
import '../providers/app_state.dart';
import '../services/container_scanner.dart';

class ContainerListPanel extends StatelessWidget {
  const ContainerListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.gamePath == null) {
      return _buildNoGamePath(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStats(state),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: '搜索容器文件...',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
            onChanged: (v) {
              // container-level search handled locally
            },
          ),
        ),
        Expanded(
          child: state.containers.isEmpty
              ? _buildEmpty(state)
              : _buildList(context, state),
        ),
      ],
    );
  }

  Widget _buildNoGamePath(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_off, size: 48, color: Aion2Theme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('未找到 AION2 游戏目录', style: TextStyle(color: Aion2Theme.textSecondary)),
          const SizedBox(height: 8),
          const Text(
            '请在设置中手动指定游戏路径',
            style: TextStyle(fontSize: 12, color: Aion2Theme.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await FilePicker.platform.getDirectoryPath(
                dialogTitle: '选择 AION2 游戏目录',
              );
              if (result != null && context.mounted) {
                await context.read<AppState>().setGamePath(result);
              }
            },
            icon: const Icon(Icons.folder_open),
            label: const Text('选择游戏目录'),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(AppState state) {
    final groups = ContainerScanner.groupByType(state.containers);
    final totalSize = ContainerScanner.totalSize(state.containers);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Aion2Theme.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Aion2Theme.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip('PAK', groups[ContainerType.pak] ?? 0, Icons.inventory_2),
          _statChip('UTOC', groups[ContainerType.utoc] ?? 0, Icons.description),
          _statChip('UCAS', groups[ContainerType.ucas] ?? 0, Icons.storage),
          _statChip(
            '总计',
            state.containers.length,
            Icons.data_usage,
            subLabel: ContainerFile.formatSize(totalSize),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, IconData icon, {String? subLabel}) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Aion2Theme.gold),
        const SizedBox(height: 4),
        Text(
          subLabel ?? '$count',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Aion2Theme.textSecondary)),
      ],
    );
  }

  Widget _buildEmpty(AppState state) {
    return Center(
      child: state.loading
          ? const CircularProgressIndicator(color: Aion2Theme.gold)
          : const Text('未找到容器文件', style: TextStyle(color: Aion2Theme.textSecondary)),
    );
  }

  Widget _buildList(BuildContext context, AppState state) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: state.containers.length,
      itemBuilder: (ctx, i) {
        final container = state.containers[i];
        final selected = state.selectedContainer?.path == container.path;
        return _ContainerTile(
          container: container,
          selected: selected,
          onTap: () => state.selectContainer(container),
        );
      },
    );
  }
}

class _ContainerTile extends StatelessWidget {
  const _ContainerTile({
    required this.container,
    required this.selected,
    required this.onTap,
  });

  final ContainerFile container;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (container.type) {
      ContainerType.pak => Aion2Theme.gold,
      ContainerType.utoc => Aion2Theme.accentPurple,
      ContainerType.ucas => Colors.blueGrey,
      ContainerType.unknown => Aion2Theme.textSecondary,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? Aion2Theme.gold.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        container.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? Aion2Theme.gold : Aion2Theme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (container.relativePath.isNotEmpty)
                        Text(
                          container.relativePath,
                          style: const TextStyle(fontSize: 10, color: Aion2Theme.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Text(
                  container.sizeFormatted,
                  style: const TextStyle(fontSize: 10, color: Aion2Theme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
