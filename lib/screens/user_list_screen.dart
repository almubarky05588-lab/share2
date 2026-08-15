import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/handle_text.dart';
import '../widgets/avatar_circle.dart';
import 'profile_screen.dart';

/// نوع القائمة المعروضة
enum UserListKind { followers, following }

/// قائمة المتابعين أو من يتابعهم
class UserListScreen extends StatefulWidget {
  const UserListScreen({
    super.key,
    required this.userId,
    required this.kind,
  });

  final String userId;
  final UserListKind kind;

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  bool _loading = true;
  List<UserProfile> _users = const [];

  String get _title =>
      widget.kind == UserListKind.followers ? 'المتابِعون' : 'يتابع';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final service = SupabaseService.instance;
      final users = widget.kind == UserListKind.followers
          ? await service.fetchFollowers(widget.userId)
          : await service.fetchFollowing(widget.userId);

      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openProfile(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _load,
              child: _users.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        Center(
                          child: Text(
                            widget.kind == UserListKind.followers
                                ? 'لا يوجد متابِعون بعد'
                                : 'لا يتابع أحدًا بعد',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _users.length,
                      itemBuilder: (_, i) => _tile(context, _users[i]),
                    ),
            ),
    );
  }

  Widget _tile(BuildContext context, UserProfile u) {
    final t = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: InkWell(
        onTap: () => _openProfile(u.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarCircle(
                initial: u.initial,
                seed: u.avatarSeed,
                imageUrl: u.avatarUrl,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 2,
                      children: [
                        Text(
                          u.name,
                          style: t.titleMedium?.copyWith(fontSize: 15),
                        ),
                        if (u.verified)
                          const Icon(Icons.verified,
                              size: 15, color: AppColors.blue),
                      ],
                    ),
                    Text(atHandle(u.handle), style: t.bodySmall),
                    if (u.bio.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        u.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
                      ),
                    ],
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
