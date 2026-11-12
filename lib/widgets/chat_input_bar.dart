import 'package:flutter/material.dart';

class ChatInputBar extends StatefulWidget {
  final bool isGenerating;
  final void Function(String text) onSend;
  final VoidCallback onStop;

  const ChatInputBar({
    super.key,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final can = _controller.text.trim().isNotEmpty;
      if (can != _canSend) setState(() => _canSend = can);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (!_canSend || widget.isGenerating) return;
    widget.onSend(_controller.text);
    _controller.clear();
    setState(() => _canSend = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                enabled: !widget.isGenerating,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: widget.isGenerating
                      ? '正在生成…'
                      : '输入消息…',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF2F2F7),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(
              isGenerating: widget.isGenerating,
              canSend: _canSend,
              onSend: _handleSend,
              onStop: widget.onStop,
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isGenerating;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _SendButton({
    required this.isGenerating,
    required this.canSend,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (isGenerating) {
      return IconButton(
        onPressed: onStop,
        icon: const Icon(Icons.stop_circle, size: 32),
        color: Colors.red,
      );
    }
    return IconButton(
      onPressed: canSend ? onSend : null,
      icon: Icon(
        Icons.arrow_upward_rounded,
        size: 26,
        color: canSend ? Colors.white : Colors.grey.shade400,
      ),
      style: IconButton.styleFrom(
        backgroundColor:
            canSend ? const Color(0xFF4A90D9) : Colors.grey.shade300,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(6),
      ),
    );
  }
}
