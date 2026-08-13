import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';

/// الإعدادات وتعديل الملف الشخصي
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _location = TextEditingController();

  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _changed = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SupabaseService.instance.fetchMyProfile();
    if (!mounted) return;

    setState(() {
      _profile = p;
      _avatarUrl = p?.avatarUrl;
      _name.text = p?.name ?? '';
      _bio.text = p?.bio ?? '';
      _location.text = p?.location ?? '';
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

  Future<void> _save() async {
    if (_saving) return;

    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('الاسم لا يمكن أن يكون فارغًا');
      return;
    }

    setState(() => _saving = true);

    try {
      await SupabaseService.instance.updateProfile(
        name: name,
        bio: _bio.text.trim(),
        location: _location.text.trim(),
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
            child: const Text('خروج',
                style: TextStyle(color: AppColors.like)),
          ),
        ],
      ),
    );

    if (ok != true) return;

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
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      AvatarCircle(
                        initial: p?.initial ?? '؟',
                        seed: p?.avatarSeed ?? AppColors.brand,
                        imageUrl: _avatarUrl,
                        size: 96,
                      ),
                      Material(
                        color: AppColors.brand,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _pickAvatar,
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: _uploadingAvatar
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.background,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt,
                                    size: 17,
                                    color: AppColors.background),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '‎@${p?.handle ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 26),
                _label(context, 'الاسم'),
                _field(_name, 'اسمك الظاهر'),
                const SizedBox(height: 16),
                _label(context, 'النبذة'),
                _field(_bio, 'اكتب نبذة قصيرة عنك', maxLines: 3),
                const SizedBox(height: 16),
                _label(context, 'الموقع'),
                _field(_location, 'المدينة، الدولة'),
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
                const SizedBox(height: 30),
                const Divider(color: AppColors.border),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _signOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'تسجيل الخروج',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppColors.like),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.logout,
                            size: 19, color: AppColors.like),
                      ],
                    ),
                  ),
                ),
              ],
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
        textAlign: TextAlign.right,
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
