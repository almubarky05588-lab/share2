import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';

/// محادثة خاصة — الشاشة ٤ من التصميم
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.name = 'نورة السالم',
    this.handle = 'noura_s',
    this.verified = true,
  });

  final String name;
  final String handle; // بدون @
  final bool verified;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // مؤقت — يُستبدل بجلب من Supabase
  final _messages = <Message>[
    const Message(
      id: '1',
      fromMe: false,
      time: '11:02',
      body: 'السلام عليكم مبارك، شفت النسخة الأخيرة من التصميم؟',
    ),
    const Message(
      id: '2',
      fromMe: true,
      time: '11:04',
      body: 'وعليكم السلام 👋 نعم شفتها، الاتجاه صار مضبوط تمامًا.',
    ),
    const Message(
      id: '3',
      fromMe: false,
      time: '11:05',
      body:
          'ممتاز. الشيء المهم عندي هو تباعد الأسطر في النص العربي — لازم يكون أوسع شوي عشان يرتاح.',
    ),
    const Message(
      id: '4',
      fromMe: true,
      time: '11:07',
      body:
          'بالضبط — الصورة الرمزية والاسم على اليمين، والإجراءات موزّعة تحت النص. ضبطتها على 1.75.',
    ),
    const Message(
      id: '5',
      fromMe: false,
      time: '11:20',
      body: 'تمام، أرسل لي ملف التصميم النهائي وأراجعه اليوم بإذن الله.',
    ),
  ];

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        Message(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          body: text,
          time: _now(),
          fromMe: true,
        ),
      );
      _controller.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  static String _now() {
    final d = DateTime.now();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.screenPadding,
                  vertical: 16,
                ),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _Bubble(message: _messages[i]),
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
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_forward,
              size: 20,
              color: AppColors.text,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.name,
                    style: t.titleMedium?.copyWith(fontSize: 16),
                  ),
                  if (widget.verified) ...[
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.verified,
                      size: 15,
                      color: AppColors.blue,
                    ),
                  ],
                ],
              ),
              Text('‎@${widget.handle}', style: t.bodySmall),
            ],
          ),
          const SizedBox(width: 10),
          AvatarCircle(
            initial: widget.name.characters.first,
            seed: AppColors.brand,
            size: 38,
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.info_outline,
            size: 20,
            color: AppColors.text,
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
              onTap: _send,
              child: const SizedBox(
                width: 41,
                height: 39,
                child: Icon(
                  Icons.send,
                  size: 19,
                  color: AppColors.background,
                ),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: AppColors.text,
                    ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  border: InputBorder.none,
                  hintText: 'اكتب رسالة…',
                  hintStyle: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          const Icon(
            Icons.image_outlined,
            size: 22,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 9),
          const Icon(
            Icons.emoji_emotions_outlined,
            size: 22,
            color: AppColors.textMuted,
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
            constraints: const BoxConstraints(maxWidth: 258),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: mine
                    ? AppColors.brand
                    : AppColors.border.withOpacity(0.45),
                borderRadius: BorderRadius.only(
                  topRight: const Radius.circular(18),
                  topLeft: const Radius.circular(18),
                  bottomRight: Radius.circular(mine ? 18 : 4),
                  bottomLeft: Radius.circular(mine ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.body,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: mine
                              ? AppColors.background
                              : AppColors.text,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      message.time,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.55,
                        color: mine
                            ? AppColors.background.withOpacity(0.75)
                            : AppColors.textMuted,
                      ),
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
