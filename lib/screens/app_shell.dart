import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/share_bottom_nav.dart';
import 'compose_screen.dart';
import 'mentions_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'timeline_screen.dart';

/// الهيكل الرئيسي — يربط شريط التنقل بالشاشات الخمس
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  final _timelineKey = GlobalKey<TimelineScreenState>();

  Future<void> _openCompose() async {
    final body = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ComposeScreen(),
      ),
    );

    if (body == null || body.trim().isEmpty) return;

    try {
      await SupabaseService.instance.createPost(body.trim());
      await _timelineKey.currentState?.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نشر المنشور')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر نشر المنشور')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: [
          TimelineScreen(key: _timelineKey, showChrome: false),
          const _ExploreScreen(),
          const MentionsScreen(showChrome: false),
          const MessagesScreen(showChrome: false),
          const ProfileScreen(showBottomNav: false),
        ],
      ),
      bottomNavigationBar: ShareBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
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

/// استكشاف — شاشة مؤقتة، غير موجودة في التصميم بعد
class _ExploreScreen extends StatelessWidget {
  const _ExploreScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'استكشاف — قريبًا',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
