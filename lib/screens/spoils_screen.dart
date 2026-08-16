import 'package:flutter/material.dart';

import '../models/spoil.dart';
import '../services/battle_service.dart';
import '../theme/app_theme.dart';
import '../theme/handle_text.dart';
import '../widgets/avatar_circle.dart';

/// الغنائم — وصول لجمهور من هزمتهم
class SpoilsScreen extends StatefulWidget {
  const SpoilsScreen({super.key});

  @override
  State<SpoilsScreen> createState() => _SpoilsScreenState();
}

class _SpoilsScreenState extends State<SpoilsScreen> {
  bool _loading = true;
  List<Spoil> _spoils = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final list = await BattleService.instance.fetchMySpoils();
      if (!mounted) return;
      setState(() {
        _spoils = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int get _totalReach => _spoils
      .where((s) => s.isUsable)
      .fold(0, (sum, s) => sum + s.reach);

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الغنائم ⚔️'),
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
              child: _spoils.isEmpty ? _empty(context) : _list(context),
            ),
    );
  }

  Widget _list(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _summary(context),
        const SizedBox(height: 16),
        ..._spoils.map((s) => _card(context, s)),
      ],
    );
  }

  /// إجمالي الوصول المتاح
  Widget _summary(BuildContext context) {
    final usable = _spoils.where((s) => s.isUsable).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4A017), Color(0xFFE0455C)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('⚔️', style: TextStyle(fontSize: 20)),
                SizedBox(width: 9),
                Text(
                  'غنائمك',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _big('$usable', 'غنيمة متاحة'),
                const SizedBox(width: 26),
                _big('$_totalReach', 'مشاهدة'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'كل غنيمة تصل لجمهور من هزمتَه في النزال',
              style: TextStyle(
                fontSize: 12,
                height: 1.7,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _big(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1.2,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: 1.6,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, Spoil s) {
    final t = Theme.of(context).textTheme;
    final soon = s.isUsable && s.daysLeft <= 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: s.isUsable
                ? const Color(0xFFD4A017).withOpacity(0.55)
                : AppColors.border,
            width: 1.4,
          ),
          color: s.isUsable
              ? const Color(0xFFD4A017).withOpacity(0.04)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarCircle(
                  initial: s.loserInitial,
                  seed: s.loserSeed,
                  imageUrl: s.loserAvatar,
                  size: 40,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'غنيمة من ${s.loserName}',
                        style: t.titleMedium?.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(atHandle(s.loserHandle), style: t.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: s.status.color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    s.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      fontWeight: FontWeight.w700,
                      color: s.status.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _chip(
                  context,
                  icon: Icons.visibility_outlined,
                  label: '${s.reach} مشاهدة',
                  color: const Color(0xFFD4A017),
                ),
                const SizedBox(width: 8),
                _chip(
                  context,
                  icon: Icons.schedule,
                  label: s.timeLeftLabel,
                  color: soon ? AppColors.like : AppColors.textMuted,
                ),
              ],
            ),
            if (s.isUsable) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _button(
                      context,
                      'استخدمها',
                      filled: true,
                      onTap: () => _snack(
                        'اضغط زر النشر واختر «انشر بغنيمة»',
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _button(
                      context,
                      'اعرضها للبيع',
                      filled: false,
                      onTap: () => _snack('سوق الغنائم قريبًا'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context,
    String label, {
    required bool filled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: filled ? const Color(0xFFD4A017) : AppColors.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 39,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: filled ? Colors.transparent : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.16),
        Center(
          child: Column(
            children: [
              const Text('⚔️', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 14),
              Text(
                'لا تملك غنائم بعد',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 38),
                child: Text(
                  'افـز في نزال، تكسب منشورًا يصل لجمهور خصمك.\n'
                  'شرط المنح: ٢٠ مصوّتًا فأكثر.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
