import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/bb_api.dart';

class DonationsPage extends StatefulWidget {
  const DonationsPage({super.key});

  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final Set<String> _expandedIds = {};
  final Map<String, Future<Uint8List>> _proofImages = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await BbApi().getPendingDonations();
      if (mounted) setState(() {
        _items = items;
        _proofImages.clear();
      });
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
          final id = item['_id']?.toString() ?? '';
          return Card(
            child: ExpansionTile(
              title: Text(item['donorName'] ?? 'Donor',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${item['bloodGroup'] ?? ''} • ${item['component'] ?? ''}'),
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedIds.add(id);
                  } else {
                    _expandedIds.remove(id);
                  }
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['bookingRef'] ?? ''),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _proofImage(id, 'donation-photo', 'Donation photo')),
                      const SizedBox(width: 8),
                      Expanded(child: _proofImage(id, 'doctor-slip', 'Doctor slip')),
                    ]),
                    const SizedBox(height: 12),
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
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _proofImage(String id, String kind, String label) {
    if (!_expandedIds.contains(id)) return _imageFrame(label, const Text('Expand to load proof'));
    final key = '$id/$kind';
    final future = _proofImages.putIfAbsent(key, () => BbApi().getDonationProofImage(id, kind));
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasData) return _imageFrame(label, Image.memory(snapshot.data!, fit: BoxFit.cover));
        if (snapshot.hasError) return _imageFrame(label, const Text('No proof attached'));
        return _imageFrame(label, const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)));
      },
    );
  }

  Widget _imageFrame(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Container(
            height: 110,
            width: double.infinity,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          ),
        ],
      );
}
