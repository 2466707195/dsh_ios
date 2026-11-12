import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import 'storage_provider.dart';

/// 设置状态 Notifier
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final storage = ref.read(storageProvider);
    return await storage.loadSettings();
  }

  Future<void> updateSettings(AppSettings settings) async {
    final storage = ref.read(storageProvider);
    await storage.saveSettings(settings);
    state = AsyncData(settings);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
