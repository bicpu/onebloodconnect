import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/admin_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One Blood Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B0000)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.idTokenChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasData) {
            return _AdminRoleGate(
              key: ValueKey(snap.data!.uid),
              user: snap.data!,
            );
          }
          return const LoginPage();
        },
      ),
    );
  }
}

class _AdminRoleGate extends StatefulWidget {
  const _AdminRoleGate({required this.user});

  final User user;

  @override
  State<_AdminRoleGate> createState() => _AdminRoleGateState();
}

class _AdminRoleGateState extends State<_AdminRoleGate> {
  late Future<IdTokenResult> _claims;

  @override
  void initState() {
    super.initState();
    _refreshClaims(forceRefresh: true);
  }

  @override
  void didUpdateWidget(covariant _AdminRoleGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    // idTokenChanges emits when Firebase refreshes the user's token. Read its
    // latest claims without forcing another refresh and causing a refresh loop.
    _refreshClaims();
  }

  void _refreshClaims({bool forceRefresh = false}) {
    // A newly provisioned administrator must receive the latest custom claims.
    _claims = widget.user.getIdTokenResult(forceRefresh);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IdTokenResult>(
      future: _claims,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final roles = snapshot.data?.claims?['roles'];
        const knownRoles = {'donor', 'blood_bank', 'admin'};
        final validRoles = roles is List &&
            roles.isNotEmpty &&
            roles.every((role) => role is String && knownRoles.contains(role));
        if (snapshot.hasData && validRoles && roles.contains('admin')) {
          return const AdminHomePage();
        }

        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.hasError
                        ? 'Could not verify administrator access.'
                        : 'This account does not have administrator access.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.hasError)
                    TextButton(
                      onPressed: () => setState(() => _refreshClaims(forceRefresh: true)),
                      child: const Text('Retry'),
                    ),
                  TextButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
