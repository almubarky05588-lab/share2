import 'package:flutter/material.dart';

import '../models/battle.dart';
import '../models/jump.dart';
import '../services/battle_service.dart';
import '../theme/app_theme.dart';
import '../widgets/rank_badge.dart';

/// موجاتي — المنشور الذي يصل لجمهور واسع
class WavesScreen extends StatefulWidget {
  const WavesScreen({super.key});

  @override
  State<WavesScreen> createState() => _WavesScreenState();
}

class _WavesScreenState extends State<WavesScreen> {
  bool _loading = true;
  List<Jump> _waves = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final list = await BattleService.instance.fetchMyJumps();
      if (!mounted) return;
      setState(() {
        _waves = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
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
      appBar: AppBar(
        title: const Text('موجاتي 🌊'),
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
              child: _waves.isEmpty ? _empty(context) : _list(context),
            ),
    );
  }

  Widget _list(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _intro(context),
        const SizedBox(height: 16),
        ..._waves.map((w) => _waveCard(context, w)),
      ],
    );
  }

  Widget _intro(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.brand.withOpacity(0.1),
              const Color(0xFF2F6BFF).withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🌊', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'ما هي الموجة؟',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 15, color: AppColors.brand),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'منشور واحد يصل لجمهور واسع خارج متابعيك. تُمنح عند بلوغ '
              'رتبة نينجا فما فوق، ويمكنك استخدامها أو إهداؤها أو عرضها للبيع.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _waveCard(BuildContext context, Jump w) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: w.isUsable
                ? AppColors.brand.withOpacity(0.5)
                : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // الرأس
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: w.isUsable
                    ? const LinearGradient(
                        colors: [Color(0xFF5B63E0), Color(0xFF2F6BFF)],
                      )
                    : null,
                color: w.isUsable ? null : AppColors.border.withOpacity(0.4),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Text(
                    '🌊 موجة',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: w.isUsable
                          ? AppColors.background
                          : AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: w.isUsable
                          ? Colors.white.withOpacity(0.22)
                          : w.status.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      w.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        fontWeight: FontWeight.w700,
                        color: w.isUsable
                            ? AppColors.background
                            : w.status.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // التفاصيل
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row(
                    context,
                    icon: Icons.people_outline,
                    label: 'الوصول',
                    value: w.reachLabel,
                  ),
                  const SizedBox(height: 10),
                  _row(
                    context,
                    icon: w.grantedRank.icon,
                    label: 'مُنحت عند',
                    value: w.grantedRank.label,
                    color: w.grantedRank.color,
                  ),
                  const SizedBox(height: 10),
                  _row(
                    context,
                    icon: Icons.schedule,
                    label: 'تنتهي خلال',
                    value: w.isExpired ? 'انتهت' : '${w.daysLeft} يومًا',
                    color: w.daysLeft <= 5 ? AppColors.like : null,
                  ),

                  if (w.isUsable) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _filledButton(
                            context,
                            'استخدمها الآن',
                            onTap: () => _snack(
                              'اكتب منشورك ثم اختر «انشر بموجة»',
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _outlinedButton(
                            context,
                            'اعرضها للبيع',
                            onTap: () => _snack('سوق الموجات قريبًا'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    final t = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 17, color: color ?? AppColors.textMuted),
        const SizedBox(width: 9),
        Text(label, style: t.bodySmall),
        const Spacer(),
        Text(
          value,
          style: t.titleMedium?.copyWith(
            fontSize: 14,
            color: color ?? AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _filledButton(BuildContext context, String label,
      {required VoidCallback onTap}) {
    return Material(
      color: AppColors.brand,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.background,
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlinedButton(BuildContext context, String label,
      {required VoidCallback onTap}) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Center(
          child: Column(
            children: [
              const Text('🌊', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 14),
              Text(
                'لا تملك موجات بعد',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _intro(context),
        const SizedBox(height: 16),
        _howToCard(context),
        const SizedBox(height: 16),
        _whatCanIDoCard(context),
      ],
    );
  }

  /// دليل الحصول على موجة
  Widget _howToCard(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'كيف أحصل على موجة؟',
              style: t.titleMedium?.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 14),
            _step(context, '١', 'شارك في النزالات ⚔️',
                'تحدَّ الآخرين أو اقبل تحدياتهم في المواضيع التي تجيدها.'),
            _step(context, '٢', 'اجمع النقاط',
                'كل فوز في نزال يمنحك نقاطًا ترفع رتبتك.'),
            _step(context, '٣', 'ابلغ رتبة نينجا ⚡',
                'عند وصولك ١٢٠ نقطة تُمنح موجتك الأولى تلقائيًا. '
                'رتبتا ساموراي والوحش تمنحان موجات أيضًا.'),
            _step(context, '٤', 'استلم موجتك هنا',
                'ستظهر في هذه الشاشة جاهزة للاستخدام قبل انتهاء صلاحيتها.',
                last: true),
            const SizedBox(height: 14),
            const Center(
              child: RankBadge(rank: BattleRank.ninja, withLabel: true),
            ),
          ],
        ),
      ),
    );
  }

  /// ماذا أفعل بالموجة
  Widget _whatCanIDoCard(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.brand.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ماذا أفعل بالموجة؟',
              style: t.titleMedium?.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 12),
            _useRow(context, Icons.campaign_outlined, 'انشر بها',
                'منشورك يصل لجمهور واسع خارج دائرة متابعيك.'),
            _useRow(context, Icons.card_giftcard_outlined, 'أهدِها',
                'أرسلها لصديق يستفيد منها بدلًا عنك.'),
            _useRow(context, Icons.storefront_outlined, 'اعرضها للبيع',
                'اعرضها في السوق واتفق مع المشتري مباشرة.',
                last: true),
          ],
        ),
      ),
    );
  }

  Widget _step(
    BuildContext context,
    String num,
    String title,
    String body, {
    bool last = false,
  }) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              num,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.brand,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium?.copyWith(fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(body, style: t.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _useRow(
    BuildContext context,
    IconData icon,
    String title,
    String body, {
    bool last = false,
  }) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium?.copyWith(fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(body, style: t.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
