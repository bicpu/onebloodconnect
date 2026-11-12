import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'services/bb_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BloodBankApp());
}

class BloodBankApp extends StatelessWidget {
  const BloodBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blood Bank Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC0152A)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Color(0xFFC0152A))),
            );
          }
          if (snap.data == null) {
            return const _AuthGate();
          }
          return const _ProfileGate();
        },
      ),
    );
  }
}

/// Shows Login or Register depending on user choice.
class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    if (_showRegister) {
      return RegisterPage(onHaveAccount: () => setState(() => _showRegister = false));
    }
    return LoginPage(onNoAccount: () => setState(() => _showRegister = true));
  }
}

/// After sign-in, checks if the blood bank profile exists in the backend.
/// If not (e.g. user signed in but never completed registration), shows Register page.
class _ProfileGate extends StatefulWidget {
  const _ProfileGate();
  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  bool _checking = true;
  bool _needsProfile = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      await BbApi().getMe();
      if (mounted) setState(() => _checking = false);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('not_registered')) {
        if (mounted) setState(() { _checking = false; _needsProfile = true; });
      } else {
        // Network error or other — let them in anyway, home page will handle
        if (mounted) setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFC0152A))),
      );
    }
    if (_needsProfile) {
      return RegisterPage(
        onHaveAccount: () => FirebaseAuth.instance.signOut(),
      );
    }
    return const HomePage();
  }
}
