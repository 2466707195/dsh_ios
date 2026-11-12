/// 对话消息模型
/// 对应 DeepSeek / OpenAI 兼容 Chat API 的 message 结构
class ChatMessage {
  final String id;
  final String role; // system | user | assistant
  final String content;
  final String? reasoningContent; // 思考链（deepseek-reasoner / v4 thinking）
  final DateTime createdAt;
  final bool isStreaming;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.reasoningContent,
    required this.createdAt,
    this.isStreaming = false,
  });

  ChatMessage copyWith({
    String? content,
    String? reasoningContent,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      createdAt: createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toApiJson() => {'role': role, 'content': content};

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'reasoningContent': reasoningContent,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        reasoningContent: json['reasoningContent'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
