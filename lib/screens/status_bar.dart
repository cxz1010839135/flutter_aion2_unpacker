import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/app_state.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Aion2Theme.cardBg,
        border: Border(top: BorderSide(color: Aion2Theme.borderColor)),
      ),
      child: Row(
        children: [
          if (state.loading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Aion2Theme.gold),
              ),
            ),
          Expanded(
            child: Text(
              state.statusMessage,
              style: const TextStyle(fontSize: 11, color: Aion2Theme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${Aion2Constants.appName} v${Aion2Constants.appVersion}',
            style: const TextStyle(fontSize: 10, color: Aion2Theme.textSecondary),
          ),
        ],
      ),
    );
  }
}
