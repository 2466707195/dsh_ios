import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversation_provider.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convState = ref.watch(conversationProvider);

    return convState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('历史对话')),
        body: Center(child: Text('加载失败: $err')),
      ),
      data: (state) => Scaffold(
        appBar: AppBar(
          title: const Text('历史对话'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '新建对话',
              onPressed: () {
                ref.read(conversationProvider.notifier).newConversation();
              },
            ),
          ],
        ),
        body: state.conversations.isEmpty
            ? const Center(
                child: Text('暂无历史对话'),
              )
            : ListView.separated(
                itemCount: state.conversations.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (context, index) {
                  final conv = state.conversations[index];
                  final isCurrent = conv.id == state.currentId;
                  final lastMsg = conv.messages.isNotEmpty
                      ? conv.messages.last.content
                      : '';
                  final preview = lastMsg.length > 60
                      ? '${lastMsg.substring(0, 60)}…'
                      : lastMsg;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    leading: Icon(
                      Icons.chat_bubble_outline,
                      color: isCurrent
                          ? const Color(0xFF4A90D9)
                          : Colors.grey.shade400,
                    ),
                    title: Text(
                      conv.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      preview.isEmpty ? '空对话' : preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13),
                    ),
                    trailing: Text(
                      _formatTime(conv.updatedAt),
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                    ),
                    onTap: () {
                      ref
                          .read(conversationProvider.notifier)
                          .selectConversation(conv.id);
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      // 切回对话 Tab（通过重建 MainTabScreen 状态，简单做法：
                      // 这里仅选中，用户手动点底部 Tab）
                    },
                    onLongPress: () {
                      _showDeleteDialog(context, ref, conv.id, conv.title);
                    },
                  );
                },
              ),
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定删除「$title」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(conversationProvider.notifier).deleteConversation(id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.month}/${time.day}';
  }
}
