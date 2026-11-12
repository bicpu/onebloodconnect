import 'package:flutter/material.dart';
import '../services/admin_api.dart';

class UsersListPage extends StatefulWidget {
  const UsersListPage({super.key});
  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  static const Color red      = Color(0xFF8B0000);
  static const Color darkText = Color(0xFF0F172A);
  static const Color subText  = Color(0xFF64748B);

  bool   _loading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final u = await AdminApi().getUsers();
      if (mounted) {
        setState(() { _users = u; _filtered = u; });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    setState(() {
      if (q.isEmpty) {
        _filtered = _users;
      } else {
        final lower = q.toLowerCase();
        _filtered = _users.where((u) =>
          (u['displayName'] as String? ?? '').toLowerCase().contains(lower) ||
          (u['email']       as String? ?? '').toLowerCase().contains(lower)
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: red,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('All Users', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),

          // Count
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('${_filtered.length} users',
                      style: const TextStyle(fontSize: 12, color: subText, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: red))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            const Text('Could not load users', style: TextStyle(color: subText)),
                            const SizedBox(height: 8),
                            ElevatedButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? const Center(child: Text('No users found', style: TextStyle(color: subText)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _userCard(_filtered[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> u) {
    final name        = (u['displayName'] as String?)?.trim() ?? 'Unknown';
    final email       = u['email']       as String? ?? '';
    final isDonor     = u['isDonor']     == true;
    final hasBooking  = u['hasBooking']  == true;
    final initials    = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFFFEAEA),
            child: Text(initials,
                style: const TextStyle(color: red, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: darkText)),
                Text(email, style: const TextStyle(fontSize: 11, color: subText)),
              ],
            ),
          ),
          // Badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isDonor)
                _badge('DONOR', const Color(0xFF15803D), const Color(0xFFDCFCE7)),
              if (hasBooking)
                _badge('BOOKED', const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
              if (!isDonor && !hasBooking)
                _badge('USER', subText, const Color(0xFFF1F5F9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, Color bg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
