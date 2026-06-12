import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/aes_key_candidate.dart';

class AesKeyPickerDialog extends StatelessWidget {
  const AesKeyPickerDialog({super.key, required this.candidates});

  final List<AesKeyCandidate> candidates;

  static Future<AesKeyCandidate?> show(
    BuildContext context,
    List<AesKeyCandidate> candidates,
  ) {
    return showDialog<AesKeyCandidate>(
      context: context,
      builder: (_) => AesKeyPickerDialog(candidates: candidates),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择 AES 密钥'),
      content: SizedBox(
        width: 520,
        child: candidates.isEmpty
            ? const Text('未找到可用密钥。\n\n请确认游戏目录正确，并尝试启动 AION2 后再扫描（exe 有加密保护，需从内存读取）。')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: candidates.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = candidates[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.verified ? Icons.verified : Icons.vpn_key_outlined,
                      color: item.verified ? Aion2Theme.successGreen : Aion2Theme.textSecondary,
                      size: 20,
                    ),
                    title: Text(
                      item.displayName,
                      style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                    ),
                    subtitle: Text(
                      '${item.source}${item.verified ? ' · 已通过 repak/retoc 验证' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
