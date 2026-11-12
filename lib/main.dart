import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'splash_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Global auth state listener for debug: logs sign-in / sign-out events
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    // ignore: avoid_print
    print('[AuthState] authStateChanges -> user is ${user == null ? 'null (signed out)' : user.uid}');
    if (user == null) {
      // If the user was unexpectedly signed out, record the stay_signed_in preference for diagnostics
      try {
        final prefs = await SharedPreferences.getInstance();
        final stay = prefs.getBool('stay_signed_in');
        // ignore: avoid_print
        print('[AuthState] stay_signed_in preference = $stay');
      } catch (e) {
        // ignore: avoid_print
        print('[AuthState] could not read stay_signed_in: ${e.toString()}');
      }
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'One Blood Connect',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const SplashPage(),
    );
  }
}
