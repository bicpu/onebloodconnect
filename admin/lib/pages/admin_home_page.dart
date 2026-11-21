import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import 'add_blood_bank_page.dart';
import 'add_donor_page.dart';
import 'users_list_page.dart';
import 'donations_page.dart';
import 'blood_bank_approvals_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});
  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  static const Color red       = Color(0xFF8B0000);
  static const Color darkText  = Color(0xFF0F172A);
  static const Color subText   = Color(0xFF64748B);

  final _api = AdminApi();
  int _tab = 0; // Dashboard, directory, donors, donations, account approvals

  // ── Dashboard state ─────────────────────────────────────────────────────
  bool _statsLoading = true;
  Map<String, dynamic> _stats = {};
  String? _statsError;

  // ── Blood banks state ────────────────────────────────────────────────────
  bool _banksLoading = false;
  List<Map<String, dynamic>> _banks = [];

  // ── Manual donors state ──────────────────────────────────────────────────
  bool _donorsLoading = false;
  List<Map<String, dynamic>> _manualDonors = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // ── Loaders ──────────────────────────────────────────────────────────────

  Future<void> _loadStats() async {
    setState(() { _statsLoading = true; _statsError = null; });
    try {
      final s = await _api.getStats();
      if (mounted) setState(() => _stats = s);
    } catch (e) {
      if (mounted) setState(() => _statsError = e.toString());
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadBanks() async {
    setState(() => _banksLoading = true);
    try {
      final b = await _api.getBloodBanks();
      if (mounted) setState(() => _banks = b);
    } catch (_) {} finally {
      if (mounted) setState(() => _banksLoading = false);
    }
  }

  Future<void> _loadManualDonors() async {
    setState(() => _donorsLoading = true);
    try {
      final d = await _api.getManualDonors();
      if (mounted) setState(() => _manualDonors = d);
    } catch (_) {} finally {
      if (mounted) setState(() => _donorsLoading = false);
    }
  }

  void _switchTab(int i) {
    setState(() => _tab = i);
    if (i == 1 && _banks.isEmpty) _loadBanks();
    if (i == 2 && _manualDonors.isEmpty) _loadManualDonors();
  }

  // ── Delete helpers ────────────────────────────────────────────────────────

  Future<void> _deleteBank(String id) async {
    await _api.deleteBloodBank(id);
    _loadBanks();
  }

  Future<void> _deleteDonor(String id) async {
    await _api.deleteManualDonor(id);
    _loadManualDonors();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: red,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.water_drop, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('One Blood Admin',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _tabBtn(0, Icons.dashboard_outlined, 'Dashboard'),
              _tabBtn(1, Icons.add_business_outlined, 'Blood Banks'),
              _tabBtn(2, Icons.person_add_outlined, 'Donors'),
              _tabBtn(3, Icons.verified_outlined, 'Donations'),
              _tabBtn(4, Icons.fact_check_outlined, 'Approvals'),
            ],
          ),
        ),
      ),
      body: _tab == 0
          ? _buildDashboard()
          : _tab == 1
              ? _buildBanksTab()
              : _tab == 2
              ? _buildDonorsTab()
              : _tab == 3
                  ? const DonationsPage()
                  : const BloodBankApprovalsPage(),
      floatingActionButton: _tab == 0 || _tab == 3 || _tab == 4
          ? null
          : FloatingActionButton.extended(
              backgroundColor: red,
              onPressed: () async {
                if (_tab == 1) {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddBloodBankPage()));
                  _loadBanks();
                } else {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddDonorPage()));
                  _loadManualDonors();
                }
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                _tab == 1 ? 'Add Blood Bank' : 'Add Donor',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }

  // ── Tab button ─────────────────────────────────────────────────────────────

  Widget _tabBtn(int index, IconData icon, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(index),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
            border: Border(bottom: BorderSide(
              color: active ? Colors.white : Colors.transparent, width: 2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dashboard tab ─────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    if (_statsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)));
    }
    if (_statsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text('Could not reach server', style: TextStyle(color: subText)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadStats, child: const Text('Retry')),
          ],
        ),
      );
    }

    final cards = [
      _StatData('Total Users',         _stats['totalUsers']          ?? 0, Icons.people_outline,         const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
      _StatData('Registered Donors',   _stats['registeredDonors']    ?? 0, Icons.volunteer_activism,      const Color(0xFF8B0000), const Color(0xFFFFEAEA)),
      _StatData('Active Bookings',     _stats['activeBookings']      ?? 0, Icons.calendar_month_outlined, const Color(0xFFD97706), const Color(0xFFFFFBEB)),
      _StatData('Completed Donations', _stats['completedDonations']  ?? 0, Icons.check_circle_outline,   const Color(0xFF15803D), const Color(0xFFDCFCE7)),
      _StatData('Blood Banks',         _stats['bloodBanks']          ?? 0, Icons.add_business_outlined,   const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
      _StatData('Pending Requests',    _stats['pendingRequests']     ?? 0, Icons.pending_actions,         const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
    ];

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkText)),
                    Text('Pull down to refresh', style: TextStyle(fontSize: 12, color: subText)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const UsersListPage())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.people, color: Color(0xFF2563EB), size: 16),
                        SizedBox(width: 6),
                        Text('All Users', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stat grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemBuilder: (_, i) => _buildStatCard(cards[i]),
            ),

            const SizedBox(height: 24),

            // Quick actions
            const Text('Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkText)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _actionCard(
                    icon: Icons.add_business,
                    label: 'Add Blood Bank',
                    color: const Color(0xFF7C3AED),
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AddBloodBankPage()));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionCard(
                    icon: Icons.person_add,
                    label: 'Add Donor',
                    color: const Color(0xFF8B0000),
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AddDonorPage()));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(_StatData d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: d.bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(d.icon, color: d.color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.value.toString(),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: d.color),
              ),
              Text(d.label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: darkText))),
            Icon(Icons.arrow_forward_ios, size: 14, color: subText),
          ],
        ),
      ),
    );
  }

  // ── Blood Banks tab ───────────────────────────────────────────────────────

  Widget _buildBanksTab() {
    return RefreshIndicator(
      onRefresh: _loadBanks,
      child: _banksLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          : _banks.isEmpty
              ? _emptyState('No blood banks yet.\nTap + to add one.', Icons.add_business_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _banks.length,
                  itemBuilder: (_, i) => _bankCard(_banks[i]),
                ),
    );
  }

  Widget _bankCard(Map<String, dynamic> b) {
    final stock = (b['stock'] as Map?)?.cast<String, dynamic>() ?? {};
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFEAEA), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_hospital, color: red, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(b['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: darkText))),
                        if (b['isVerified'] == true)
                          const Icon(Icons.verified, color: Color(0xFF0284C7), size: 16),
                      ],
                    ),
                    Text(b['address'] ?? '', style: const TextStyle(fontSize: 11, color: subText)),
                    Text('${b['city'] ?? ''}  •  ${b['hours'] ?? ''}',
                        style: const TextStyle(fontSize: 11, color: subText)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(
                  context,
                  title: 'Delete Blood Bank',
                  message: 'Remove "${b['name']}" from the directory?',
                  onConfirm: () => _deleteBank(b['_id'] as String),
                ),
              ),
            ],
          ),
          if (stock.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Stock:', style: TextStyle(fontSize: 11, color: subText, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: stock.entries
                  .map((e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${e.key}: ${e.value}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1), fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(b['phone'] ?? '', style: const TextStyle(fontSize: 12, color: darkText)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Manual Donors tab ─────────────────────────────────────────────────────

  Widget _buildDonorsTab() {
    return RefreshIndicator(
      onRefresh: _loadManualDonors,
      child: _donorsLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B0000)))
          : _manualDonors.isEmpty
              ? _emptyState('No manual donors added yet.\nTap + to add one.', Icons.person_add_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _manualDonors.length,
                  itemBuilder: (_, i) => _donorCard(_manualDonors[i]),
                ),
    );
  }

  Widget _donorCard(Map<String, dynamic> d) {
    final bg = d['bloodGroup'] as String? ?? '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          // Blood group badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: const Color(0xFFFFEAEA), borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(bg, style: const TextStyle(color: red, fontWeight: FontWeight.bold, fontSize: 15)),
                const Text('GROUP', style: TextStyle(color: red, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d['fullName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: darkText)),
                Text('${d['city'] ?? ''}  •  ${d['donationStream'] ?? 'Whole Blood'}',
                    style: const TextStyle(fontSize: 11, color: subText)),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 12, color: subText),
                    const SizedBox(width: 4),
                    Text(d['phone'] ?? '', style: const TextStyle(fontSize: 12, color: darkText)),
                  ],
                ),
              ],
            ),
          ),
          // Manual badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(6)),
            child: const Text('MANUAL', style: TextStyle(fontSize: 9, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _confirmDelete(
              context,
              title: 'Remove Donor',
              message: 'Remove "${d['fullName']}" from the directory?',
              onConfirm: () => _deleteDonor(d['_id'] as String),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, {required String title, required String message, required VoidCallback onConfirm}) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { Navigator.pop(ctx); onConfirm(); },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _StatData(this.label, this.value, this.icon, this.color, this.bgColor);
}
