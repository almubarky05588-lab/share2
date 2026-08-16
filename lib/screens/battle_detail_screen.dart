import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/battle.dart';
import '../models/spoil.dart';
import '../services/battle_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/handle_text.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/battle_card.dart';
import 'media_viewer_screen.dart';
import 'profile_screen.dart';

/// شاشة النزال — الحجج والمصادر والوسائط
class BattleDetailScreen extends StatefulWidget {
  const BattleDetailScreen({super.key, required this.battle});

  final Battle battle;

  @override
  State<BattleDetailScreen> createState() => _BattleDetailScreenState();
}

class _BattleDetailScreenState extends State<BattleDetailScreen> {
  static const _red = Color(0xFFE0455C);
  static const _blue = Color(0xFF2F6BFF);
  static const _maxArgs = 3;

  late Battle _b = widget.battle;
  List<BattleArgument> _args = const [];
  int _myArgs = 0;
  bool _loading = true;

  RealtimeChannel? _channel;

  String? get _mySide {
    final me = SupabaseService.instance.currentUserId;
    if (me == _b.challenger.userId) return 'challenger';
    if (me == _b.opponent.userId) return 'opponent';
    return null;
  }

  bool get _canArgue => _mySide != null && _b.isActive && _myArgs < _maxArgs;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = BattleService.instance.watchArguments(_load);
  }

  @override
  void dispose() {
    final c = _channel;
    if (c != null) BattleService.instance.unwatch(c);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final args = await BattleService.instance.fetchArguments(_b.id);
      final mine = await BattleService.instance.myArgumentsCount(_b.id);

      if (!mounted) return;
      setState(() {
        _args = args;
        _myArgs = mine;
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

  Future<void> _addArgument() async {
    final side = _mySide;
    if (side == null) return;

    final draft = await showModalBottomSheet<_ArgDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ArgumentSheet(
        remaining: _maxArgs - _myArgs,
        color: side == 'challenger' ? _red : _blue,
      ),
    );

    if (draft == null || !mounted) return;

    _snack('جارٍ الإرسال…');

    try {
      final images = <String>[];
      for (final f in draft.images) {
        images.add(await BattleService.instance.uploadBattleMedia(f));
      }

      String? video;
      if (draft.video != null) {
        video = await BattleService.instance.uploadBattleMedia(draft.video!);
      }

      await BattleService.instance.addArgument(
        battleId: _b.id,
        side: side,
        body: draft.body,
        sources: draft.sources,
        images: images,
        videoUrl: video,
      );

      if (!mounted) return;
      _snack('أُضيفت حجّتك');
      _load();
    } catch (_) {
      _snack('تعذّرت إضافة الحجّة');
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
        title: const Text('النزال ⚔️'),
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
              child: ListView(
                padding: const EdgeInsets.only(bottom: 90),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  BattleCard(
                    battle: _b,
                    onOpenProfile: _openProfile,
                    showArguments: false,
                  ),
                  _section(context),
                ],
              ),
            ),
      floatingActionButton: _canArgue
          ? FloatingActionButton.extended(
              backgroundColor: _mySide == 'challenger' ? _red : _blue,
              foregroundColor: Colors.white,
              onPressed: _addArgument,
              icon: const Icon(Icons.gavel, size: 19),
              label: Text('أضف حجّة · ${_maxArgs - _myArgs}'),
            )
          : null,
    );
  }

  Widget _section(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_outlined,
                    size: 18, color: AppColors.brand),
                const SizedBox(width: 8),
                Text('الحجج والمصادر',
                    style: t.titleMedium?.copyWith(fontSize: 15)),
                const Spacer(),
                Text('${_args.length}', style: t.bodySmall),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'لكل طرف ٣ حجج · مصادر وصور وفيديو',
              style: t.bodySmall?.copyWith(fontSize: 11.5),
            ),
            const SizedBox(height: 14),
            if (_args.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Center(
                  child: Text('لم يضف أحد حجّة بعد', style: t.bodySmall),
                ),
              )
            else
              ..._args.map((a) => _argCard(context, a)),
          ],
        ),
      ),
    );
  }

  Widget _argCard(BuildContext context, BattleArgument a) {
    final t = Theme.of(context).textTheme;
    final isCh = a.side == 'challenger';
    final color = isCh ? _red : _blue;
    final who = isCh ? _b.challenger : _b.opponent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border(right: BorderSide(color: color, width: 3.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarCircle(
                initial: who.initial,
                seed: color,
                imageUrl: who.avatarUrl,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(who.name,
                  style: t.titleMedium?.copyWith(fontSize: 13.5)),
              const SizedBox(width: 5),
              Text(atHandle(who.handle),
                  style: t.bodySmall?.copyWith(fontSize: 11.5)),
              const Spacer(),
              Text(a.timeAgo, style: t.bodySmall?.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Text(a.body, style: t.bodyMedium?.copyWith(fontSize: 14.5)),
          if (a.hasImages) ...[
            const SizedBox(height: 10),
            _imagesGrid(context, a.images),
          ],
          if (a.hasVideo) ...[
            const SizedBox(height: 10),
            _videoTile(context, a.videoUrl!),
          ],
          if (a.hasSources) ...[
            const SizedBox(height: 10),
            ...a.sources.map((s) => _sourceRow(context, s, color)),
          ],
        ],
      ),
    );
  }

  Widget _imagesGrid(BuildContext context, List<String> urls) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: urls.map((u) {
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MediaViewerScreen(url: u, isVideo: false),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              u,
              width: urls.length == 1 ? double.infinity : 96,
              height: urls.length == 1 ? 180 : 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 96,
                height: 96,
                color: AppColors.border,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.textMuted),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _videoTile(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(url: url, isVideo: true),
        ),
      ),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_fill, size: 34, color: Colors.white),
            SizedBox(width: 10),
            Text('فيديو مرفق',
                style: TextStyle(color: Colors.white, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }

  Widget _sourceRow(BuildContext context, String url, Color color) {
    final t = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.link, size: 15, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              BattleArgument.hostOf(url),
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            'مصدر',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// مسوّدة الحجّة
class _ArgDraft {
  const _ArgDraft({
    required this.body,
    required this.sources,
    required this.images,
    this.video,
  });

  final String body;
  final List<String> sources;
  final List<File> images;
  final File? video;
}

/// لوحة كتابة الحجّة
class _ArgumentSheet extends StatefulWidget {
  const _ArgumentSheet({required this.remaining, required this.color});

  final int remaining;
  final Color color;

  @override
  State<_ArgumentSheet> createState() => _ArgumentSheetState();
}

class _ArgumentSheetState extends State<_ArgumentSheet> {
  static const _max = 200;
  static const _maxSources = 3;
  static const _maxImages = 4;

  final _body = TextEditingController();
  final _picker = ImagePicker();

  final List<TextEditingController> _sources = [TextEditingController()];
  final List<File> _images = [];
  File? _video;

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _body.dispose();
    for (final c in _sources) {
      c.dispose();
    }
    super.dispose();
  }

  int get _remaining => _max - _body.text.characters.length;

  bool get _canSend => _body.text.trim().isNotEmpty && _remaining >= 0;

  void _addSourceField() {
    if (_sources.length >= _maxSources) return;
    setState(() => _sources.add(TextEditingController()));
  }

  void _removeSource(int i) {
    if (_sources.length == 1) return;
    setState(() {
      _sources[i].dispose();
      _sources.removeAt(i);
    });
  }

  Future<void> _pickImages() async {
    if (_images.length >= _maxImages) {
      _snack('حد أقصى ٤ صور');
      return;
    }

    final files = await _picker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (files.isEmpty) return;

    setState(() {
      for (final f in files) {
        if (_images.length < _maxImages) _images.add(File(f.path));
      }
    });
  }

  Future<void> _pickVideo() async {
    final x = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (x == null) return;
    setState(() => _video = File(x.path));
  }

  void _snack(String t) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t)));
  }

  void _send() {
    final srcs = _sources
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    Navigator.of(context).pop(
      _ArgDraft(
        body: _body.text.trim(),
        sources: srcs,
        images: _images,
        video: _video,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Icon(Icons.gavel, size: 19, color: widget.color),
                    const SizedBox(width: 9),
                    Text('أضف حجّة',
                        style: t.titleMedium?.copyWith(fontSize: 16)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'باقٍ ${widget.remaining}',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.6,
                          fontWeight: FontWeight.w700,
                          color: widget.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    _textField(context),
                    const SizedBox(height: 16),
                    _label(context, 'المصادر · ${_sources.length}/$_maxSources'),
                    ..._sources.asMap().entries.map(
                          (e) => _sourceField(context, e.key),
                        ),
                    if (_sources.length < _maxSources) _addSourceButton(context),
                    const SizedBox(height: 16),
                    _label(context, 'الوسائط'),
                    _mediaButtons(context),
                    if (_images.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _imagesPreview(),
                    ],
                    if (_video != null) ...[
                      const SizedBox(height: 10),
                      _videoPreview(),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Text(
                      '$_remaining',
                      style: t.labelMedium?.copyWith(
                        color: _remaining < 0
                            ? AppColors.like
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Opacity(
                      opacity: _canSend ? 1 : 0.45,
                      child: Material(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: _canSend ? _send : null,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 30, vertical: 12),
                            child: Text(
                              'أرسل الحجّة',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  Widget _textField(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _body,
        autofocus: true,
        textAlign: TextAlign.right,
        minLines: 3,
        maxLines: 5,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          hintText: 'اكتب حجّتك…',
          hintStyle: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _sourceField(BuildContext context, int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.35),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(Icons.link, size: 16, color: widget.color),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _sources[i],
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              keyboardType: TextInputType.url,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 13.5),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: 'https://…',
                hintStyle: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (_sources.length > 1)
            InkWell(
              onTap: () => _removeSource(i),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close,
                    size: 17, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addSourceButton(BuildContext context) {
    return InkWell(
      onTap: _addSourceField,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: widget.color.withOpacity(0.45),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 17, color: widget.color),
            const SizedBox(width: 6),
            Text(
              'أضف مصدرًا آخر',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.6,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _mediaButton(
            context,
            icon: Icons.image_outlined,
            label: 'صور · ${_images.length}/$_maxImages',
            onTap: _pickImages,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _mediaButton(
            context,
            icon: Icons.videocam_outlined,
            label: _video == null ? 'فيديو' : 'فيديو ✓',
            onTap: _pickVideo,
          ),
        ),
      ],
    );
  }

  Widget _mediaButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.border.withOpacity(0.35),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: widget.color),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.6,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagesPreview() {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: _images.asMap().entries.map((e) {
        return Stack(
          alignment: Alignment.topLeft,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                e.value,
                width: 78,
                height: 78,
                fit: BoxFit.cover,
              ),
            ),
            InkWell(
              onTap: () => setState(() => _images.removeAt(e.key)),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(3),
                child: const Icon(Icons.close,
                    size: 13, color: Colors.white),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _videoPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.text,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam, size: 20, color: Colors.white),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'فيديو مختار',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _video = null),
            child: const Icon(Icons.close, size: 17, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
