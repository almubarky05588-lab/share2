import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';

/// نتيجة النشر — تُعاد إلى الهيكل
class ComposeResult {
  const ComposeResult({
    required this.body,
    this.mediaFile,
  });

  final String body;
  final File? mediaFile;
}

/// نشر جديد (share)
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key, this.replyTo});

  /// معرّف المنشور عند الرد
  final String? replyTo;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  static const _maxLength = 280;

  final _controller = TextEditingController();
  final _picker = ImagePicker();

  File? _media;
  bool _isVideo = false;
  bool _sending = false;

  UserProfile? _me;
  List<UserProfile> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _loadMe();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    final me = await SupabaseService.instance.fetchMyProfile();
    if (!mounted) return;
    setState(() => _me = me);
  }

  Future<void> _loadSuggestions() async {
    final users = await SupabaseService.instance.searchUsers('');
    if (!mounted) return;
    setState(() => _suggestions = users.take(5).toList());
  }

  int get _remaining => _maxLength - _controller.text.characters.length;

  bool get _canShare =>
      (_controller.text.trim().isNotEmpty || _media != null) &&
      _remaining >= 0 &&
      !_sending;

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 88,
    );
    if (x == null) return;
    setState(() {
      _media = File(x.path);
      _isVideo = false;
    });
  }

  Future<void> _pickCamera() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      imageQuality: 88,
    );
    if (x == null) return;
    setState(() {
      _media = File(x.path);
      _isVideo = false;
    });
  }

  Future<void> _pickVideo() async {
    final x = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (x == null) return;
    setState(() {
      _media = File(x.path);
      _isVideo = true;
    });
  }

  void _insertMention(String handle) {
    final text = _controller.text;
    final needsSpace = text.isNotEmpty && !text.endsWith(' ');
    _controller.text = '$text${needsSpace ? ' ' : ''}@$handle ';
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  Future<void> _submit() async {
    if (!_canShare) return;
    setState(() => _sending = true);

    try {
      String? url;
      String? type;

      if (_media != null) {
        final r = await SupabaseService.instance.uploadMedia(_media!);
        url = r.url;
        type = r.type;
      }

      await SupabaseService.instance.createPost(
        _controller.text.trim(),
        replyTo: widget.replyTo,
        mediaUrl: url,
        mediaType: type,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر نشر المنشور')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _replyScope(context),
                  _editor(context),
                  if (_media != null) _preview(),
                  const Divider(height: 24, color: AppColors.border),
                  if (_suggestions.isNotEmpty) ...[
                    _suggestionsHeader(context),
                    ..._suggestions.map((s) => _suggestionTile(context, s)),
                  ],
                ],
              ),
            ),
            _toolbar(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Opacity(
            opacity: _canShare ? 1 : 0.45,
            child: Material(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(19),
              child: InkWell(
                borderRadius: BorderRadius.circular(19),
                onTap: _canShare ? _submit : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 8),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : Text(
                          widget.replyTo == null ? 'share' : 'رد',
                          style: const TextStyle(
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
        ],
      ),
    );
  }

  Widget _replyScope(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.brand.withOpacity(0.08),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public, size: 15, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(
                'الجميع يمكنهم الرد',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editor(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              textAlign: TextAlign.right,
              minLines: 3,
              maxLines: 8,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 17),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'وش يدور في بالك؟',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 17,
                      color: AppColors.textMuted,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AvatarCircle(
            initial: _me?.initial ?? 'م',
            seed: AppColors.brand,
            imageUrl: _me?.avatarUrl,
            size: AppSizes.avatarLarge,
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedia),
            child: _isVideo
                ? Container(
                    height: 200,
                    width: double.infinity,
                    color: AppColors.text,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam,
                            size: 40, color: Colors.white),
                        SizedBox(height: 8),
                        Text('فيديو مرفق',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  )
                : Image.file(
                    _media!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _media = null),
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionsHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'اقتراحات المنشن',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 7),
          const Icon(Icons.alternate_email,
              size: 15, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _suggestionTile(BuildContext context, UserProfile s) {
    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => _insertMention(s.handle),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.add,
                size: AppSizes.iconSmall, color: AppColors.textMuted),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.name, style: t.titleMedium?.copyWith(fontSize: 14)),
                    if (s.verified) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified,
                          size: 14, color: AppColors.blue),
                    ],
                  ],
                ),
                Text('‎@${s.handle}', style: t.bodySmall),
              ],
            ),
            const SizedBox(width: 10),
            AvatarCircle(
              initial: s.initial,
              seed: s.avatarSeed,
              imageUrl: s.avatarUrl,
              size: 36,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final over = _remaining < 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$_remaining',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: over ? AppColors.like : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Row(
            children: [
              _toolIcon(Icons.videocam_outlined, _pickVideo),
              const SizedBox(width: 20),
              _toolIcon(Icons.camera_alt_outlined, _pickCamera),
              const SizedBox(width: 20),
              _toolIcon(Icons.image_outlined, _pickImage),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 23, color: AppColors.brand),
      ),
    );
  }
}
