import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/conversation.dart';
import '../models/app_settings.dart';

/// 本地持久化：会话存 SharedPreferences，apiKey 存 Keychain（flutter_secure_storage）
class StorageService {
  static const _convsKey = 'dsh_conversations_v1';
  static const _currentConvKey = 'dsh_current_conversation_v1';
  static const _secureKey = 'dsh_api_key';
  static const _baseUrlKey = 'dsh_base_url';
  static const _modelKey = 'dsh_model';

  Future<List<Conversation>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_convsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveConversations(List<Conversation> convs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _convsKey,
      jsonEncode(convs.map((c) => c.toJson()).toList()),
    );
  }

  Future<String?> loadCurrentConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentConvKey);
  }

  Future<void> saveCurrentConversationId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_currentConvKey);
    } else {
      await prefs.setString(_currentConvKey, id);
    }
  }

  Future<AppSettings> loadSettings() async {
    const secure = FlutterSecureStorage();
    final apiKey = await secure.read(key: _secureKey) ?? '';
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      apiKey: apiKey,
      baseUrl: prefs.getString(_baseUrlKey) ?? AppSettings.defaultBaseUrl,
      model: prefs.getString(_modelKey) ?? AppSettings.defaultModel,
    );
  }

  Future<void> saveSettings(AppSettings s) async {
    const secure = FlutterSecureStorage();
    await secure.write(key: _secureKey, value: s.apiKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, s.baseUrl);
    await prefs.setString(_modelKey, s.model);
  }
}
