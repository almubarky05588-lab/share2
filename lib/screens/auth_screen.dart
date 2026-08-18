import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

/// تسجيل الدخول وإنشاء حساب
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  /// معرّفات قوقل — تُعبّأ بعد تجهيز Google Cloud
  static const _googleWebClientId = '';
  static const _googleIosClientId = '';

  bool _isSignUp = false;
  bool _busy = false;
  String? _error;

  /// دخل بآبل/قوقل أول مرة — يحتاج اسمًا ومعرّفًا
  bool _needsProfile = false;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _handle = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _handle.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  /// بعد دخول آبل/قوقل: إن وُجد الملف ندخل، وإلا نطلب الاسم والمعرّف
  Future<void> _afterOAuth({String? suggestedName}) async {
    final me = await SupabaseService.instance.fetchMyProfile();
    if (!mounted) return;

    if (me != null) {
      _go();
      return;
    }

    setState(() {
      _needsProfile = true;
      _error = null;
      if (suggestedName != null && suggestedName.trim().isNotEmpty) {
        _name.text = suggestedName.trim();
      }
    });
  }

  /// إنشاء ملف المستخدم بعد دخول آبل/قوقل
  Future<void> _completeProfile() async {
    final name = _name.text.trim();
    final handle =
        _handle.text.trim().replaceAll('@', '').toLowerCase();

    if (name.isEmpty || handle.isEmpty) {
      setState(() => _error = 'أدخل الاسم والمعرّف');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser!.id;

      await client.from('profiles').insert({
        'id': uid,
        'name': name,
        'handle': handle,
      });

      if (!mounted) return;
      _go();
    } on PostgrestException catch (e) {
      setState(() => _error = e.code == '23505'
          ? 'المعرّف مستخدم، جرّب غيره'
          : 'تعذّر إنشاء الملف، حاول مرة أخرى');
    } catch (_) {
      setState(() => _error = 'تعذّر إنشاء الملف، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _nonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// الدخول بحساب آبل
  Future<void> _appleSignIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final rawNonce = _nonce();
      final hashedNonce =
          sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('لم يصل رمز الدخول من آبل');
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (!mounted) return;
      final name = [
        credential.givenName ?? '',
        credential.familyName ?? '',
      ].where((s) => s.isNotEmpty).join(' ');

      await _afterOAuth(suggestedName: name);
    } on SignInWithAppleAuthorizationException catch (e) {
      // المستخدم أغلق النافذة — لا خطأ يعرض
      if (e.code != AuthorizationErrorCode.canceled) {
        setState(() => _error = 'تعذّر الدخول بآبل، حاول مرة أخرى');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر الدخول بآبل، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// الدخول بحساب قوقل
  Future<void> _googleSignIn() async {
    if (_googleWebClientId.isEmpty || _googleIosClientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الدخول بقوقل يتفعّل قريبًا')),
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final googleSignIn = GoogleSignIn(
        clientId: _googleIosClientId,
        serverClientId: _googleWebClientId,
      );

      final user = await googleSignIn.signIn();
      if (user == null) {
        // المستخدم أغلق النافذة
        setState(() => _busy = false);
        return;
      }

      final auth = await user.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      if (idToken == null || accessToken == null) {
        throw const AuthException('لم يصل رمز الدخول من قوقل');
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (!mounted) return;
      await _afterOAuth(suggestedName: user.displayName);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر الدخول بقوقل، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'أدخل البريد وكلمة المرور');
      return;
    }
    if (_isSignUp && (_handle.text.trim().isEmpty || _name.text.trim().isEmpty)) {
      setState(() => _error = 'أدخل الاسم والمعرّف');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        await SupabaseService.instance.signUp(
          email: email,
          password: password,
          handle: _handle.text.trim(),
          name: _name.text.trim(),
        );
      } else {
        await SupabaseService.instance.signIn(
          email: email,
          password: password,
        );
      }

      if (!mounted) return;
      _go();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'تعذّر إتمام العملية، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 74,
                    height: 74,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text(
                      'S',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: AppColors.background,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    _needsProfile
                        ? 'خطوة أخيرة — عرّفنا عليك'
                        : _isSignUp
                            ? 'حساب جديد في شارِك'
                            : 'أهلًا بك في شارِك',
                    style: t.titleMedium?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                if (_needsProfile) ...[
                  _field(controller: _name, hint: 'الاسم'),
                  const SizedBox(height: 12),
                  _field(
                    controller: _handle,
                    hint: 'المعرّف بدون @',
                    textDirection: TextDirection.ltr,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(color: AppColors.like),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _primaryButton(
                    label: 'إكمال الحساب',
                    onTap: _completeProfile,
                  ),
                ] else ...[
                  if (_isSignUp) ...[
                    _field(controller: _name, hint: 'الاسم'),
                    const SizedBox(height: 12),
                    _field(
                      controller: _handle,
                      hint: 'المعرّف بدون @',
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _field(
                    controller: _email,
                    hint: 'البريد الإلكتروني',
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _password,
                    hint: 'كلمة المرور',
                    obscure: true,
                    textDirection: TextDirection.ltr,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(color: AppColors.like),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _primaryButton(
                    label: _isSignUp ? 'إنشاء الحساب' : 'دخول',
                    onTap: _submit,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                          child:
                              Divider(height: 1, color: AppColors.border)),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('أو', style: t.bodySmall),
                      ),
                      const Expanded(
                          child:
                              Divider(height: 1, color: AppColors.border)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _oauthButton(
                    label: 'الدخول بحساب آبل',
                    icon: Icons.apple,
                    background: AppColors.text,
                    foreground: AppColors.background,
                    onTap: _appleSignIn,
                  ),
                  const SizedBox(height: 10),
                  _oauthButton(
                    label: 'الدخول بحساب قوقل',
                    icon: Icons.g_mobiledata,
                    background: AppColors.background,
                    foreground: AppColors.text,
                    outlined: true,
                    onTap: _googleSignIn,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _error = null;
                              }),
                      child: Text(
                        _isSignUp
                            ? 'عندك حساب؟ سجّل الدخول'
                            : 'ما عندك حساب؟ أنشئ واحدًا',
                        style:
                            t.bodySmall?.copyWith(color: AppColors.brand),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.brand,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: _busy ? null : onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.background,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.background,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _oauthButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: _busy ? null : onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border:
                outlined ? Border.all(color: AppColors.border) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    TextDirection textDirection = TextDirection.rtl,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textDirection: textDirection,
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          hintText: hint,
          hintStyle: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
