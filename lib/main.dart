// =============================================================================
// MARITA — APP ENTRY POINT
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design_system/marita_design_system.dart';
import 'router.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: MaritaApp()));
}

/// Root application widget.
class MaritaApp extends ConsumerWidget {
  const MaritaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Marita',
      debugShowCheckedModeBanner: false,
      theme: MaritaTheme.light(),
      darkTheme: MaritaTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
