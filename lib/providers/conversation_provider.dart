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
    final id = currentId;
    if (id == null) return null;
    for (final c in conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  ConversationListState copyWith({
    List<Conversation>? conversations,
    String? currentId,
    bool? isGenerating,
    String? error,
    bool clearError = false,
  }) =>
      ConversationListState(
        conversations: conversations ?? this.conversations,
        currentId: currentId ?? this.currentId,
        isGenerating: isGenerating ?? this.isGenerating,
        error: clearError ? null : (error ?? this.error),
      );
}

class ConversationNotifier extends AsyncNotifier<ConversationListState> {
  final _uuid = const Uuid();
  final _service = DeepSeekService();
  bool _disposed = false;

  @override
  Future<ConversationListState> build() async {
    final storage = ref.read(storageProvider);
    final convs = await storage.loadConversations();
    final currentId = await storage.loadCurrentConversationId();

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

  void _replaceConversation(List<Conversation> convs, Conversation updated) {
    final newState = convs.map((c) => c.id == updated.id ? updated : c).toList();
    state = AsyncData(state.value!.copyWith(conversations: newState));
    ref.read(storageProvider).saveConversations(newState);
  }

  void newConversation() {
    final stateVal = state.value;
    if (stateVal == null) return;
    final conv = _createConversation();
    final updated = [conv, ...stateVal.conversations];
    state = AsyncData(stateVal.copyWith(
      conversations: updated,
      currentId: conv.id,
      clearError: true,
    ));
    ref.read(storageProvider).saveConversations(updated);
    ref.read(storageProvider).saveCurrentConversationId(conv.id);
  }

  void selectConversation(String id) {
    final stateVal = state.value;
    if (stateVal == null) return;
    state = AsyncData(stateVal.copyWith(currentId: id, clearError: true));
    ref.read(storageProvider).saveCurrentConversationId(id);
  }

  void deleteConversation(String id) {
    final stateVal = state.value;
    if (stateVal == null) return;
    var remaining = stateVal.conversations.where((c) => c.id != id).toList();
    if (remaining.isEmpty) {
      final conv = _createConversation();
      remaining = [conv];
      state = AsyncData(stateVal.copyWith(
        conversations: remaining,
        currentId: conv.id,
      ));
      ref.read(storageProvider).saveCurrentConversationId(conv.id);
    } else {
      final keep = stateVal.currentId == id ? remaining.first.id : stateVal.currentId;
      state = AsyncData(stateVal.copyWith(conversations: remaining, currentId: keep));
      ref.read(storageProvider).saveCurrentConversationId(keep);
    }
    ref.read(storageProvider).saveConversations(remaining);
  }

  Future<void> sendMessage(String text) async {
    final stateVal = state.value;
    if (stateVal == null || text.trim().isEmpty) return;

    final settings = ref.read(settingsProvider).value;
    if (settings == null || !settings.isConfigured) {
      state = AsyncData(stateVal.copyWith(error: '请先在设置中配置 API Key'));
      return;
    }

    final conv0 = stateVal.current;
    if (conv0 == null) return;

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now(),
    );
    final assistantId = _uuid.v4();
    final assistantMsg = ChatMessage(
      id: assistantId,
      role: 'assistant',
      content: '',
      createdAt: DateTime.now(),
      isStreaming: true,
    );

    final withUser = Conversation(
      id: conv0.id,
      title: conv0.messages.isEmpty ? text.trim() : conv0.title,
      messages: [...conv0.messages, userMsg, assistantMsg],
      createdAt: conv0.createdAt,
      updatedAt: DateTime.now(),
    );
    _replaceConversation(stateVal.conversations, withUser);
    state = AsyncData(state.value!.copyWith(isGenerating: true, clearError: true));

    // 发送给 API 的历史（不含占位 assistant）
    final history = [...conv0.messages, userMsg];

    final String convId = withUser.id;
    void patchAssistant(ChatMessage patched) {
      if (_disposed) return;
      final sv = state.value;
      if (sv == null) return;
      final conv = sv.current;
      if (conv == null || conv.id != convId) return;
      final msgs = conv.messages.map((m) => m.id == assistantId ? patched : m).toList();
      final updated = Conversation(
        id: conv.id,
        title: conv.title,
        messages: msgs,
        createdAt: conv.createdAt,
        updatedAt: DateTime.now(),
      );
      _replaceConversation(sv.conversations, updated);
    }

    try {
      String contentAcc = '';
      String reasoningAcc = '';

      final result = await _service.streamChat(
        apiKey: settings.apiKey,
        baseUrl: settings.baseUrl,
        model: settings.model,
        history: history,
        onDelta: (delta) {
          contentAcc += delta;
          patchAssistant(ChatMessage(
            id: assistantId,
            role: 'assistant',
            content: contentAcc,
            reasoningContent: reasoningAcc.isEmpty ? null : reasoningAcc,
            createdAt: assistantMsg.createdAt,
            isStreaming: true,
          ));
        },
        onReasoning: (delta) {
          reasoningAcc += delta;
          patchAssistant(ChatMessage(
            id: assistantId,
            role: 'assistant',
            content: contentAcc,
            reasoningContent: reasoningAcc,
            createdAt: assistantMsg.createdAt,
            isStreaming: true,
          ));
        },
      );

      patchAssistant(ChatMessage(
        id: assistantId,
        role: 'assistant',
        content: result.content,
        reasoningContent: result.reasoningContent,
        createdAt: assistantMsg.createdAt,
        isStreaming: false,
      ));

      if (!_disposed) {
        state = AsyncData(state.value?.copyWith(isGenerating: false) ??
            stateVal.copyWith(isGenerating: false));
      }
    } catch (e) {
      patchAssistant(ChatMessage(
        id: assistantId,
        role: 'assistant',
        content: '❌ 请求失败: ${e.toString()}',
        createdAt: assistantMsg.createdAt,
        isStreaming: false,
      ));
      if (!_disposed) {
        final sv = state.value;
        state = AsyncData((sv ?? stateVal).copyWith(isGenerating: false, error: e.toString()));
      }
    }
  }

  void stopGenerating() {
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

  @override
  void dispose() {
    _disposed = true;
    _service.dispose();
    super.dispose();
  }
}

final conversationProvider =
    AsyncNotifierProvider<ConversationNotifier, ConversationListState>(
        ConversationNotifier.new);
