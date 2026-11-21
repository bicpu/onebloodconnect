import 'package:flutter/material.dart';
import '../services/admin_api.dart';

class BloodBankApprovalsPage extends StatefulWidget {
  const BloodBankApprovalsPage({super.key});

  @override
  State<BloodBankApprovalsPage> createState() => _BloodBankApprovalsPageState();
}

class _BloodBankApprovalsPageState extends State<BloodBankApprovalsPage> {
  final _api = AdminApi();
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final accounts = await _api.getPendingBloodBankAccounts();
      if (mounted) setState(() => _accounts = accounts);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> account) async {
    try {
      await _api.approveBloodBankAccount(account['_id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${account['name']} approved')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 100),
                    Center(child: Text('Could not load approval queue: $_error')),
                    Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
                  ])
                : _accounts.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No blood bank accounts are awaiting approval.')),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _accounts.length,
                        itemBuilder: (context, index) {
                          final account = _accounts[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(account['name']?.toString() ?? 'Unnamed bank',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 6),
                                  Text(account['email']?.toString() ?? ''),
                                  Text(account['phone']?.toString() ?? ''),
                                  Text([
                                    account['address'], account['city'], account['state'],
                                  ].where((value) => value != null && value.toString().isNotEmpty)
                                      .join(', ')),
                                  Text('Registration: ${account['registrationNo'] ?? 'Not provided'}'),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton.icon(
                                      onPressed: () => _approve(account),
                                      icon: const Icon(Icons.verified_outlined),
                                      label: const Text('Approve account'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      );
}
