import 'package:athena/services/typing_indicator.dart';
import 'package:flutter/material.dart';

class ChatBubble extends StatefulWidget {
  final String message;
  final bool isUser;
  final bool isLoading;
  final Color textColor;
  final FontWeight fontWeight; // Add fontWeight parameter

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.isLoading = false,
    required this.textColor,
    required this.fontWeight, // Add this to the constructor
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const ElasticOutCurve(0.7),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.isUser ? const Offset(0.25, 0.1) : const Offset(-0.25, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCirc),
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
      ),
    );

    // Use Future.microtask instead of addPostFrameCallback for more reliable animation triggering
    Future.microtask(() {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _sanitizeText(String text) {
    return text
        .replaceAll('□', '')
        .replaceAll('*', '')
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'Ã¢Â¹'), '₹')
        .replaceAll(RegExp(r'Ã¢Â¬'), '€')
        .replaceAll(RegExp(r'Ã¡'), 'á')
        .replaceAll(RegExp(r'Ã²'), 'ò')
        .replaceAll(RegExp(r'ÃŸ'), 'ß')
        .replaceAll(RegExp(r'Ã¿'), 'ÿ')
        .replaceAll(RegExp(r'Ã¸'), 'ø')
        .replaceAll(RegExp(r'Ã§'), 'ç')
        .replaceAll(RegExp(r'Ã¤'), 'ä')
        .replaceAll(RegExp(r'Ã¼'), 'ü')
        .replaceAll(RegExp(r'Ãè'), 'è')
        .replaceAll(RegExp(r'Ã‰'), 'É')
        .replaceAll(RegExp(r'Ã¬'), 'ì')
        .replaceAll(RegExp(r'Ãê'), 'ê')
        .replaceAll(RegExp(r'Ã¿'), 'ÿ')
        .trim();
  }

  bool _containsCode(String text) {
    return text.contains("```");
  }

  Widget _buildCodeBlock(String part) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(
        color: const Color.fromARGB(214, 0, 0, 0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        part.trim(),
        style: TextStyle(
          fontFamily: 'SFDisplayPro',
          color: Colors.white,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildTextBlock(String part) {
    return Text(
      _sanitizeText(part),
      style: TextStyle(
        fontFamily: 'BOLD',
        fontSize: 16,
        fontWeight:
            widget.fontWeight, // Use the fontWeight passed in the constructor
        color: widget.isUser ? Colors.white : Colors.black87,
      ),
      softWrap: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCode = _containsCode(widget.message);
    final List<String> parts = widget.message.split("```");

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: Align(
        alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isUser
                ? const Color.fromARGB(255, 33, 177, 243)
                : Colors.grey[300],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  widget.isUser ? const Radius.circular(16) : Radius.zero,
              bottomRight:
                  widget.isUser ? Radius.zero : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: widget.isLoading
              ? TypingIndicator()
              : hasCode
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: parts.mapIndexed((index, part) {
                        if (part.trim().isEmpty) return const SizedBox.shrink();
                        final bool isCode = index.isOdd;
                        return isCode
                            ? _buildCodeBlock(part)
                            : _buildTextBlock(part);
                      }).toList(),
                    )
                  : _buildTextBlock(widget.message),
        ),
      ),
    );
  }
}

// Extension to add mapIndexed to Iterable
extension IndexedIterable<E> on Iterable<E> {
  Iterable<T> mapIndexed<T>(T Function(int index, E item) f) sync* {
    var index = 0;
    for (final item in this) {
      yield f(index, item);
      index = index + 1;
    }
  }
}
