import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_profile.dart';
import '../services/push_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';
import 'auth_screen.dart';

/// الإعدادات وتعديل الملف الشخصي
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// روابط السياسات
  static const _privacyUrl =
      'https://share-admin-panel.netlify.app/privacy.html';
  static const _termsUrl =
      'https://share-admin-panel.netlify.app/terms.html';

  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _bio = TextEditingController();
  final _location = TextEditingController();
  final _website = TextEditingController();

  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;
  bool _changed = false;
  String? _avatarUrl;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _bio.dispose();
    _location.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SupabaseService.instance.fetchMyProfile();
    if (!mounted) return;

    setState(() {
      _profile = p;
      _avatarUrl = p?.avatarUrl;
      _coverUrl = p?.coverUrl;
      _name.text = p?.name ?? '';
      _handle.text = p?.handle ?? '';
      _bio.text = p?.bio ?? '';
      _location.text = p?.location ?? '';
      _website.text = p?.website ?? '';
      _loading = false;
    });
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);

    try {
      final url =
          await SupabaseService.instance.uploadAvatar(File(picked.path));
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _changed = true;
      });
      _snack('تم تحديث الصورة');
    } catch (_) {
      _snack('تعذّر رفع الصورة');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _pickCover() async {
    if (_uploadingCover) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingCover = true);

    try {
      final url =
          await SupabaseService.instance.uploadCover(File(picked.path));
      if (!mounted) return;
      setState(() {
        _coverUrl = url;
        _changed = true;
      });
      _snack('تم تحديث الغلاف');
    } catch (_) {
      _snack('تعذّر رفع الغلاف');
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _name.text.trim();
    final handle = _handle.text.trim().replaceAll('@', '').toLowerCase();

    if (name.isEmpty) {
      _snack('الاسم لا يمكن أن يكون فارغًا');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9._]{3,20}$').hasMatch(handle)) {
      _snack('المعرّف: حروف إنجليزية وأرقام و . _ فقط، من 3 إلى 20');
      return;
    }

    setState(() => _saving = true);

    try {
      if (handle != _profile?.handle) {
        final free = await SupabaseService.instance.isHandleAvailable(handle);
        if (!free) {
          _snack('المعرّف محجوز، اختر غيره');
          setState(() => _saving = false);
          return;
        }
      }

      await SupabaseService.instance.updateProfile(
        name: name,
        handle: handle,
        bio: _bio.text.trim(),
        location: _location.text.trim(),
        website: _website.text.trim(),
      );

      if (!mounted) return;
      _changed = true;
      _snack('تم الحفظ');
      Navigator.of(context).pop(true);
    } catch (_) {
      _snack('تعذّر الحفظ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeEmail() async {
    final controller =
        TextEditingController(text: SupabaseService.instance.currentEmail);

    final newEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير البريد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(hintText: 'البريد الجديد'),
            ),
            const SizedBox(height: 12),
            Text(
              'ستصلك رسالة تأكيد على البريد الجديد، ولن يتغيّر قبل تأكيدها.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );

    if (newEmail == null || newEmail.isEmpty) return;
    if (newEmail == SupabaseService.instance.currentEmail) return;

    try {
      await SupabaseService.instance.changeEmail(newEmail);
      _snack('أُرسلت رسالة التأكيد إلى $newEmail');
    } catch (_) {
      _snack('تعذّر تغيير البريد');
    }
  }

  /// تغيير كلمة المرور
  Future<void> _changePassword() async {
    final pass1 = TextEditingController();
    final pass2 = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pass1,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration:
                  const InputDecoration(hintText: 'كلمة المرور الجديدة'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pass2,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(hintText: 'أعد كتابتها'),
            ),
            const SizedBox(height: 12),
            Text(
              'يجب ألا تقل عن ٦ أحرف',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    if (pass1.text.length < 6) {
      _snack('كلمة المرور قصيرة');
      return;
    }
    if (pass1.text != pass2.text) {
      _snack('الكلمتان غير متطابقتين');
      return;
    }

    try {
      await SupabaseService.instance.changePassword(pass1.text);
      _snack('تم تغيير كلمة المرور');
    } catch (_) {
      _snack('تعذّر تغيير كلمة المرور');
    }
  }

  Future<void> _openBlocked() async {
    final blocked = await SupabaseService.instance.fetchBlockedUsers();
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: blocked.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(34),
                child: Center(
                  child: Text(
                    'لا يوجد محظورون',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 14),
                children: blocked
                    .map(
                      (u) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              AvatarCircle(
                                initial: u.initial,
                                seed: u.avatarSeed,
                                imageUrl: u.avatarUrl,
                                size: 42,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(u.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontSize: 15)),
                                    Text('‎@${u.handle}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await SupabaseService.instance
                                      .setBlock(u.id, false);
                                  if (!ctx.mounted) return;
                                  Navigator.of(ctx).pop();
                                  _snack('أُلغي حظر ${u.name}');
                                },
                                child: const Text('إلغاء الحظر'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// حذف الحساب نهائيًا
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'سيُحذف حسابك ومنشوراتك ونزالاتك ورسائلك نهائيًا، '
          'ولا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('متابعة',
                style: TextStyle(color: AppColors.like)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // تأكيد ثانٍ بكتابة كلمة
    final field = TextEditingController();
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد أخير'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اكتب كلمة «حذف» للتأكيد'),
            const SizedBox(height: 12),
            TextField(
              controller: field,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: 'حذف'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(field.text.trim() == 'حذف'),
            child: const Text('حذف نهائيًا',
                style: TextStyle(color: AppColors.like)),
          ),
        ],
      ),
    );

    if (sure != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      ),
    );

    try {
      await PushService.instance.unregisterDevice();
      await SupabaseService.instance.deleteMyAccount();

      if (!mounted) return;
      Navigator.of(context).pop();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack('تعذّر حذف الحساب، حاول لاحقًا');
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('خروج', style: TextStyle(color: AppColors.like)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await PushService.instance.unregisterDevice();
    await SupabaseService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإعدادات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => Navigator.of(context).pop(_changed),
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _coverAndAvatar(context, p),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    children: [
                      _label(context, 'الاسم'),
                      _field(_name, 'اسمك الظاهر'),
                      const SizedBox(height: 16),
                      _label(context, 'المعرّف'),
                      _field(_handle, 'بدون @',
                          direction: TextDirection.ltr),
                      const SizedBox(height: 16),
                      _label(context, 'النبذة'),
                      _field(_bio, 'اكتب نبذة قصيرة عنك', maxLines: 3),
                      const SizedBox(height: 16),
                      _label(context, 'الموقع'),
                      _field(_location, 'المدينة، الدولة'),
                      const SizedBox(height: 16),
                      _label(context, 'الموقع الإلكتروني'),
                      _field(
                        _website,
                        'example.com',
                        direction: TextDirection.ltr,
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 28),
                      Material(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(26),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(26),
                          onTap: _saving ? null : _save,
                          child: Container(
                            height: 50,
                            alignment: Alignment.center,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.background,
                                    ),
                                  )
                                : const Text(
                                    'حفظ التغييرات',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.background,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // ── الحساب ──
                      _sectionLabel(context, 'الحساب'),
                      const Divider(color: AppColors.border),
                      _rowItem(
                        context,
                        icon: Icons.mail_outline,
                        label: 'تغيير البريد',
                        value: SupabaseService.instance.currentEmail,
                        onTap: _changeEmail,
                      ),
                      const Divider(color: AppColors.border),
                      _rowItem(
                        context,
                        icon: Icons.lock_outline,
                        label: 'تغيير كلمة المرور',
                        onTap: _changePassword,
                      ),
                      const Divider(color: AppColors.border),
                      _rowItem(
                        context,
                        icon: Icons.block,
                        label: 'الحسابات المحظورة',
                        onTap: _openBlocked,
                      ),

                      const SizedBox(height: 22),

                      // ── عن التطبيق ──
                      _sectionLabel(context, 'عن التطبيق'),
                      const Divider(color: AppColors.border),
                      _rowItem(
                        context,
                        icon: Icons.privacy_tip_outlined,
                        label: 'سياسة الخصوصية',
                        onTap: () => _openUrl(_privacyUrl),
                      ),
                      const Divider(color: AppColors.border),
                      _rowItem(
                        context,
                        icon: Icons.description_outlined,
                        label: 'شروط الاستخدام',
                        onTap: () => _openUrl(_termsUrl),
                      ),

                      const SizedBox(height: 22),

                      // ── مغادرة ──
                      const Divider(color: AppColors.border),
                      _rowItem(
                        context,
                        icon: Icons.logout,
                        label: 'تسجيل الخروج',
                        color: AppColors.like,
                        onTap: _signOut,
                      ),
                      const Divider(color: AppColors.border),
                      _rowItem(
                        context,
                        icon: Icons.delete_forever_outlined,
                        label: 'حذف الحساب',
                        color: AppColors.like,
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// الغلاف مع الصورة الشخصية فوقه
  Widget _coverAndAvatar(BuildContext context, UserProfile? p) {
    return SizedBox(
      height: 130 + 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: _pickCover,
            child: Container(
              height: 130,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: _coverUrl == null ? AppTheme.brandGradient : null,
                image: _coverUrl == null
                    ? null
                    : DecorationImage(
                        image: NetworkImage(_coverUrl!),
                        fit: BoxFit.cover,
                      ),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: _uploadingCover
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.photo_camera_outlined,
                        color: Colors.white, size: 21),
              ),
            ),
          ),
          Positioned(
            top: 130 - 44,
            right: 20,
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: AvatarCircle(
                    initial: p?.initial ?? '؟',
                    seed: p?.avatarSeed ?? AppColors.brand,
                    imageUrl: _avatarUrl,
                    size: 84,
                  ),
                ),
                Material(
                  color: AppColors.brand,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _pickAvatar,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: _uploadingAvatar
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : const Icon(Icons.camera_alt,
                              size: 16, color: AppColors.background),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4, right: 2),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
        ),
      ),
    );
  }

  Widget _rowItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? value,
    Color color = AppColors.text,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 15, color: color),
            ),
            const Spacer(),
            if (value != null)
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, right: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextDirection direction = TextDirection.rtl,
    TextInputType? keyboardType,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        textDirection: direction,
        textAlign: TextAlign.right,
        keyboardType: keyboardType,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintText: hint,
          hintStyle: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
