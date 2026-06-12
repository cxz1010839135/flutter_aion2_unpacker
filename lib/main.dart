import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Aion2UnpackerApp());
}

class Aion2UnpackerApp extends StatelessWidget {
  const Aion2UnpackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(SettingsService())..init(),
      child: MaterialApp(
        title: Aion2Constants.appName,
        debugShowCheckedModeBanner: false,
        theme: Aion2Theme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
