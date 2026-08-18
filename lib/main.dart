import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';
import 'services/push_service.dart';
import 'theme/app_theme.dart';

/// مشروع Supabase الخاص بـ شارِك.
/// يمكن تجاوزهما وقت البناء:
/// flutter build ios --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://mxtyhuddoeywdlhcejgg.supabase.co',
);

const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_1x-ZykKSxiJDgVSKwyEhkg_G9yF4a9y',
);

/// إشعار وصل والتطبيق مغلق أو في الخلفية
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await PushService.instance.init();
  FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

  // يسجّل الجهاز مع كل جلسة دخول
  Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    if (state.session != null) {
      PushService.instance.registerDevice();
    }
  });

  // الجلسة قائمة أصلًا من فتحة سابقة
  if (Supabase.instance.client.auth.currentUser != null) {
    PushService.instance.registerDevice();
  }

  runApp(const ShareApp());
}

class ShareApp extends StatelessWidget {
  const ShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شارِك',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const SplashScreen(),
    );
  }
}
