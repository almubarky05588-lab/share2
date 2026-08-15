import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/handle_text.dart';
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
          avatarUrl: c.avatarUrl,
          verified: c.verified,
        ),
      ),
    );
    _load();
  }

  Future<void> _newChat() async {
    final picked = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _UserPickerSheet(),
    );

    if (picked == null || !mounted) return;

    try {
      final cid =
          await SupabaseService.instance.openConversationWith(picked.id);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: cid,
            otherUserId: picked.id,
            name: picked.name,
            handle: picked.handle,
            avatarUrl: picked.avatarUrl,
            verified: picked.verified,
          ),
        ),
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح المحادثة')),
      );
    }
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
                                  height:
                                      MediaQuery.of(context).size.height *
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
                              padding: const EdgeInsets.only(bottom: 90),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.background,
        onPressed: _newChat,
        child: const Icon(Icons.edit_outlined, size: 21),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

/// لوحة اختيار مستخدم لبدء محادثة
class _UserPickerSheet extends StatefulWidget {
  const _UserPickerSheet();

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  final _controller = TextEditingController();
  List<UserProfile> _users = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);

    try {
      final me = SupabaseService.instance.currentUserId;
      final users = await SupabaseService.instance.searchUsers(q);
      if (!mounted) return;
      setState(() {
        _users = users.where((u) => u.id != me).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  'محادثة جديدة',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 17),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        size: 19, color: AppColors.textMuted),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        onChanged: _search,
                        textAlign: TextAlign.right,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.text),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'ابحث عن مستخدم',
                          hintStyle:
                              Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.brand),
                    )
                  : _users.isEmpty
                      ? Center(
                          child: Text(
                            'لا توجد نتائج',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (_, i) {
                            final u = _users[i];

                            return InkWell(
                              onTap: () => Navigator.of(context).pop(u),
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 11),
                                  child: Row(
                                    children: [
                                      AvatarCircle(
                                        initial: u.initial,
                                        seed: u.avatarSeed,
                                        imageUrl: u.avatarUrl,
                                        size: 44,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: 5,
                                              children: [
                                                Text(
                                                  u.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                          fontSize: 15),
                                                ),
                                                if (u.verified)
                                                  const Icon(Icons.verified,
                                                      size: 14,
                                                      color:
                                                          AppColors.blue),
                                              ],
                                            ),
                                            Text(atHandle(u.handle),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: InkWell(
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
                imageUrl: c.avatarUrl,
                size: 48,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 5,
                            runSpacing: 2,
                            children: [
                              Text(
                                c.name,
                                style: t.titleMedium?.copyWith(fontSize: 14),
                              ),
                              if (c.verified)
                                const Icon(Icons.verified,
                                    size: 15, color: AppColors.blue),
                              Text(atHandle(c.handle), style: t.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(c.time, style: t.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
