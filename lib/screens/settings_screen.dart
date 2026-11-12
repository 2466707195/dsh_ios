import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../services/deepseek_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  bool _obscureKey = true;
  bool _testing = false;
  String? _testResult;

  static const _models = [
    'deepseek-flash',
    'deepseek-v4-pro',
    'deepseek-chat',
    'deepseek-reasoner',
  ];

  @override
  void initState() {
    super.initState();
    // 等首个帧后回填当前设置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(settingsProvider).value;
      if (s != null) {
        _apiKeyController.text = s.apiKey;
        _baseUrlController.text = s.baseUrl;
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = ref.read(settingsProvider).value ?? const AppSettings();
    final updated = current.copyWith(
      apiKey: _apiKeyController.text.trim(),
      baseUrl:
          _baseUrlController.text.trim().isEmpty
              ? AppSettings.defaultBaseUrl
              : _baseUrlController.text.trim(),
    );
    await ref.read(settingsProvider.notifier).updateSettings(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已保存'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final current = ref.read(settingsProvider).value ?? const AppSettings();
    final apiKey = _apiKeyController.text.trim();
    final baseUrl = _baseUrlController.text.trim().isEmpty
        ? AppSettings.defaultBaseUrl
        : _baseUrlController.text.trim();
    final model = current.model;

    final service = DeepSeekService();
    try {
      final ok = await service.testConnection(
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model,
      );
      setState(() {
        _testResult = ok ? '✅ 连接成功' : '❌ 连接失败（HTTP 非 200）';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ 连接失败: $e';
      });
    } finally {
      service.dispose();
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final currentModel = settingsAsync.value?.model ?? AppSettings.defaultModel;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // API Key
            _SectionCard(
              title: 'API 配置',
              children: [
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    labelText: 'DeepSeek API Key',
                    hintText: 'sk-...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: AppSettings.defaultBaseUrl,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _models.contains(currentModel)
                      ? currentModel
                      : AppSettings.defaultModel,
                  decoration: const InputDecoration(
                    labelText: '模型',
                    border: OutlineInputBorder(),
                  ),
                  items: _models
                      .map((m) =>
                          DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateSettings(settings.copyWith(model: v));
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('保存'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testing ? null : _testConnection,
                        child: _testing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('测试连接'),
                      ),
                    ),
                  ],
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 12),
                  Text(_testResult!,
                      style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            // 说明
            _SectionCard(
              title: '关于',
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline),
                  title: Text('DSH iOS'),
                  subtitle: Text('DeepSeek Harness 复刻 iOS 客户端\nFlutter 版本'),
                  isThreeLine: true,
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.link),
                  title: Text('原项目'),
                  subtitle: Text('github.com/ccch1mneyyy/dsh-go'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
