import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/deepseek_service.dart';
import 'settings_provider.dart';
import 'storage_provider.dart';

/// 会话列表状态
class ConversationListState {
  final List<Conversation> conversations;
  final String? currentId;
  final bool isGenerating;
  final String? error;

  const ConversationListState({
    this.conversations = const [],
    this.currentId,
    this.isGenerating = false,
    this.error,
  });

  Conversation? get current {
    if (currentId == null) return null;
    try {
      return conversations.firstWhere((c) => c.id == currentId);
    } catch (_) {
      return null;
    }
  }

  ConversationListState copyWith({
    List<Conversation>? conversations,
    String? currentId,
    bool? isGenerating,
    String? error,
    bool clearError = false,
    bool clearCurrent = false,
  }) =>
      ConversationListState(
        conversations: conversations ?? this.conversations,
        currentId: clearCurrent ? null : (currentId ?? this.currentId),
        isGenerating: isGenerating ?? this.isGenerating,
        error: clearError ? null : (error ?? this.error),
      );
}

class ConversationNotifier extends AsyncNotifier<ConversationListState> {
  final _uuid = const Uuid();
  final _service = DeepSeekService();
  StreamSubscription? _sub;

  @override
  Future<ConversationListState> build() async {
    final storage = ref.read(storageProvider);
    final convs = await storage.loadConversations();
    final currentId = await storage.loadCurrentConversationId();
    // 如果没有会话，自动创建一个
    if (convs.isEmpty) {
      final newConv = _createConversation();
      convs.add(newConv);
      await storage.saveConversations(convs);
      await storage.saveCurrentConversationId(newConv.id);
      return ConversationListState(
          conversations: convs, currentId: newConv.id);
    }
    return ConversationListState(
      conversations: convs,
      currentId: currentId ?? convs.first.id,
    );
  }

  Conversation _createConversation() {
    final now = DateTime.now();
    return Conversation(
      id: _uuid.v4(),
      title: '新对话',
      createdAt: now,
      updatedAt: now,
    );
  }

  void newConversation() {
    final stateVal = state.value;
    if (stateVal == null) return;
    final conv = _createConversation();
    final updated = [conv, ...stateVal.conversations];
    state = AsyncData(stateVal.copyWith(
      conversations: updated,
      currentId: conv.id,
    ));
    _persist(updated);
    ref.read(storageProvider).saveCurrentConversationId(conv.id);
  }

  void selectConversation(String id) {
    final stateVal = state.value;
    if (stateVal == null) return;
    state = AsyncData(stateVal.copyWith(currentId: id));
    ref.read(storageProvider).saveCurrentConversationId(id);
  }

  void deleteConversation(String id) {
    final stateVal = state.value;
    if (stateVal == null) return;
    var updated =
        stateVal.conversations.where((c) => c.id != id).toList();
    if (updated.isEmpty) {
      final conv = _createConversation();
      updated = [conv];
      state = AsyncData(stateVal.copyWith(
        conversations: updated,
        currentId: conv.id,
      ));
    } else {
      state = AsyncData(stateVal.copyWith(conversations: updated));
    }
    _persist(updated);
    ref.read(storageProvider)
        .saveCurrentConversationId(state.value?.currentId);
  }

  Future<void> sendMessage(String text) async {
    final stateVal = state.value;
    if (stateVal == null || text.trim().isEmpty) return;

    final settings = ref.read(settingsProvider).value;
    if (settings == null || !settings.isConfigured) {
      state = AsyncData(stateVal.copyWith(
          error: '请先在设置中配置 API Key'));
      return;
    }

    final currentConv = stateVal.current;
    if (currentConv == null) return;

    // 添加用户消息
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now(),
    );

