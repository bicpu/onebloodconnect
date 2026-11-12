import 'package:flutter/material.dart';
import 'blood_bank_details_page.dart';
import 'contact_donor_page.dart';
import 'notifications_page.dart';
import 'widgets/floating_nav.dart';
import 'services/api_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const Color themeRed = Color(0xFF8C1D18);
  static const Color themeBg  = Color(0xFFF8F9FA);

  final int _selectedIndex = 1;

  // ── Filter state ──────────────────────────────────────────────────────────
  int    selectedTypeIndex   = 0; // 0=All  1=Blood Banks  2=Individual
  String selectedBloodGroup  = '';
  final  _searchCtrl         = TextEditingController();
  String _searchQuery        = '';

  // ── Data ──────────────────────────────────────────────────────────────────
  bool   _loading = true;
  String? _error;

  List<Map<String, dynamic>> _allBanks   = [];
  List<Map<String, dynamic>> _allDonors  = [];

  /// Donor IDs (uid or _id) the current user has already sent a request to.
  /// Persists for the lifetime of this page so the button stays "Contacted".
  final Set<String> _contactedDonorIds = {};

  // ── Blood groups for filter row ───────────────────────────────────────────
  static const List<String> _groups = ['A+','A-','B+','B-','O+','O-','AB+','AB-'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService().getBloodBanks(),          // admin-added banks
        ApiService().searchDonors(),
        ApiService().getBloodBankAccounts(),    // self-registered blood bank accounts
      ]);

      // Normalise blood bank account documents to the same shape as blood banks
      final adminBanks    = results[0];
      final accountBanks  = results[2].map((a) {
        final stock = a['stock'];
        return {
          ...a,
          // Ensure stock is a plain Map<String,dynamic>
          'stock': stock is Map ? stock.cast<String, dynamic>() : <String, dynamic>{},
          // Mark source so UI can show a "Self-Registered" badge if needed
          'selfRegistered': true,
        };
      }).toList();

      // Merge — admin banks first, then self-registered (dedup by name as safety)
      final seenNames = <String>{};
      final merged    = <Map<String, dynamic>>[];
      for (final b in [...adminBanks, ...accountBanks]) {
        final name = (b['name'] as String? ?? '').toLowerCase().trim();
        if (name.isNotEmpty && seenNames.add(name)) merged.add(b);
      }

      if (!mounted) return;
      setState(() {
        _allBanks  = merged;
        _allDonors = results[1];
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Filtered lists ────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _banks {
    var list = _allBanks;
    if (selectedBloodGroup.isNotEmpty) {
      list = list.where((b) {
        final stock = (b['stock'] as Map?)?.cast<String, dynamic>() ?? {};
        return stock.containsKey(selectedBloodGroup) &&
            (stock[selectedBloodGroup] as num? ?? 0) > 0;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((b) =>
          (b['name']    as String? ?? '').toLowerCase().contains(q) ||
          (b['address'] as String? ?? '').toLowerCase().contains(q) ||
          (b['city']    as String? ?? '').toLowerCase().contains(q)).toList();
    }
    return list;
  }

  List<Map<String, dynamic>> get _donors {
    var list = _allDonors;
    if (selectedBloodGroup.isNotEmpty) {
      list = list.where((d) => d['bloodGroup'] == selectedBloodGroup).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((d) =>
          (d['fullName']  as String? ?? '').toLowerCase().contains(q) ||
          (d['city']      as String? ?? '').toLowerCase().contains(q)).toList();
    }
    return list;
  }

  int get _totalCount {
    if (selectedTypeIndex == 1) return _banks.length;
    if (selectedTypeIndex == 2) return _donors.length;
    return _banks.length + _donors.length;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeBg,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── App bar ───────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: const BoxDecoration(color: themeRed, shape: BoxShape.circle),
                        child: const Icon(Icons.water_drop, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text('One Blood Connect',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
                        onPressed: _load,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Search box ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: const InputDecoration(
                              hintText: 'Search donors & blood banks…',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.black54, fontSize: 14),
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(Icons.cancel, color: Colors.grey, size: 18),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: themeRed, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.tune, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Type chips ────────────────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _typeChip(0, 'All',          '${_allBanks.length + _allDonors.length}'),
                        const SizedBox(width: 8),
                        _typeChip(1, 'Blood Banks',  '${_allBanks.length}',  icon: Icons.add_business_outlined),
                        const SizedBox(width: 8),
                        _typeChip(2, 'Individual',   '${_allDonors.length}', icon: Icons.person_outline),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Blood group filter ────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('FILTER BY BLOOD GROUP',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                      if (selectedBloodGroup.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => selectedBloodGroup = ''),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                            child: const Text('Clear filter',
                                style: TextStyle(color: Color(0xFFDC2626), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _groups.map((g) {
                        final selected = selectedBloodGroup == g;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() =>
                                selectedBloodGroup = selected ? '' : g),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? themeRed : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: selected ? themeRed : Colors.grey.shade300),
                              ),
                              child: Text(g,
                                  style: TextStyle(
                                    color: selected ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  )),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Loading / error ───────────────────────────────────
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: themeRed)),
                    )
                  else if (_error != null)
                    _buildError()
                  else ...[

                    // ── Results header ────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Results ($_totalCount)',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          selectedBloodGroup.isNotEmpty
                              ? 'Filtered: $selectedBloodGroup'
                              : 'All blood groups',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Blood bank cards ──────────────────────────────
                    if (selectedTypeIndex != 2) ...[
                      if (_banks.isEmpty && selectedTypeIndex == 1)
                        _emptyState('No blood banks found', Icons.add_business_outlined)
                      else
                        ..._banks.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _bankCard(b),
                        )),
                    ],

                    // ── Donor cards ───────────────────────────────────
                    if (selectedTypeIndex != 1) ...[
                      if (_donors.isEmpty && selectedTypeIndex == 2)
                        _emptyState('No donors found', Icons.person_outline)
                      else
                        ..._donors.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _donorCard(d),
                        )),
                    ],

                    // ── All-empty state ───────────────────────────────
                    if (selectedTypeIndex == 0 && _banks.isEmpty && _donors.isEmpty)
                      _emptyState('No results found.\nTry a different filter.', Icons.search_off),
                  ],
                ],
              ),
            ),

            // ── Floating nav ──────────────────────────────────────────
            Positioned(
              left: 20, right: 20, bottom: 16,
              child: FloatingNav(selectedIndex: _selectedIndex),
            ),
          ],
        ),
      ),
    );
  }

  // ── Blood bank card ───────────────────────────────────────────────────────

  Widget _bankCard(Map<String, dynamic> b) {
    final stock = (b['stock'] as Map?)?.cast<String, dynamic>() ?? {};
    final isVerified = b['isVerified'] == true;

    return _resultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon tile
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEAEA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: Icon(Icons.local_hospital, color: themeRed, size: 26)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(b['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (isVerified)
                          const Icon(Icons.verified, color: Color(0xFF0284C7), size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(b['address'] ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.grey),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(b['hours'] ?? '',
                              style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Stock pills
          if (stock.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.water_drop, color: themeRed, size: 12),
                  const SizedBox(width: 6),
                  const Text('Stock: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: stock.entries
                            .where((e) => (e.value as num? ?? 0) > 0)
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _stockPill('${e.key} (${e.value})'),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Phone
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(b['phone'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
            ],
          ),
          const SizedBox(height: 10),

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => BloodBankDetailsPage(bank: b))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.water_drop, size: 14, color: Colors.white),
                  label: const Text('Request Blood', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0F2FE),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.phone, size: 14, color: Color(0xFF0369A1)),
                  label: const Text('Direct Call', style: TextStyle(color: Color(0xFF0369A1), fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Donor card ────────────────────────────────────────────────────────────

  Widget _donorCard(Map<String, dynamic> d) {
    final name        = d['fullName']       as String? ?? 'Unknown';
    final bloodGroup  = d['bloodGroup']     as String? ?? '?';
    final city        = d['city']           as String? ?? '';
    final stream      = d['donationStream'] as String? ?? 'Whole Blood';
    final phone       = d['phone']          as String? ?? '';
    final isManual    = d['manualEntry']    == true;
    final initials    = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return _resultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFFFEAEA),
                    child: Text(initials,
                        style: const TextStyle(color: themeRed, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        if (isManual)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('MANUAL',
                                style: TextStyle(color: Color(0xFFD97706), fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(stream, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: themeRed),
                          const SizedBox(width: 2),
                          Text(city,
                              style: const TextStyle(color: themeRed, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Blood group badge
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(bloodGroup,
                        style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 14)),
                    const Text('GROUP',
                        style: TextStyle(color: Color(0xFFDC2626), fontSize: 7, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Available badge
          Row(
            children: [
              _miniBadge(Icons.check_circle_outline, 'Available Now'),
              if (phone.isNotEmpty) ...[
                const SizedBox(width: 6),
                _miniBadge(Icons.phone_outlined, phone),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Contact button — swaps to "Contacted" after request is sent
          SizedBox(
            width: double.infinity,
            child: _buildContactButton(d),
          ),
        ],
      ),
    );
  }

  // ── Empty / error states ──────────────────────────────────────────────────

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text('Could not reach server',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Check your connection and try again.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: themeRed),
              icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 10),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _typeChip(int index, String label, String count, {IconData? icon}) {
    final selected = selectedTypeIndex == index;
    return GestureDetector(
      onTap: () => setState(() => selectedTypeIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? themeRed : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? themeRed : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? Colors.white : Colors.black87),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(count,
                  style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF0284C7),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Contact button helper ─────────────────────────────────────────────────

  /// Unique key for a donor — prefer uid (Firebase string), fall back to _id.
  String _donorKey(Map<String, dynamic> d) {
    final uid = d['uid'] as String?;
    if (uid != null && uid.isNotEmpty) return uid;
    final id = d['_id'];
    if (id is String && id.isNotEmpty) return id;
    if (id is Map) return (id['\$oid'] ?? '').toString();
    return id?.toString() ?? '';
  }

  Widget _buildContactButton(Map<String, dynamic> d) {
    final key = _donorKey(d);
    final alreadyContacted = _contactedDonorIds.contains(key);

    if (alreadyContacted) {
      return ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF15803D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.white),
        label: const Text('Contacted · View Status',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }

    return ElevatedButton.icon(
      onPressed: () async {
        final sent = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => ContactDonorPage(donor: d)),
        );
        // Only persist the visual state after the request endpoint succeeds.
        if (mounted && sent == true) {
          setState(() => _contactedDonorIds.add(key));
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: themeRed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
      label: const Text('Contact Donor',
          style: TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  // ── Result card wrapper ───────────────────────────────────────────────────

  Widget _resultCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  Widget _miniBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF0284C7)),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(fontSize: 10, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _stockPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: const TextStyle(color: Color(0xFF0369A1), fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
