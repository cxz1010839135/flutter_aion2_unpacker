import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/app_state.dart';
import 'container_list_panel.dart';
import 'entry_list_panel.dart';
import 'settings_panel.dart';
import 'status_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNav = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildContent()),
                const StatusBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Aion2Theme.cardBg,
        border: Border(right: BorderSide(color: Aion2Theme.borderColor)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildLogo(),
          const SizedBox(height: 32),
          _navItem(0, Icons.folder_open, '资源浏览'),
          _navItem(1, Icons.settings, '设置'),
          const Spacer(),
          _buildOfficialLink(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Aion2Theme.gold.withValues(alpha: 0.8),
                Aion2Theme.accentPurple,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shield, color: Aion2Theme.darkBg, size: 36),
        ),
        const SizedBox(height: 12),
        const Text(
          'AION2',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Aion2Theme.gold,
            letterSpacing: 3,
          ),
        ),
        Text(
          Aion2Constants.engineVersion,
          style: TextStyle(
            fontSize: 11,
            color: Aion2Theme.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _selectedNav == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? Aion2Theme.gold.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _selectedNav = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: selected ? Aion2Theme.gold : Aion2Theme.textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Aion2Theme.gold : Aion2Theme.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialLink(BuildContext context) {
    return TextButton.icon(
      onPressed: () => launchUrl(Uri.parse(Aion2Constants.officialUrl)),
      icon: const Icon(Icons.language, size: 16),
      label: const Text('官方网站', style: TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(foregroundColor: Aion2Theme.textSecondary),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Aion2Theme.cardBg,
        border: Border(bottom: BorderSide(color: Aion2Theme.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedNav == 0 ? '资源浏览' : '设置',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                if (state.gamePath != null)
                  Text(
                    state.gamePath!,
                    style: const TextStyle(fontSize: 11, color: Aion2Theme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (_selectedNav == 0) ...[
            OutlinedButton.icon(
              onPressed: state.loading ? null : () => state.scanContainers(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重新扫描'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: state.selectedContainer != null && state.outputPath != null
                  ? () => _confirmExtract(context, state)
                  : null,
              icon: const Icon(Icons.unarchive, size: 18),
              label: const Text('解包选中'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedNav == 1) return const SettingsPanel();
    return const Row(
      children: [
        Expanded(flex: 2, child: ContainerListPanel()),
        VerticalDivider(width: 1, color: Aion2Theme.borderColor),
        Expanded(flex: 3, child: EntryListPanel()),
      ],
    );
  }

  Future<void> _confirmExtract(BuildContext context, AppState state) async {
    final container = state.selectedContainer!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认解包'),
        content: Text('将解包 "${container.name}" 到:\n${state.outputPath}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('开始解包')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await state.extractContainer();
    }
  }
}
