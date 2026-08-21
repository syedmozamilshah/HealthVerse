import 'package:flutter/material.dart';
import 'package:flutter_floaty/flutter_floaty.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../../services/buddy_chat_service/buddy_chat_service.dart';
import '../color/colors.dart';

/// BuddyChatWidget - A floating chatbot widget that can be dragged anywhere
/// Uses flutter_floaty package for smooth draggable functionality
/// Shows a cute buddy AI icon that expands into a chat interface
class BuddyChatWidget extends StatefulWidget {
  const BuddyChatWidget({super.key});

  @override
  State<BuddyChatWidget> createState() => _BuddyChatWidgetState();
}

class _BuddyChatWidgetState extends State<BuddyChatWidget>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  bool _isLoading = false;
  final BuddyChatService _chatService = BuddyChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleChat() {
    if (_isOpen) {
      _animationController.reverse().then((_) {
        _removeOverlay();
      });
    } else {
      // Add greeting if no messages
      if (_messages.isEmpty) {
        _messages.add(ChatMessage(
          text: _chatService.getGreeting(),
          isUser: false,
        ));
      }
      _showOverlay();
      _animationController.forward();
    }
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildChatOverlay(),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _updateOverlay();

    _scrollToBottom();

    try {
      final response = await _chatService.sendMessage(text);
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
      _updateOverlay();
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Oops! Something went wrong. Please try again! 👁️",
          isUser: false,
        ));
        _isLoading = false;
      });
      _updateOverlay();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 100 + bottomPadding;

    // Define boundaries for the draggable widget
    final boundaries = Rect.fromLTWH(
      0,
      100, // Top margin to avoid status bar
      screenSize.width,
      screenSize.height - navBarHeight - 50, // Leave space for nav bar
    );

    return FlutterFloaty(
      intrinsicBoundaries: boundaries,
      width: 64,
      height: 64,
      initialX: screenSize.width - 80,
      initialY: screenSize.height - navBarHeight - 80,
      builder: (context) => _buildBuddyContent(),
      backgroundColor: Colors.transparent,
      onDragBackgroundColor: Colors.transparent,
      borderRadius: 32,
      growingFactor: 1.15,
      enableAnimation: true,
      onTap: _toggleChat,
      shadow: BoxShadow(
        color: tealColor.withOpacity(0.4),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    );
  }

  Widget _buildBuddyContent() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: _isOpen
              ? [Colors.red.shade400, Colors.red.shade600]
              : [tealColor, darkTealColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isOpen ? Colors.red : tealColor).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isOpen
          ? const Icon(Icons.close, color: Colors.white, size: 28)
          : ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'lib/assets/buddy_ai.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                      size: 32,
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _buildChatOverlay() {
    return Positioned(
      bottom: 180,
      right: 16,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment.bottomRight,
        child: Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 85.w > 350 ? 350 : 85.w,
            height: 60.h > 500 ? 500 : 60.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tealColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                // Header
                _buildChatHeader(),

                // Messages
                Expanded(child: _buildMessageList()),

                // Input
                _buildInputField(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tealColor, darkTealColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.5), width: 2),
            ),
            child: ClipOval(
              child: Image.asset(
                'lib/assets/buddy_ai.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.smart_toy,
                      color: tealColor, size: 24);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Eye Buddy',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Your eye health assistant 👁️',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _messages.clear();
              _chatService.clearHistory();
              _messages.add(ChatMessage(
                text: _chatService.getGreeting(),
                isUser: false,
              ));
              _updateOverlay();
            },
            tooltip: 'New Chat',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _toggleChat,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: message.isUser ? 40 : 0,
          right: message.isUser ? 0 : 40,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser ? tealColor : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4, right: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            _buildDot(1),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: tealColor.withOpacity(0.4 + (0.6 * (1 - value))),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask about eye health...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: tealColor, width: 2),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tealColor, darkTealColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: tealColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();
}
