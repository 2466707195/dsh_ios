import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversation_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final convState = ref.watch(conversationProvider);
    final settings = ref.watch(settingsProvider);

    return convState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('加载失败: $err')),
      ),
      data: (state) {
        // 监听新消息自动滚动
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        final conv = state.current;
        final isConfigured = settings.value?.isConfigured ?? false;

        return Scaffold(
          appBar: AppBar(
            title: Text(conv?.title ?? 'DSH'),
            actions: [
              if (!isConfigured)
                IconButton(
                  icon: const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange),
                  onPressed: () {
                    // 跳转到设置 Tab（简单做法：提示用户）
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('请先在「设置」页配置 API Key'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              if (state.isGenerating)
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined),
                  tooltip: '停止',
                  onPressed: () =>
                      ref.read(conversationProvider.notifier).stopGenerating(),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: (conv == null || conv.messages.isEmpty)
                    ? _EmptyState(isConfigured: isConfigured)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: conv.messages.length,
                        itemBuilder: (context, index) {
                          final msg = conv.messages[index];
                          return MessageBubble(
                            message: msg,
                            key: ValueKey(msg.id),
                          );
                        },
                      ),
              ),
              if (state.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: Colors.red.shade50,
                  child: Text(
                    state.error!,
                    style: TextStyle(
                        color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
              ChatInputBar(
                isGenerating: state.isGenerating,
                onSend: (text) {
                  ref.read(conversationProvider.notifier).sendMessage(text);
                },
                onStop: () =>
                    ref.read(conversationProvider.notifier).stopGenerating(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isConfigured;

  const _EmptyState({required this.isConfigured});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            isConfigured ? '开始新对话' : '请先配置 API Key',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          if (!isConfigured) ...[
            const SizedBox(height: 8),
            Text(
              '前往「设置」页填入 DeepSeek API Key',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}
