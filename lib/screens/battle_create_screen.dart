import 'package:flutter/material.dart';

import '../models/battle.dart';
import '../models/post.dart';
import '../services/battle_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/handle_text.dart';
import '../widgets/avatar_circle.dart';

/// إنشاء تحدٍّ على منشور
class BattleCreateScreen extends StatefulWidget {
  const BattleCreateScreen({super.key, required this.target});

  /// المنشور المتحدَّى
  final Post target;

  @override
  State<BattleCreateScreen> createState() => _BattleCreateScreenState();
}

class _BattleCreateScreenState extends State<BattleCreateScreen> {
  static const _maxLength = 200;

  final _controller = TextEditingController();

  BattleTopic _topic = BattleTopic.general;
  int _hours = 6;
  bool _sending = false;

  BattleRank _rank = BattleRank.rookie;
  int _todayCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final me = await SupabaseService.instance.fetchMyProfile();
    final count = await BattleService.instance.todayBattlesCount();

    if (!mounted) return;
    setState(() {
      _rank = BattleRankInfo.fromPoints(me?.battlePoints ?? 0);
      _todayCount = count;
      _loading = false;
    });
  }

  int get _remaining => _maxLength - _controller.text.characters.length;

  bool get _limitReached => _todayCount >= _rank.dailyLimit;

  bool get _canPickDuration =>
      _rank == BattleRank.ninja ||
      _rank == BattleRank.samurai ||
      _rank == BattleRank.beast;

  bool get _canSend =>
      _controller.text.trim().isNotEmpty &&
      _remaining >= 0 &&
      !_sending &&
      !_limitReached;

  Future<void> _submit() async {
    if (!_canSend) return;
    setState(() => _sending = true);

    try {
      await BattleService.instance.challenge(
        opponentId: widget.target.authorId,
        opponentText: widget.target.body,
        opponentPostId: widget.target.id,
        myText: _controller.text.trim(),
        topic: _topic,
        durationHours: _canPickDuration ? _hours : 6,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إرسال التحدي')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.brand),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          if (_limitReached) _limitNotice(context),
                          _targetPost(context),
                          const SizedBox(height: 16),
                          _label(context, 'ردّك'),
                          _editor(context),
                          const SizedBox(height: 20),
                          _label(context, 'المجال'),
                          _topics(context),
                          const SizedBox(height: 20),
                          _label(context, 'مدة النزال'),
                          _durations(context),
                          const SizedBox(height: 20),
                          _rules(context),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            child: Text(
              'إلغاء',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
            ),
          ),
          const Spacer(),
          Opacity(
            opacity: _canSend ? 1 : 0.45,
            child: Material(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(19),
              child: InkWell(
                borderRadius: BorderRadius.circular(19),
                onTap: _canSend ? _submit : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : const Text(
                          '⚔️ تحدَّ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.55,
                            color: AppColors.background,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _limitNotice(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.like.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 19, color: AppColors.like),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'بلغتَ حدّك اليومي (${_rank.dailyLimit} نزال). ارتقِ لرتبة أعلى لتزيد الحد.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetPost(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = widget.target;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarCircle(
                initial: p.initial,
                seed: p.avatarSeed,
                imageUrl: p.avatarUrl,
                size: 32,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5,
                  children: [
                    Text(p.authorName,
                        style: t.titleMedium?.copyWith(fontSize: 14)),
                    if (p.verified)
                      const Icon(Icons.verified,
                          size: 13, color: AppColors.blue),
                    Text(atHandle(p.handle), style: t.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(p.body, style: t.bodyMedium?.copyWith(fontSize: 15)),
        ],
      ),
    );
  }

  Widget _editor(BuildContext context) {
    final over = _remaining < 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.right,
            minLines: 3,
            maxLines: 6,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'اكتب رأيك المضاد…',
              hintStyle: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '$_remaining',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: over ? AppColors.like : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topics(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BattleTopic.values.map((tp) {
        final active = _topic == tp;

        return InkWell(
          onTap: () => setState(() => _topic = tp),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.brand
                  : AppColors.border.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tp.icon,
                    size: 15,
                    color: active
                        ? AppColors.background
                        : AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  tp.label,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color:
                        active ? AppColors.background : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _durations(BuildContext context) {
    if (!_canPickDuration) {
      return Row(
        children: [
          const Icon(Icons.lock_outline,
              size: 15, color: AppColors.textMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '٦ ساعات · تحديد المدة متاح من رتبة نينجا',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [3, 6, 24].map((h) {
        final active = _hours == h;

        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: InkWell(
            onTap: () => setState(() => _hours = h),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.brand
                    : AppColors.border.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$h ساعات',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.background : AppColors.text,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _rules(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brand.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'كيف يعمل النزال؟',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontSize: 14, color: AppColors.brand),
          ),
          const SizedBox(height: 8),
          _rule(context, 'يصل التحدي للطرف الآخر، ولا يبدأ إلا بقبوله'),
          _rule(context, 'الناس تصوّت، ولا ترى النتيجة قبل التصويت'),
          _rule(context, 'كل نزال يمنحك نقطة، والفوز يمنحك ثلاثًا'),
        ],
      ),
    );
  }

  Widget _rule(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: AppColors.textMuted)),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
