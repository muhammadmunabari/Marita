// =============================================================================
// MARITA — APP ENTRY POINT
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_system/marita_design_system.dart';
import 'router.dart';
import 'providers/settings_provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize App Check
  await FirebaseAppCheck.instance.activate(
    providerAndroid: const AndroidPlayIntegrityProvider(),
    providerApple: const AppleAppAttestProvider(),
  );

  // Connect to Local Firebase Emulators when running in debug
  // if (kDebugMode) {
  //   try {
  //     FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  //     await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  //     print('Connected to Firebase Local Emulator Suite.');
  //   } catch (e) {
  //     print('Failed to connect to emulators: $e');
  //   }
  // }

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaritaApp(),
    ),
  );
}

/// Root application widget.
class MaritaApp extends ConsumerStatefulWidget {
  const MaritaApp({super.key});

  @override
  ConsumerState<MaritaApp> createState() => _MaritaAppState();
}

class _MaritaAppState extends ConsumerState<MaritaApp> {
  late final AppLifecycleListener _listener;
  DateTime? _pausedTime;

  @visibleForTesting
  DateTime Function() nowFn = DateTime.now;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onStateChange: _onStateChange);
  }

  void _onStateChange(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Record the time when the app was paused or became inactive (e.g. due to picker or system dialog overlay)
      _pausedTime ??= nowFn();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final elapsed = nowFn().difference(_pausedTime!);
        if (elapsed.inSeconds >= 30) {
          // Reset the biometric session verification status to lock the app only if gone for 30+ seconds
          ref.read(biometricSessionProvider.notifier).state = false;
        }
        _pausedTime = null;
      }
      // Trigger a GoRouter redirect evaluation to make sure the app locks immediately on resumption if biometric lock is enabled.
      ref.read(routerListenableProvider).refresh();
    }
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Marita',
      debugShowCheckedModeBanner: false,
      theme: MaritaTheme.dark(),
      routerConfig: router,
    );
  }
}
