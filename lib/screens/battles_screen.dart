import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/battle.dart';
import '../services/battle_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/handle_text.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/battle_card.dart';
import '../widgets/clash_overlay.dart';
import '../widgets/rank_badge.dart';
import 'battle_detail_screen.dart';
import 'profile_screen.dart';

/// شاشة النزالات
class BattlesScreen extends StatefulWidget {
  const BattlesScreen({super.key});

  @override
  State<BattlesScreen> createState() => _BattlesScreenState();
}

class _BattlesScreenState extends State<BattlesScreen> {
  /// 0 الأقرب · 1 الأكثر إثارة · 2 نزالاتي · 3 تحدياتي
  int _tab = 0;

  bool _loading = true;
  List<Battle> _battles = const [];
  List<Battle> _mine = const [];
  List<Battle> _pending = const [];
  int _points = 0;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = BattleService.instance.watchVotes(_refreshQuiet);
  }

  @override
  void dispose() {
    final c = _channel;
    if (c != null) BattleService.instance.unwatch(c);
    super.dispose();
  }

  Future<void> _refreshQuiet() async {
    if (!mounted || _tab > 1) return;
    final list = _tab == 0
        ? await BattleService.instance.fetchActive()
        : await BattleService.instance.fetchHot();
    if (!mounted) return;
    setState(() => _battles = list);
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final service = BattleService.instance;
      final me = await SupabaseService.instance.fetchMyProfile();
      final uid = SupabaseService.instance.currentUserId;

      final pending = await service.fetchPending();

      List<Battle> list = const [];
      List<Battle> mine = const [];

      if (_tab == 0) {
        list = await service.fetchActive();
      } else if (_tab == 1) {
        list = await service.fetchHot();
      } else if (_tab == 2 && uid != null) {
        mine = await service.fetchUserBattles(uid);
      }

      if (!mounted) return;
      setState(() {
        _points = me?.battlePoints ?? 0;
        _pending = pending;
        _battles = list;
        _mine = mine;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _switchTab(int i) {
    if (_tab == i) return;
    setState(() => _tab = i);
    _load();
  }

  void _openProfile(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)),
    );
  }

  Future<void> _openBattle(Battle b) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BattleDetailScreen(battle: b)),
    );
    _load();
  }

  Future<void> _accept(Battle b) async {
    try {
      await BattleService.instance.accept(b.id);
      if (!mounted) return;

      await ClashOverlay.show(context);
      if (!mounted) return;

      setState(() => _tab = 2);
      _load();
    } catch (_) {
      _snack('تعذّر قبول التحدي');
    }
  }

  Future<void> _decline(Battle b) async {
    try {
      await BattleService.instance.decline(b.id);
      if (!mounted) return;
      _snack('رُفض التحدي');
      _load();
    } catch (_) {
      _snack('تعذّر الرفض');
    }
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            _tabs(context),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.brand),
                    )
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: _load,
                      child: switch (_tab) {
                        2 => _mineList(),
                        3 => _pendingList(),
                        _ => _battlesList(),
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 19)),
                const SizedBox(width: 8),
                Text(
                  'النزالات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            RankProgress(points: _points),
          ],
        ),
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _tabItem(context, 'الأقرب', 0),
          _tabItem(context, 'الأكثر إثارة', 1),
          _tabItem(context, 'نزالاتي', 2),
          _tabItem(context, 'تحدياتي', 3, badge: _pending.length),
        ],
      ),
    );
  }

  Widget _tabItem(
    BuildContext context,
    String label,
    int index, {
    int badge = 0,
  }) {
    final active = _tab == index;

    return Expanded(
      child: InkWell(
        onTap: () => _switchTab(index),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    label,
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 12.5,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active
                                  ? AppColors.text
                                  : AppColors.textMuted,
                            ),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -6,
                      left: -12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.like,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                            color: AppColors.background,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: active ? AppColors.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _battlesList() {
    if (_battles.isEmpty) return _empty('لا توجد نزالات نشطة الآن');

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 90),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _battles.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => _openBattle(_battles[i]),
        child: BattleCard(
          battle: _battles[i],
          onOpenProfile: _openProfile,
          showArguments: false,
        ),
      ),
    );
  }

  Widget _mineList() {
    if (_mine.isEmpty) return _empty('لم تخض نزالًا بعد');

    final uid = SupabaseService.instance.currentUserId;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 90),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _mine.length,
      itemBuilder: (_, i) {
        final b = _mine[i];

        return Column(
          children: [
            if (b.isFinished) _resultBanner(context, b, uid),
            GestureDetector(
              onTap: () => _openBattle(b),
              child: BattleCard(
                battle: b,
                onOpenProfile: _openProfile,
                showArguments: false,
              ),
            ),
          ],
        );
      },
    );
  }

  /// شريط النتيجة فوق نزالي المنتهي
  Widget _resultBanner(BuildContext context, Battle b, String? uid) {
    final won = b.winnerId != null && b.winnerId == uid;
    final tie = b.isTie;

    final color = tie
        ? AppColors.textMuted
        : won
            ? const Color(0xFFD4A017)
            : AppColors.like;

    final label = tie
        ? 'انتهى بالتعادل · +١ نقطة'
        : won
            ? 'فزتَ بهذا النزال · +٤ نقاط'
            : 'خسرتَ هذا النزال · +١ نقطة';

    final icon = tie
        ? Icons.remove
        : won
            ? Icons.emoji_events
            : Icons.shield_outlined;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingList() {
    if (_pending.isEmpty) return _empty('لا توجد تحديات واردة');

    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 90),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _pending.length,
      itemBuilder: (_, i) => _pendingCard(context, _pending[i]),
    );
  }

  Widget _pendingCard(BuildContext context, Battle b) {
    final t = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brand.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _openProfile(b.challenger.userId),
                  child: AvatarCircle(
                    initial: b.challenger.initial,
                    seed: AppColors.brand,
                    imageUrl: b.challenger.avatarUrl,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 5,
                        children: [
                          Text(b.challenger.name,
                              style: t.titleMedium?.copyWith(fontSize: 14)),
                          if (b.challenger.verified)
                            const Icon(Icons.verified,
                                size: 13, color: AppColors.blue),
                          Text(atHandle(b.challenger.handle),
                              style: t.bodySmall),
                        ],
                      ),
                      Text('يتحداك · ${b.topic.label}',
                          style: t.bodySmall
                              ?.copyWith(color: AppColors.brand)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('منشورك:', style: t.bodySmall),
                  const SizedBox(height: 4),
                  Text(b.opponent.text,
                      style: t.bodyMedium?.copyWith(fontSize: 14)),
                  const Divider(height: 18, color: AppColors.border),
                  Text('ردّه:', style: t.bodySmall),
                  const SizedBox(height: 4),
                  Text(b.challenger.text,
                      style: t.bodyMedium?.copyWith(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _accept(b),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        child: const Text(
                          '⚔️ قبول التحدي',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.background,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Material(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _decline(b),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'رفض',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String text) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              const Text('⚔️', style: TextStyle(fontSize: 38)),
              const SizedBox(height: 12),
              Text(text, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                'تحدَّ أي منشور من قائمة النقاط الثلاث',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
