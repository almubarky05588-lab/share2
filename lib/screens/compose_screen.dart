import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';

/// اقتراح منشن أثناء الكتابة
class _MentionSuggestion {
  const _MentionSuggestion({
    required this.name,
    required this.handle,
    this.verified = false,
  });

  final String name;
  final String handle;
  final bool verified;
}

/// نشر جديد (share) — الشاشة ٦ من التصميم
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  static const _maxLength = 280;

  final _controller = TextEditingController();

  static const _suggestions = <_MentionSuggestion>[
    _MentionSuggestion(
      name: 'نورة السالم',
      handle: 'noura_s',
      verified: true,
    ),
    _MentionSuggestion(
      name: 'استوديو مِداد',
      handle: 'midad.studio',
      verified: true,
    ),
    _MentionSuggestion(name: 'نايف الشمري', handle: 'noor.dev'),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _remaining => _maxLength - _controller.text.characters.length;

  bool get _canShare =>
      _controller.text.trim().isNotEmpty && _remaining >= 0;

  void _insertMention(String handle) {
    final text = _controller.text;
    final needsSpace = text.isNotEmpty && !text.endsWith(' ');
    _controller.text = '$text${needsSpace ? ' ' : ''}@$handle ';
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            _replyScope(context),
            _editor(context),
            const Divider(height: 1, color: AppColors.border),
            _suggestionsHeader(context),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (_, i) => _suggestionTile(context, _suggestions[i]),
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
                onTap: _canShare
                    ? () => Navigator.of(context).maybePop(_controller.text)
                    : null,
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  child: Text(
                    'share',
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
              const Icon(
                Icons.public,
                size: 15,
                color: AppColors.brand,
              ),
              const SizedBox(width: 6),
              Text(
                'الجميع يمكنهم الرد',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 15,
                color: AppColors.brand,
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
              maxLines: 6,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 17,
                  ),
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
          const AvatarCircle(
            initial: 'م',
            seed: AppColors.brand,
            size: AppSizes.avatarLarge,
          ),
        ],
      ),
    );
  }

  Widget _suggestionsHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'اقتراحات المنشن',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 7),
          const Icon(
            Icons.alternate_email,
            size: 15,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _suggestionTile(BuildContext context, _MentionSuggestion s) {
    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => _insertMention(s.handle),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(
              Icons.add,
              size: AppSizes.iconSmall,
              color: AppColors.textMuted,
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.name,
                      style: t.titleMedium?.copyWith(fontSize: 14),
                    ),
                    if (s.verified) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.verified,
                        size: 14,
                        color: AppColors.blue,
                      ),
                    ],
                  ],
                ),
                Text('‎@${s.handle}', style: t.bodySmall),
              ],
            ),
            const SizedBox(width: 10),
            AvatarCircle(
              initial: s.name.characters.first,
              seed: AppColors.brand,
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
              _toolIcon(Icons.location_on_outlined),
              const SizedBox(width: 18),
              _gifChip(context),
              const SizedBox(width: 18),
              _toolIcon(Icons.poll_outlined),
              const SizedBox(width: 18),
              _toolIcon(Icons.camera_alt_outlined),
              const SizedBox(width: 18),
              _toolIcon(Icons.image_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolIcon(IconData icon) {
    return Icon(icon, size: 21, color: AppColors.brand);
  }

  Widget _gifChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.brand, width: 1.4),
      ),
      child: const Text(
        'GIF',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: AppColors.brand,
        ),
      ),
    );
  }
}
