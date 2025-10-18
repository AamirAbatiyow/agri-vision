// lib/pages/chat/ai_chat_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage>
    with SingleTickerProviderStateMixin {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  // Backend URL - adjust for your setup
  static const String _backend = 'http://10.102.96.77:8000';

  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Welcome message
    _messages.add(
      _ChatMessage(
        text:
            '👋 Hi! I\'m your AgriVision AI assistant. Ask me anything about crops, diseases, soil health, or farming techniques!',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _typingController.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(
        _ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });
    _input.clear();
    _scrollToEnd();

    try {
      // Call AI endpoint
      final response = await http
          .get(
            Uri.parse('$_backend/ai_usda?query=${Uri.encodeComponent(text)}'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse =
            data['response']?.toString() ?? 'No response received.';

        // Simulate typing delay for better UX
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          setState(() {
            _messages.add(
              _ChatMessage(
                text: aiResponse,
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            _isTyping = false;
          });
          _scrollToEnd();
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text:
                  '❌ Sorry, I encountered an error: $e\n\nPlease make sure the backend server is running.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isTyping = false;
        });
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Gradient background for AI assistant feel
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [scheme.surface, scheme.surfaceContainerHighest]
                : [
                    scheme.primaryContainer.withOpacity(0.2),
                    scheme.surface,
                    scheme.secondaryContainer.withOpacity(0.15),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern header
              _buildHeader(scheme),

              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    return _MessageBubble(
                      message: _messages[i],
                      scheme: scheme,
                    );
                  },
                ),
              ),

              // Typing indicator
              if (_isTyping) _buildTypingIndicator(scheme),

              // Input composer
              _buildComposer(scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          // AI Icon with gradient
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FaIcon(
              FontAwesomeIcons.brain,
              size: 20,
              color: scheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Powered by AWS & USDA',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primaryContainer, scheme.secondaryContainer],
              ),
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              FontAwesomeIcons.brain,
              size: 12,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AnimatedDot(controller: _typingController, delay: 0),
                const SizedBox(width: 4),
                _AnimatedDot(controller: _typingController, delay: 0.2),
                const SizedBox(width: 4),
                _AnimatedDot(controller: _typingController, delay: 0.4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.8),
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              style: TextStyle(color: scheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Ask about crops, diseases, farming...',
                hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.6),
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                prefixIcon: Icon(
                  FontAwesomeIcons.leaf,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 12),
          // Send button with gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isTyping ? null : _send,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: FaIcon(
                    FontAwesomeIcons.paperPlane,
                    size: 18,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Message bubble widget with animations
class _MessageBubble extends StatefulWidget {
  final _ChatMessage message;
  final ColorScheme scheme;

  const _MessageBubble({required this.message, required this.scheme});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.message.isUser ? 0.1 : -0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final isUser = widget.message.isUser;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                // AI Avatar
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.secondary],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.brain,
                    size: 14,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // Message bubble
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? LinearGradient(
                            colors: [
                              scheme.primary,
                              scheme.primary.withOpacity(0.8),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              scheme.surfaceContainerHigh,
                              scheme.surfaceContainerHighest,
                            ],
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    border: Border.all(
                      color: scheme.outlineVariant.withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message.text,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: isUser ? scheme.onPrimary : scheme.onSurface,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(widget.message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isUser
                              ? scheme.onPrimary.withOpacity(0.7)
                              : scheme.onSurfaceVariant,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 10),
                // User Avatar
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.user,
                    size: 14,
                    color: scheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

// Animated typing dot
class _AnimatedDot extends StatelessWidget {
  final AnimationController controller;
  final double delay;

  const _AnimatedDot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = ((controller.value + delay) % 1.0);
        final opacity = (0.3 + (0.7 * (1 - (value - 0.5).abs() * 2))).clamp(
          0.0,
          1.0,
        );

        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

// Message data model
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
