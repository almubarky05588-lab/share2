import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/share_bottom_nav.dart';
import 'chat_screen.dart';

/// الرسائل الخاصة
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.showChrome = true});

  final bool showChrome;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  bool _loading = true;
  List<Conversation> _conversations = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final items = await SupabaseService.instance.fetchConversations();
      if (!mounted) return;
      setState(() {
        _conversations = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Conversation> get _visible {
    final q = _query.trim();
    if (q.isEmpty) return _conversations;

    return _conversations
        .where((c) =>
            c.name.contains(q) ||
            c.handle.contains(q) ||
            c.lastMessage.contains(q))
        .toList();
  }

  Future<void> _openChat(Conversation c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: c.id,
          otherUserId: c.otherUserId,
          name: c.name,
          handle: c.handle,
          verified: c.verified,
        ),
      ),
    );
    _load();
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
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.brand),
                    )
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: _load,
                      child: list.isEmpty
                          ? ListView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context)
                                          .size
                                          .height *
                                      0.25,
                                ),
                                Center(
                                  child: Text(
                                    _query.isEmpty
                                        ? 'لا توجد محادثات بعد'
                                        : 'لا توجد نتائج',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              itemCount: list.length,
                              itemBuilder: (_, i) => _ConversationTile(
                                conversation: list[i],
                                onTap: () => _openChat(list[i]),
                              ),
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
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'الرسائل الخاصة',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
        ),
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
            const Icon(Icons.search,
                size: AppSizes.iconSmall, color: AppColors.textMuted),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                textAlign: TextAlign.right,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.text),
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
                                style:
                                    t.titleMedium?.copyWith(fontSize: 14),
                              ),
                            ),
                            if (c.verified) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified,
                                  size: 15, color: AppColors.blue),
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
          ],
        ),
      ),
    );
  }
}
