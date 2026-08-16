import 'dart:async';

import 'package:flutter/material.dart';

import '../models/battle.dart';
import '../services/battle_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/handle_text.dart';
import 'avatar_circle.dart';

/// بطاقة نزال — عمودية مع خط ملوّن لكل طرف
class BattleCard extends StatefulWidget {
  const BattleCard({
    super.key,
    required this.battle,
    this.onOpenProfile,
    this.onChanged,
  });

  final Battle battle;
  final void Function(String userId)? onOpenProfile;
  final VoidCallback? onChanged;

  @override
  State<BattleCard> createState() => _BattleCardState();
}

class _BattleCardState extends State<BattleCard> {
  static const _red = Color(0xFFE0455C);
  static const _blue = Color(0xFF2F6BFF);

  late Battle _b = widget.battle;
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_b.isActive) {
      _tick = Timer.periodic(
        const Duration(seconds: 1),
        (_) => mounted ? setState(() {}) : null,
      );
    }
  }

  @override
  void didUpdateWidget(covariant BattleCard old) {
    super.didUpdateWidget(old);
    if (old.battle.id != widget.battle.id) _b = widget.battle;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool get _isParty {
    final me = SupabaseService.instance.currentUserId;
    return me == _b.challenger.userId || me == _b.opponent.userId;
  }

  Future<void> _vote(String side) async {
    if (_busy || _b.voted || !_b.isActive || _isParty) return;

    setState(() => _busy = true);

    try {
      await BattleService.instance.vote(_b.id, side);
      if (!mounted) return;

      setState(() {
        _b = _b.copyWith(
          myVote: side,
          challenger: side == 'challenger'
              ? BattleSide(
                  userId: _b.challenger.userId,
                  name: _b.challenger.name,
                  handle: _b.challenger.handle,
                  text: _b.challenger.text,
                  avatarUrl: _b.challenger.avatarUrl,
                  verified: _b.challenger.verified,
                  votes: _b.challenger.votes + 1,
                )
              : _b.challenger,
          opponent: side == 'opponent'
              ? BattleSide(
                  userId: _b.opponent.userId,
                  name: _b.opponent.name,
                  handle: _b.opponent.handle,
                  text: _b.opponent.text,
                  avatarUrl: _b.opponent.avatarUrl,
                  verified: _b.opponent.verified,
                  votes: _b.opponent.votes + 1,
                )
              : _b.opponent,
        );
      });

      widget.onChanged?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر التصويت')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showResult = _b.voted || _b.isFinished || _isParty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.screenPadding,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _head(context),
            _side(context, _b.challenger, 'challenger', _red, showResult),
            _divider(context),
            _side(context, _b.opponent, 'opponent', _blue, showResult),
            if (showResult) _result(context) else _hint(context),
          ],
        ),
      ),
    );
  }

  Widget _head(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.brand.withOpacity(0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
      ),
      child: Row(
        children: [
          const Text('⚔️', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 7),
          Text(
            'نزال',
            style: t.titleMedium?.copyWith(
              fontSize: 14,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: 6),
          Text('· ${_b.topic.label}', style: t.bodySmall),
          const Spacer(),
          if (_b.isActive) ...[
            const Icon(Icons.timer_outlined,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              _b.countdown,
              style: t.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: _b.remaining.inMinutes < 30
                    ? AppColors.like
                    : AppColors.textMuted,
              ),
            ),
          ] else
            Text('انتهى', style: t.bodySmall),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1, color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            'ضد',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const Expanded(child: Divider(height: 1, color: AppColors.border)),
      ],
    );
  }

  Widget _side(
    BuildContext context,
    BattleSide s,
    String key,
    Color color,
    bool showResult,
  ) {
    final t = Theme.of(context).textTheme;
    final mine = _b.myVote == key;
    final won = _b.isFinished && _b.winnerId == s.userId;

    return InkWell(
      onTap: showResult ? null : () => _vote(key),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: mine ? color.withOpacity(0.05) : null,
          border: Border(
            right: BorderSide(color: color, width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => widget.onOpenProfile?.call(s.userId),
                  child: AvatarCircle(
                    initial: s.initial,
                    seed: color,
                    imageUrl: s.avatarUrl,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    children: [
                      Text(s.name,
                          style: t.titleMedium?.copyWith(fontSize: 14)),
                      if (s.verified)
                        const Icon(Icons.verified,
                            size: 13, color: AppColors.blue),
                      Text(atHandle(s.handle), style: t.bodySmall),
                    ],
                  ),
                ),
                if (won)
                  const Icon(Icons.emoji_events,
                      size: 20, color: Color(0xFFD4A017)),
              ],
            ),
            const SizedBox(height: 8),
            Text(s.text, style: t.bodyMedium?.copyWith(fontSize: 15)),
            if (!showResult) ...[
              const SizedBox(height: 10),
              _voteButton(context, color, key),
            ],
          ],
        ),
      ),
    );
  }

  Widget _voteButton(BuildContext context, Color color, String key) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _busy ? null : () => _vote(key),
        child: Container(
          height: 34,
          alignment: Alignment.center,
          width: double.infinity,
          child: _busy
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                )
              : Text(
                  'صوّت',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _hint(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            'صوّت لترى النتيجة',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _result(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ratio = _b.challengerRatio;
    final chPct = (ratio * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (ratio * 1000).round().clamp(1, 999),
                    child: Container(color: _red),
                  ),
                  Expanded(
                    flex: ((1 - ratio) * 1000).round().clamp(1, 999),
                    child: Container(color: _blue),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$chPct٪',
                style: t.labelMedium?.copyWith(
                    color: _red, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text('${_b.totalVotes} صوتًا', style: t.bodySmall),
              const Spacer(),
              Text(
                '${100 - chPct}٪',
                style: t.labelMedium?.copyWith(
                    color: _blue, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (_b.isFinished) ...[
            const SizedBox(height: 8),
            Text(
              _b.isTie
                  ? 'انتهى بالتعادل'
                  : 'الفائز: ${_b.winnerId == _b.challenger.userId ? _b.challenger.name : _b.opponent.name}',
              style: t.titleMedium?.copyWith(
                fontSize: 14,
                color: const Color(0xFFD4A017),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