    // 添加占位 assistant 消息
    final assistantMsg = ChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content: '',
      createdAt: DateTime.now(),
      isStreaming: true,
    );

    // 更新会话
    final updatedMessages = [
      ...currentConv.messages,
      userMsg,
      assistantMsg,
    ];
    final updatedConv = Conversation(
      id: currentConv.id,
      title: currentConv.messages.isEmpty ? text.trim() : currentConv.title,
      messages: updatedMessages,
      createdAt: currentConv.createdAt,
      updatedAt: DateTime.now(),
    );

    final updatedConvs = stateVal.conversations
        .map((c) => c.id == currentConv.id ? updatedConv : c)
        .toList();

    state = AsyncData(stateVal.copyWith(
      conversations: updatedConvs,
      isGenerating: true,
      clearError: true,
    ));
    _persist(updatedConvs);

    // 构建历史消息（不含占位 assistant）
    final history = updatedMessages
        .where((m) => m.id != assistantMsg.id)
        .toList();

    try {
      // 更新 assistant 消息内容的回调
      void updateAssistant(String content, {String? reasoning}) {
        final sv = state.value;
        if (sv == null) return;
        final conv = sv.current;
        if (conv == null) return;
        final msgs = conv.messages.map((m) {
          if (m.id == assistantMsg.id) {
            return m.copyWith(
              content: content,
              reasoningContent: reasoning,
            );
          }
          return m;
        }).toList();

        final uc = Conversation(
          id: conv.id,
          title: conv.title,
          messages: msgs,
          createdAt: conv.createdAt,
          updatedAt: DateTime.now(),
        );
        final ucs = sv.conversations
            .map((c) => c.id == conv.id ? uc : c)
            .toList();
        state = AsyncData(sv.copyWith(conversations: ucs));
      }

      String contentAcc = '';
      String reasoningAcc = '';

      final result = await _service.streamChat(
        apiKey: settings.apiKey,
        baseUrl: settings.baseUrl,
        model: settings.model,
        history: history,
        onDelta: (delta) {
          contentAcc += delta;
          updateAssistant(contentAcc,
              reasoning: reasoningAcc.isEmpty ? null : reasoningAcc);
        },
        onReasoning: (delta) {
          reasoningAcc += delta;
          updateAssistant(contentAcc, reasoning: reasoningAcc);
        },
      );

      // 最终更新：标记流结束
      final sv = state.value;
      if (sv != null) {
        final conv = sv.current;
        if (conv != null) {
          final msgs = conv.messages.map((m) {
            if (m.id == assistantMsg.id) {
              return ChatMessage(
                id: m.id,
                role: m.role,
                content: result.content,
                reasoningContent: result.reasoningContent,
                createdAt: m.createdAt,
                isStreaming: false,
              );
            }
            return m;
          }).toList();
          final uc = Conversation(
            id: conv.id,
            title: conv.title,
            messages: msgs,
            createdAt: conv.createdAt,
            updatedAt: DateTime.now(),
          );
          final ucs = sv.conversations
              .map((c) => c.id == conv.id ? uc : c)
              .toList();
          state = AsyncData(sv.copyWith(conversations: ucs, isGenerating: false));
          _persist(ucs);
        }
      }
    } catch (e) {
      // 回填错误信息到 assistant 消息
      final sv = state.value;
      if (sv != null) {
        final conv = sv.current;
        if (conv != null) {
          final msgs = conv.messages.map((m) {
            if (m.id == assistantMsg.id) {
              return m.copyWith(
                content: '❌ 请求失败: ${e.toString()}',
                isStreaming: false,
              );
            }
            return m;
          }).toList();
          final uc = Conversation(
            id: conv.id,
            title: conv.title,
            messages: msgs,
            createdAt: conv.createdAt,
            updatedAt: DateTime.now(),
          );
          final ucs = sv.conversations
              .map((c) => c.id == conv.id ? uc : c)
              .toList();
          state = AsyncData(sv.copyWith(
              conversations: ucs,
              isGenerating: false,
              error: e.toString()));
          _persist(ucs);
        }
      }
    }
  }

  void stopGenerating() {
    _sub?.cancel();
    final sv = state.value;
    if (sv != null) {
      state = AsyncData(sv.copyWith(isGenerating: false));
    }
  }

  void clearError() {
    final sv = state.value;
    if (sv != null) {
      state = AsyncData(sv.copyWith(clearError: true));
    }
  }

  void _persist(List<Conversation> convs) {
    ref.read(storageProvider).saveConversations(convs);
  }
}

final conversationProvider =
    AsyncNotifierProvider<ConversationNotifier, ConversationListState>(
        ConversationNotifier.new);
