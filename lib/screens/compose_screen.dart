import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/handle_text.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/rich_compose_field.dart';

/// نشر جديد أو رد على منشور
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key, this.replyTo, this.initialText});

  /// المنشور المردود عليه — إن وُجد
  final Post? replyTo;

  /// نص مبدئي (مثل @معرّف عند المنشن من الملف الشخصي)
  final String? initialText;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  static const _maxLength = 280;

  late final RichComposeController _controller =
      RichComposeController(text: widget.initialText ?? '');
  final _picker = ImagePicker();

  File? _media;
  bool _isVideo = false;
  bool _sending = false;

  UserProfile? _me;

  /// اقتراحات المنشن
  List<UserProfile> _suggestions = const [];
  Timer? _debounce;

  bool get _isReply => widget.replyTo != null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _loadMe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});

    final q = _controller.activeMentionQuery;
    _debounce?.cancel();

    if (q == null) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final me = SupabaseService.instance.currentUserId;
        final users = await SupabaseService.instance.searchUsers(q);
        if (!mounted) return;
        setState(() {
          _suggestions =
              users.where((u) => u.id != me).take(6).toList();
        });
      } catch (_) {}
    });
  }

  Future<void> _loadMe() async {
    final me = await SupabaseService.instance.fetchMyProfile();
    if (!mounted) return;
    setState(() => _me = me);
  }

  int get _remaining => _maxLength - _controller.text.characters.length;

  bool get _canSend =>
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

  Future<void> _submit() async {
    if (!_canSend) return;
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
        replyTo: widget.replyTo?.id,
        mediaUrl: url,
        mediaType: type,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isReply ? 'تعذّر إرسال الرد' : 'تعذّر نشر المنشور'),
        ),
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
                  if (_isReply) _originalPost(context, widget.replyTo!),
                  if (!_isReply) _replyScope(context),
                  _editor(context),
                  if (_suggestions.isNotEmpty) _mentionList(context),
                  if (_media != null) _preview(),
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
        textDirection: TextDirection.rtl,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
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
                          _isReply ? 'رد' : 'share',
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
        ],
      ),
    );
  }

  Widget _originalPost(BuildContext context, Post p) {
    final t = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                AvatarCircle(
                  initial: p.initial,
                  seed: p.avatarSeed,
                  imageUrl: p.avatarUrl,
                  size: 42,
                ),
                const SizedBox(height: 6),
                Container(width: 2, height: 42, color: AppColors.border),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    runSpacing: 2,
                    children: [
                      Text(p.authorName,
                          style: t.titleMedium?.copyWith(fontSize: 14)),
                      if (p.verified)
                        const Icon(Icons.verified,
                            size: 14, color: AppColors.blue),
                      Text(atHandle(p.handle), style: t.bodySmall),
                      Text('· ${p.timeAgo}', style: t.bodySmall),
                    ],
                  ),
                  if (p.body.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(p.body,
                        style: t.bodyMedium?.copyWith(fontSize: 14)),
                  ],
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      style: t.bodySmall,
                      children: [
                        const TextSpan(text: 'ردًّا على '),
                        TextSpan(
                          text: atHandle(p.handle),
                          style:
                              t.bodySmall?.copyWith(color: AppColors.brand),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            textDirection: TextDirection.rtl,
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
      padding: EdgeInsets.fromLTRB(16, _isReply ? 6 : 0, 16, 10),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarCircle(
            initial: _me?.initial ?? 'م',
            seed: AppColors.brand,
            imageUrl: _me?.avatarUrl,
            size: AppSizes.avatarLarge,
          ),
          const SizedBox(width: 12),
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
                hintText: _isReply ? 'اكتب ردّك…' : 'وش يدور في بالك؟',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 17,
                      color: AppColors.textMuted,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// اقتراحات المنشن أثناء الكتابة
  Widget _mentionList(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: _suggestions.map((u) {
          return InkWell(
            onTap: () {
              _controller.completeMention(u.handle);
              setState(() => _suggestions = const []);
            },
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    AvatarCircle(
                      initial: u.initial,
                      seed: u.avatarSeed,
                      imageUrl: u.avatarUrl,
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 5,
                        children: [
                          Text(
                            u.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontSize: 14),
                          ),
                          if (u.verified)
                            const Icon(Icons.verified,
                                size: 13, color: AppColors.blue),
                          Text(atHandle(u.handle),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _preview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                        Icon(Icons.videocam, size: 40, color: Colors.white),
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

  Widget _toolbar(BuildContext context) {
    final over = _remaining < 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          _toolIcon(Icons.image_outlined, _pickImage),
          const SizedBox(width: 20),
          _toolIcon(Icons.camera_alt_outlined, _pickCamera),
          const SizedBox(width: 20),
          _toolIcon(Icons.videocam_outlined, _pickVideo),
          const Spacer(),
          Text(
            '$_remaining',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: over ? AppColors.like : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
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
