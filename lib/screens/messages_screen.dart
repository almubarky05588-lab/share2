import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/share_bottom_nav.dart';
import 'chat_screen.dart';

/// الرسائل الخاصة — الشاشة ٣ من التصميم
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.showChrome = true});

  /// false عند العرض داخل AppShell — شريط التنقل يأتي من الهيكل
  final bool showChrome;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  // مؤقت — يُستبدل بجلب من Supabase
  static const _conversations = <Conversation>[
    Conversation(
      id: '1',
      name: 'نورة السالم',
      handle: 'noura_s',
      verified: true,
      time: 'الآن',
      unread: true,
      lastMessage: 'تمام، أرسل لي ملف التصميم النهائي وأراجعه اليوم بإذن الله.',
    ),
    Conversation(
      id: '2',
      name: 'خالد المطيري',
      handle: 'khalid.m',
      time: '11:20',
      unread: true,
      lastMessage: 'شفت الريشير الأخير؟ وصل ناس كثير.',
    ),
    Conversation(
      id: '3',
      name: 'استوديو مِداد',
      handle: 'midad.studio',
      verified: true,
      time: 'أمس',
      lastMessage: 'أرسلنا لك دعوة للتعاون على اللوحة الجديدة.',
    ),
    Conversation(
      id: '4',
      name: 'سارة العتيبي',
      handle: 'sara.otb',
      time: 'أمس',
      lastMessage: 'شكرًا على المنشن 🌿',
    ),
    Conversation(
      id: '5',
      name: 'فهد الحربي',
      handle: 'fahad_hr',
      time: 'الأحد',
      sentByMe: true,
      lastMessage: 'راجعت الملاحظات وعدّلت التباعد.',
    ),
  ];

  List<Conversation> get _visible {
    if (_query.trim().isEmpty) return _conversations;
    final q = _query.trim();
    return _conversations
        .where((c) =>
            c.name.contains(q) ||
            c.handle.contains(q) ||
            c.lastMessage.contains(q))
        .toList();
  }

  void _openChat(Conversation c) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          name: c.name,
          handle: c.handle,
          verified: c.verified,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            _search(context),
            Expanded(
              child: list.isEmpty
                  ? _empty(context)
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: list.length,
                      itemBuilder: (_, i) => _ConversationTile(
                        conversation: list[i],
                        onTap: () => _openChat(list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.showChrome ? const ShareBottomNav(currentIndex: 3) : null,
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18, left: 18, top: 6, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'الرسائل الخاصة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
          ),
          const Icon(
            Icons.edit_outlined,
            size: 20,
            color: AppColors.text,
          ),
        ],
      ),
    );
  }

  Widget _search(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        0,
        AppSizes.screenPadding,
        12,
      ),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.border.withOpacity(0.45),
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search,
              size: AppSizes.iconSmall,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.text,
                    ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'ابحث في الرسائل',
                  hintStyle: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Text(
        'لا توجد نتائج',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

/// صف محادثة واحدة
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, this.onTap});

  final Conversation conversation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = conversation;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.screenPadding,
          vertical: 12,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarCircle(
              initial: c.initial,
              seed: c.avatarSeed,
              size: 48,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c.time, style: t.bodySmall),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleMedium?.copyWith(fontSize: 14),
                              ),
                            ),
                            if (c.verified) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.verified,
                                size: 15,
                                color: AppColors.blue,
                              ),
                            ],
                            const SizedBox(width: 6),
                            Text('‎@${c.handle}', style: t.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: t.bodySmall?.copyWith(
                      color: c.unread ? AppColors.text : AppColors.textMuted,
                      fontWeight:
                          c.unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (c.unread) ...[
              const SizedBox(width: 11),
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
