import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/edit_profile_page.dart';
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
  Map<String, dynamic>? _profile;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final profile = await BbApi().getMe();
      if (mounted) setState(() {
        _profile = profile;
        _statusError = null;
        _checking = false;
      });
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('not_registered')) {
        if (mounted) setState(() { _checking = false; _needsProfile = true; });
      } else {
        if (mounted) setState(() {
          _statusError = msg;
          _checking = false;
        });
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
        onRegistrationComplete: () {
          setState(() { _checking = true; _needsProfile = false; });
          _check();
        },
      );
    }
    if (_statusError != null) {
      return _AccountStatusScreen(
        title: 'Could not check account status',
        message: 'Please check your connection and try again. The dashboard stays unavailable until your account status is confirmed.',
        onRetry: () => setState(() { _checking = true; _statusError = null; _check(); }),
      );
    }
    if (_profile?['isVerified'] != true || _profile?['isActive'] != true) {
      final pending = _profile?['isVerified'] != true;
      return _AccountStatusScreen(
        title: pending ? 'Approval pending' : 'Account inactive',
        message: pending
            ? 'Your profile has been submitted. Blood bank operations will be available after an administrator approves your account.'
            : 'This blood bank account is inactive. Contact support for assistance.',
        onRetry: () => setState(() { _checking = true; _check(); }),
        onEdit: pending
            ? () async {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const EditProfilePage(basicOnly: true),
                ));
                if (mounted) setState(() { _checking = true; _check(); });
              }
            : null,
      );
    }
    return const HomePage();
  }
}

class _AccountStatusScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onEdit;

  const _AccountStatusScreen({
    required this.title,
    required this.message,
    required this.onRetry,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.hourglass_top, size: 52, color: Color(0xFFC0152A)),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              if (onEdit != null)
                OutlinedButton(onPressed: onEdit, child: const Text('Correct profile')),
              ElevatedButton(onPressed: onRetry, child: const Text('Check again')),
            ]),
          ),
        ),
      );
}
