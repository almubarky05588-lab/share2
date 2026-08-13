import 'dart:async';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/share_bottom_nav.dart';
import 'compose_screen.dart';
import 'explore_screen.dart';
import 'mentions_screen.dart';
import 'messages_screen.dart';
import 'timeline_screen.dart';

/// الهيكل الرئيسي — أربع شاشات في شريط التنقل
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;
  int _badge = 0;
  Timer? _timer;

  final _timelineKey = GlobalKey<TimelineScreenState>();
  final _mentionsKey = GlobalKey<MentionsScreenState>();

  @override
  void initState() {
    super.initState();
    _refreshBadge();
    _timer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _refreshBadge(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBadge() async {
    final n = await SupabaseService.instance.unreadNotificationsCount();
    if (!mounted) return;
    setState(() => _badge = n);
  }

  Future<void> _onTabTap(int i) async {
    setState(() => _index = i);

    if (i == 2) {
      await SupabaseService.instance.markNotificationsSeen();
      if (!mounted) return;
      setState(() => _badge = 0);
      _mentionsKey.currentState?.reload();
    }
  }

  Future<void> _openCompose() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ComposeScreen(),
      ),
    );

    if (posted != true) return;

    await _timelineKey.currentState?.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نشر المنشور')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: [
          TimelineScreen(key: _timelineKey, showChrome: false),
          const ExploreScreen(),
          MentionsScreen(key: _mentionsKey, showChrome: false),
          const MessagesScreen(showChrome: false),
        ],
      ),
      bottomNavigationBar: ShareBottomNav(
        currentIndex: _index,
        mentionsBadge: _badge,
        onTap: _onTabTap,
      ),
      floatingActionButton: _index == 0 ? _shareButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _shareButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          onTap: _openCompose,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 19, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 18, color: AppColors.background),
                SizedBox(width: 7),
                Text(
                  'share',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.55,
                    color: AppColors.background,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
