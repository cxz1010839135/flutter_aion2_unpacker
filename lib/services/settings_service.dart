import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyGamePath = 'game_path';
  static const _keyOutputPath = 'output_path';
  static const _keyRetocPath = 'retoc_path';
  static const _keyRepakPath = 'repak_path';
  static const _keyUnrealPakPath = 'unrealpak_path';
  static const _keyAesKey = 'aes_key';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? get gamePath => _prefs?.getString(_keyGamePath);
  set gamePath(String? v) => _setOrRemove(_keyGamePath, v);

  String? get outputPath => _prefs?.getString(_keyOutputPath);
  set outputPath(String? v) => _setOrRemove(_keyOutputPath, v);

  String? get retocPath => _prefs?.getString(_keyRetocPath);
  set retocPath(String? v) => _setOrRemove(_keyRetocPath, v);

  String? get repakPath => _prefs?.getString(_keyRepakPath);
  set repakPath(String? v) => _setOrRemove(_keyRepakPath, v);

  String? get unrealPakPath => _prefs?.getString(_keyUnrealPakPath);
  set unrealPakPath(String? v) => _setOrRemove(_keyUnrealPakPath, v);

  String? get aesKey => _prefs?.getString(_keyAesKey);
  set aesKey(String? v) => _setOrRemove(_keyAesKey, v);

  void _setOrRemove(String key, String? value) {
    if (value == null || value.isEmpty) {
      _prefs?.remove(key);
    } else {
      _prefs?.setString(key, value);
    }
  }
}
