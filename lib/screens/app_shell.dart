import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/share_bottom_nav.dart';
import 'compose_screen.dart';
import 'explore_screen.dart';
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
