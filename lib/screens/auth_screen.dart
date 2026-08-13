import 'package:flutter/material.dart';
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
  bool _isSignUp = false;
  bool _busy = false;
  String? _error;

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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
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
                    _isSignUp ? 'حساب جديد في شارِك' : 'أهلًا بك في شارِك',
                    style: t.titleMedium?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
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
                Material(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(26),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: _busy ? null : _submit,
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
                              _isSignUp ? 'إنشاء الحساب' : 'دخول',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.background,
                              ),
                            ),
                    ),
                  ),
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
                      style: t.bodySmall?.copyWith(color: AppColors.brand),
                    ),
                  ),
                ),
              ],
            ),
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
