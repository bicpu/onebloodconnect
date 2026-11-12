import 'package:flutter/material.dart';
import '../services/bb_api.dart';

class DonationsPage extends StatefulWidget {
  const DonationsPage({super.key});

  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await BbApi().getPendingDonations();
      if (mounted) setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(Map<String, dynamic> item, bool approved) async {
    await BbApi().verifyDonation(item['_id'] as String, approved: approved);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 220),
          Center(child: Text('No donation proofs awaiting review')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['donorName'] ?? 'Donor',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${item['bloodGroup'] ?? ''} • ${item['component'] ?? ''}'),
                Text(item['bookingRef'] ?? ''),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => _review(item, false),
                    child: const Text('Reject'),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton(
                    onPressed: () => _review(item, true),
                    child: const Text('Approve'),
                  )),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}
