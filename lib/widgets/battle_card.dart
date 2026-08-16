import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/battle.dart';
import '../models/spoil.dart';
import '../services/battle_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/handle_text.dart';
import 'avatar_circle.dart';

/// ذاكرة أصوات الجلسة
class BattleVoteMemory {
  BattleVoteMemory._();
  static final Map<String, String> votes = {};
  static final Set<String> changed = {};
}

/// بطاقة نزال
class BattleCard extends StatefulWidget {
  const BattleCard({
    super.key,
    required this.battle,
    this.onOpenProfile,
    this.onChanged,
    this.showArguments = true,
    this.featured = false,
  });

  final Battle battle;
  final void Function(String userId)? onOpenProfile;
  final VoidCallback? onChanged;
  final bool showArguments;

  /// بطاقة النزال الساخن المتصدرة
  final bool featured;

  @override
  State<BattleCard> createState() => _BattleCardState();
}

class _BattleCardState extends State<BattleCard>
    with TickerProviderStateMixin {
  static const _red = Color(0xFFE0455C);
  static const _blue = Color(0xFF2F6BFF);

  late Battle _b = _withMemory(widget.battle);
  Timer? _tick;
  bool _busy = false;

  List<BattleArgument> _args = const [];
  int _myPower = 1;

  /// نبض اللحظات الحرجة وتوهج المتقدم
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  /// اهتزاز البطاقة عند الضربة
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// رقم القوة الطائر بعد الضربة
  int _flyTick = 0;
  int _flyPower = 0;
  Color _flyColor = _red;

  static Battle _withMemory(Battle b) {
    if (b.myVote != null) {
      BattleVoteMemory.votes[b.id] = b.myVote!;
      return b;
    }
    final saved = BattleVoteMemory.votes[b.id];
    return saved == null ? b : b.copyWith(myVote: saved);
  }

  /// آخر ٣٠ دقيقة من نزال نشط
  bool get _urgent =>
      _b.isActive &&
      _b.endsAt != null &&
      _b.remaining.inMinutes < 30;

  @override
  void initState() {
    super.initState();
    _loadExtras();

    if (_b.isActive) {
      _tick = Timer.periodic(
        const Duration(seconds: 1),
        (_) => mounted ? setState(() {}) : null,
      );
    }
  }

  Future<void> _loadExtras() async {
    final power = await BattleService.instance.myStrikePower();
    List<BattleArgument> args = const [];

    if (widget.showArguments) {
      try {
        args = await BattleService.instance.fetchArguments(_b.id);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _myPower = power;
      _args = args;
    });
  }

  @override
  void didUpdateWidget(covariant BattleCard old) {
    super.didUpdateWidget(old);
    if (old.battle.id != widget.battle.id ||
        old.battle.totalVotes != widget.battle.totalVotes) {
      _b = _withMemory(widget.battle);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    _shake.dispose();
    super.dispose();
  }

  bool get _isParty {
    final me = SupabaseService.instance.currentUserId;
    return me == _b.challenger.userId || me == _b.opponent.userId;
  }

  bool get _canChange =>
      _b.voted &&
      _b.isActive &&
      !_isParty &&
      !BattleVoteMemory.changed.contains(_b.id);

  /// يفتح رابط مصدر في المتصفح
  Future<void> _openUrl(String url) async {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }

    final uri = Uri.tryParse(u);
    if (uri == null) {
      _snack('الرابط غير صالح');
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('تعذّر فتح الرابط');
  }

  /// اهتزاز + رقم طائر
  void _strikeFx(String side) {
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
    setState(() {
      _flyTick++;
      _flyPower = _myPower;
      _flyColor = side == 'challenger' ? _red : _blue;
    });
  }

  Future<void> _vote(String side) async {
    if (_busy || !_b.isActive || _isParty) return;

    // تغيير الصوت
    if (_b.voted) {
      if (!_canChange || _b.myVote == side) return;
      return _change(side);
    }

    setState(() => _busy = true);

    try {
      await BattleService.instance.vote(_b.id, side);
      BattleVoteMemory.votes[_b.id] = side;

      if (!mounted) return;
      _strikeFx(side);
      setState(() => _b = _applyVote(side, _myPower));
      widget.onChanged?.call();
    } catch (_) {
      BattleVoteMemory.votes[_b.id] = side;
      if (!mounted) return;
      setState(() => _b = _b.copyWith(myVote: side));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change(String side) async {
    setState(() => _busy = true);

    try {
      await BattleService.instance.changeVote(_b.id, side);
      BattleVoteMemory.votes[_b.id] = side;
      BattleVoteMemory.changed.add(_b.id);

      if (!mounted) return;

      // سحب القوة من القديم وإضافتها للجديد
      final old = _b.myVote!;
      var ch = _b.challenger.votes;
      var op = _b.opponent.votes;

      if (old == 'challenger') {
        ch -= _myPower;
        op += _myPower;
      } else {
        op -= _myPower;
        ch += _myPower;
      }

      _strikeFx(side);
      setState(() {
        _b = _b.copyWith(
          myVote: side,
          challenger: _side(_b.challenger, ch < 0 ? 0 : ch),
          opponent: _side(_b.opponent, op < 0 ? 0 : op),
        );
      });

      _snack('غيّرتَ صوتك');
      widget.onChanged?.call();
    } catch (_) {
      _snack('لا يمكنك تغيير صوتك مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Battle _applyVote(String side, int power) => _b.copyWith(
        myVote: side,
        challenger: side == 'challenger'
            ? _side(_b.challenger, _b.challenger.votes + power)
            : _b.challenger,
        opponent: side == 'opponent'
            ? _side(_b.opponent, _b.opponent.votes + power)
            : _b.opponent,
      );

  BattleSide _side(BattleSide s, int votes) => BattleSide(
        userId: s.userId,
        name: s.name,
        handle: s.handle,
        text: s.text,
        avatarUrl: s.avatarUrl,
        verified: s.verified,
        votes: votes,
      );

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    final showResult = _b.voted || _b.isFinished || _isParty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _shake]),
        builder: (context, child) {
          // اهتزاز أفقي متلاشٍ
          final sv = _shake.value;
          final dx = math.sin(sv * math.pi * 6) * 7 * (1 - sv);

          // توهج الإطار في اللحظات الحرجة
          final glow = _urgent ? 0.25 + _pulse.value * 0.35 : 0.0;

          return Transform.translate(
            offset: Offset(dx, 0),
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: AppSizes.screenPadding,
                vertical: widget.featured ? 12 : 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _urgent
                      ? AppColors.like.withOpacity(0.4 + _pulse.value * 0.4)
                      : widget.featured
                          ? const Color(0xFFFF7A00).withOpacity(0.55)
                          : AppColors.border,
                  width: widget.featured ? 1.8 : 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _urgent
                        ? AppColors.like.withOpacity(glow * 0.5)
                        : widget.featured
                            ? const Color(0xFFFF7A00).withOpacity(0.14)
                            : Colors.black.withOpacity(0.05),
                    blurRadius: _urgent ? 20 : 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Stack(
          children: [
            Column(
              children: [
                _head(context),
                _sideBlock(
                    context, _b.challenger, 'challenger', _red, showResult),
                _vsDivider(context),
                _sideBlock(
                    context, _b.opponent, 'opponent', _blue, showResult),
                if (_args.isNotEmpty) _argumentsBlock(context),
                if (showResult) _result(context) else _hint(context),
              ],
            ),
            // رقم القوة الطائر
            if (_flyPower > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_flyTick),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      onEnd: () {
                        if (mounted) setState(() => _flyPower = 0);
                      },
                      builder: (_, v, __) => Transform.translate(
                        offset: Offset(0, -70 * v),
                        child: Opacity(
                          opacity: (1 - v).clamp(0.0, 1.0),
                          child: Text(
                            '⚡ +$_flyPower',
                            style: TextStyle(
                              fontSize: 26 + v * 8,
                              fontWeight: FontWeight.w900,
                              color: _flyColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
        gradient: widget.featured
            ? LinearGradient(colors: [
                const Color(0xFFFF7A00).withOpacity(0.14),
                _red.withOpacity(0.10),
              ])
            : null,
        color: widget.featured ? null : AppColors.brand.withOpacity(0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
      ),
      child: Row(
        children: [
          if (widget.featured) ...[
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Transform.scale(
                scale: 1 + _pulse.value * 0.18,
                child: const Text('🔥', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'يشتعل الآن',
              style: t.titleMedium?.copyWith(
                fontSize: 14,
                color: const Color(0xFFE05500),
              ),
            ),
          ] else ...[
            const Text('⚔️', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Text(
              'نزال',
              style: t.titleMedium
                  ?.copyWith(fontSize: 14, color: AppColors.brand),
            ),
          ],
          const SizedBox(width: 6),
          Text('· ${_b.topic.label}', style: t.bodySmall),
          const Spacer(),
          if (_b.isActive) ...[
            Icon(Icons.timer_outlined,
                size: 14,
                color: _urgent ? AppColors.like : AppColors.textMuted),
            const SizedBox(width: 4),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Transform.scale(
                scale: _urgent ? 1 + _pulse.value * 0.12 : 1,
                child: Text(
                  _b.countdown,
                  style: t.labelMedium?.copyWith(
                    fontSize: _urgent ? 14 : null,
                    fontWeight: FontWeight.w800,
                    color:
                        _urgent ? AppColors.like : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ] else
            Text('انتهى', style: t.bodySmall),
        ],
      ),
    );
  }

  /// شارة VS متصادمة بخطين ملونين
  Widget _vsDivider(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 2.5,
                  margin: const EdgeInsets.only(right: 14, left: 26),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(colors: [
                      _red.withOpacity(0.08),
                      _red.withOpacity(0.85),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 2.5,
                  margin: const EdgeInsets.only(right: 26, left: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(colors: [
                      _blue.withOpacity(0.85),
                      _blue.withOpacity(0.08),
                    ]),
                  ),
                ),
              ),
            ],
          ),
          Transform.rotate(
            angle: -0.12,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [_red, _blue],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'VS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideBlock(
    BuildContext context,
    BattleSide s,
    String key,
    Color color,
    bool showResult,
  ) {
    final t = Theme.of(context).textTheme;
    final mine = _b.myVote == key;
    final won = _b.isFinished && _b.winnerId == s.userId;

    // الطرف المتقدم في نزال نشط — حده يتوهج
    final leading = _b.isActive &&
        _b.totalVotes > 0 &&
        ((key == 'challenger' && _b.challengerRatio > 0.5) ||
            (key == 'opponent' && _b.challengerRatio < 0.5));

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glowW = leading ? 4.0 + _pulse.value * 2 : 4.0;

        return InkWell(
          onTap: showResult && !_canChange ? null : () => _vote(key),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: mine
                  ? color.withOpacity(0.05)
                  : leading
                      ? color.withOpacity(0.015 + _pulse.value * 0.02)
                      : null,
              border: Border(
                right: BorderSide(color: color, width: glowW),
              ),
            ),
            child: child,
          ),
        );
      },
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
              if (mine && !_b.isFinished)
                Icon(Icons.check_circle, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.text, style: t.bodyMedium?.copyWith(fontSize: 15)),
          if (!showResult) ...[
            const SizedBox(height: 10),
            _voteButton(context, color, key),
          ] else if (_canChange && !mine) ...[
            const SizedBox(height: 10),
            _switchButton(context, color, key),
          ],
        ],
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
          height: 36,
          alignment: Alignment.center,
          width: double.infinity,
          child: _busy
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 15, color: color),
                    const SizedBox(width: 6),
                    Text(
                      'اضرب · $_myPower',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _switchButton(BuildContext context, Color color, String key) {
    return InkWell(
      onTap: _busy ? null : () => _vote(key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 32,
        alignment: Alignment.center,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          'حوّل ضربتي هنا',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.6,
            color: color,
          ),
        ),
      ),
    );
  }

  /// ردود الطرفين
  Widget _argumentsBlock(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_outlined,
                  size: 15, color: AppColors.textMuted),
              const SizedBox(width: 7),
              Text('الحجج', style: t.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          ..._args.map((a) => _argument(context, a)),
        ],
      ),
    );
  }

  Widget _argument(BuildContext context, BattleArgument a) {
    final t = Theme.of(context).textTheme;
    final color = a.side == 'challenger' ? _red : _blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border(right: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.body, style: t.bodyMedium?.copyWith(fontSize: 14)),
          if (a.hasSources) ...[
            const SizedBox(height: 7),
            ...a.sources.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: InkWell(
                  onTap: () => _openUrl(s),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 2, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link, size: 13, color: color),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            BattleArgument.hostOf(s),
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall?.copyWith(
                              color: color,
                              decoration: TextDecoration.underline,
                              decorationColor: color.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(a.timeAgo, style: t.bodySmall?.copyWith(fontSize: 11)),
        ],
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
            'اضرب لترى النتيجة',
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
          // شريط النسبة — ينزلق بنعومة عند كل تغيّر
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: ratio),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: (v * 1000).round().clamp(1, 999),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _red,
                            _red.withOpacity(0.75),
                          ]),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: ((1 - v) * 1000).round().clamp(1, 999),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _blue.withOpacity(0.75),
                            _blue,
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('$chPct٪',
                  style: t.labelMedium
                      ?.copyWith(color: _red, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${_b.totalVotes} قوة', style: t.bodySmall),
              const Spacer(),
              Text('${100 - chPct}٪',
                  style: t.labelMedium
                      ?.copyWith(color: _blue, fontWeight: FontWeight.w700)),
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
