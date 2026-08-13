import 'dart:async';

import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';
import 'profile_screen.dart';

/// محادثة خاصة — بث حي للرسائل
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.name,
    required this.handle,
    this.otherUserId,
    this.verified = false,
    this.avatarUrl,
  });

  final String conversationId;
  final String name;
  final String handle;
  final String? otherUserId;
  final bool verified;
  final String? avatarUrl;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  StreamSubscription<List<Message>>? _sub;
  List<Message> _messages = const [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// يستمع للرسائل لحظيًا — تصل بلا خروج ودخول
  void _listen() {
    _sub = SupabaseService.instance
        .messageStream(widget.conversationId)
        .listen((msgs) {
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToEnd();
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      await SupabaseService.instance
          .sendMessage(widget.conversationId, text);
      _controller.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إرسال الرسالة')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openProfile() {
    if (widget.otherUserId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: widget.otherUserId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.brand),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            'ابدأ المحادثة',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.screenPadding,
                            vertical: 16,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) =>
                              _Bubble(message: _messages[i]),
                        ),
            ),
            _composer(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_forward,
                size: 20, color: AppColors.text),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _openProfile,
            child: AvatarCircle(
              initial:
                  widget.name.isEmpty ? '؟' : widget.name.characters.first,
              seed: AppColors.brand,
              imageUrl: widget.avatarUrl,
              size: 38,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _openProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    textDirection: TextDirection.rtl,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    children: [
                      Text(widget.name,
                          style: t.titleMedium?.copyWith(fontSize: 16)),
                      if (widget.verified)
                        const Icon(Icons.verified,
                            size: 15, color: AppColors.blue),
                    ],
                  ),
                  Text('‎@${widget.handle}', style: t.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Material(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _sending ? null : _send,
              child: SizedBox(
                width: 41,
                height: 39,
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Icon(Icons.send,
                        size: 19, color: AppColors.background),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.45),
                borderRadius: BorderRadius.circular(21),
              ),
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.right,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => _send(),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 15),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 11),
                  border: InputBorder.none,
                  hintText: 'اكتب رسالة…',
                  hintStyle: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// فقاعة رسالة
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromMe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine
                    ? AppColors.brand
                    : AppColors.border.withOpacity(0.5),
                borderRadius: BorderRadius.only(
                  topRight: const Radius.circular(18),
                  topLeft: const Radius.circular(18),
                  bottomRight: Radius.circular(mine ? 18 : 4),
                  bottomLeft: Radius.circular(mine ? 4 : 18),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.body,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          color:
                              mine ? AppColors.background : AppColors.text,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message.time,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: mine
                          ? AppColors.background.withOpacity(0.75)
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
