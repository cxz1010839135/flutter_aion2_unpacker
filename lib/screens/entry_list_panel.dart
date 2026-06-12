import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/container_file.dart';
import '../models/extract_task.dart';
import '../providers/app_state.dart';

class EntryListPanel extends StatelessWidget {
  const EntryListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.selectedContainer == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 48, color: Aion2Theme.textSecondary),
            SizedBox(height: 12),
            Text('选择一个容器文件查看内容', style: TextStyle(color: Aion2Theme.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context, state),
        if (state.currentTask != null) _buildTaskProgress(state.currentTask!),
        Expanded(child: _buildEntryList(state)),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, AppState state) {
    final container = state.selectedContainer!;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _typeBadge(container.type),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              container.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索文件...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
              onChanged: state.setSearchQuery,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(ContainerType type) {
    final (label, color) = switch (type) {
      ContainerType.pak => ('PAK', Aion2Theme.gold),
      ContainerType.utoc => ('UTOC', Aion2Theme.accentPurple),
      ContainerType.ucas => ('UCAS', Colors.blueGrey),
      ContainerType.unknown => ('?', Aion2Theme.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTaskProgress(ExtractTask task) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Aion2Theme.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Aion2Theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusIcon(task.status),
              const SizedBox(width: 8),
              Expanded(child: Text(task.message, style: const TextStyle(fontSize: 12))),
            ],
          ),
          if (task.logs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              height: 80,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Aion2Theme.darkBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: Text(
                  task.logs.takeLast(20).join('\n'),
                  style: const TextStyle(fontSize: 10, fontFamily: 'Consolas', color: Aion2Theme.textSecondary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusIcon(ExtractStatus status) {
    return switch (status) {
      ExtractStatus.running => const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Aion2Theme.gold),
        ),
      ExtractStatus.success => const Icon(Icons.check_circle, color: Aion2Theme.successGreen, size: 18),
      ExtractStatus.failed => const Icon(Icons.error, color: Aion2Theme.errorRed, size: 18),
      _ => const Icon(Icons.hourglass_empty, size: 18, color: Aion2Theme.textSecondary),
    };
  }

  Widget _buildEntryList(AppState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator(color: Aion2Theme.gold));
    }

    final container = state.selectedContainer!;

    if (container.type == ContainerType.utoc) {
      return _buildUtocList(state);
    }

    if (container.type == ContainerType.pak) {
      return _buildPakList(state: state);
    }

    return Center(
      child: Text(
        state.statusMessage,
        style: const TextStyle(color: Aion2Theme.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPakList({required AppState state}) {
    if (state.pakEntries.isEmpty) {
      return Center(
        child: Text(state.statusMessage, style: const TextStyle(color: Aion2Theme.textSecondary)),
      );
    }

    return ListView.builder(
      itemCount: state.pakEntries.length,
      itemBuilder: (ctx, i) {
        final entry = state.pakEntries[i];
        return ListTile(
          dense: true,
          leading: Icon(
            _fileIcon(entry.filename),
            size: 18,
            color: Aion2Theme.textSecondary,
          ),
          title: Text(entry.filename, style: const TextStyle(fontSize: 12)),
          subtitle: Text(
            '${entry.sizeFormatted}${entry.isEncrypted ? " · 加密" : ""}${entry.isCompressed ? " · 压缩" : ""}',
            style: const TextStyle(fontSize: 10),
          ),
          trailing: entry.isEncrypted || entry.isCompressed
              ? const Icon(Icons.lock, size: 14, color: Aion2Theme.textSecondary)
              : IconButton(
                  icon: const Icon(Icons.download, size: 16),
                  onPressed: () => state.extractPakEntry(entry),
                  tooltip: '提取',
                ),
        );
      },
    );
  }

  Widget _buildUtocList(AppState state) {
    if (state.utocEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.statusMessage,
            style: const TextStyle(color: Aion2Theme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: state.utocEntries.length,
      itemBuilder: (ctx, i) {
        final entry = state.utocEntries[i];
        return ListTile(
          dense: true,
          leading: Icon(_fileIcon(entry), size: 18, color: Aion2Theme.textSecondary),
          title: Text(entry, style: const TextStyle(fontSize: 12)),
        );
      },
    );
  }

  IconData _fileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.uasset') || lower.endsWith('.uexp')) return Icons.view_in_ar;
    if (lower.endsWith('.dat') || lower.endsWith('.txt')) return Icons.text_snippet;
    if (lower.endsWith('.png') || lower.endsWith('.jpg')) return Icons.image;
    if (lower.endsWith('.wav') || lower.endsWith('.wem')) return Icons.audiotrack;
    return Icons.insert_drive_file;
  }
}

extension _ListExt<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}
