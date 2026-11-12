import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'blood_bank_request_page.dart';

class BloodBankDetailsPage extends StatelessWidget {
  /// The blood-bank document returned by the API.
  /// Expected keys: name, address, city, phone, hours, isVerified, stock (Map)
  final Map<String, dynamic> bank;

  const BloodBankDetailsPage({super.key, required this.bank});

  static const Color _red    = Color(0xFF990000);
  static const Color _bgLight = Color(0xFFF7F9FC);

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _name      => bank['name']    as String? ?? 'Blood Bank';
  String get _address   => bank['address'] as String? ?? '';
  String get _city      => bank['city']    as String? ?? '';
  String get _phone     => bank['phone']   as String? ?? '';
  String get _hours     => bank['hours']   as String? ?? '';
  bool   get _verified  => bank['isVerified'] == true;

  Map<String, int> get _stock {
    final raw = bank['stock'];
    if (raw == null) return {};
    final map = <String, int>{};
    (raw as Map).forEach((k, v) {
      final qty = (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 0;
      if (qty > 0) map[k.toString()] = qty;
    });
    return map;
  }

  int get _totalUnits => _stock.values.fold(0, (a, b) => a + b);

  /// Returns (statusLabel, fraction) for a blood group given its unit count.
  (String, double) _stockLevel(int units) {
    if (units == 0)  return ('Unavailable', 0.0);
    if (units <= 5)  return ('Critical',    0.15);
    if (units <= 15) return ('Low',         0.35);
    if (units <= 30) return ('Medium',      0.55);
    return ('High', 0.85);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _name,
          style: const TextStyle(
            color: _red,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header card ─────────────────────────────────────────────────
            _buildHeaderCard(),
            const SizedBox(height: 16),

            // ── Request button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BloodBankRequestPage(bank: bank),
                  ),
                ),
                icon: const Icon(Icons.assignment_outlined, color: Colors.white, size: 20),
                label: const Text(
                  'Request from Bank',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Contact / Directions row ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: Colors.white,
                    ),
                    onPressed: _phone.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: _phone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Phone number copied: $_phone'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                    icon: const Icon(Icons.phone_outlined, color: _red, size: 18),
                    label: Text(
                      _phone.isNotEmpty ? _phone : 'Contact',
                      style: const TextStyle(color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: Colors.white,
                    ),
                    onPressed: () {},
                    icon: const Icon(Icons.near_me_outlined, color: _red, size: 18),
                    label: const Text('Directions', style: TextStyle(color: Colors.black87)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Live stock section ──────────────────────────────────────────
            _buildStockSection(),
            const SizedBox(height: 20),

            // ── Info section ────────────────────────────────────────────────
            _buildInfoSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Header card ────────────────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    final hasStock   = _stock.isNotEmpty;
    final stockLabel = hasStock
        ? (_totalUnits > 30 ? 'High Availability' : (_totalUnits > 10 ? 'Moderate Stock' : 'Low Stock'))
        : 'Stock Unavailable';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_verified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBFE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 4),
                      Text(
                        'VERIFIED PARTNER',
                        style: TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
              if (_hours.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _hours,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            _name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),

          // Address
          if (_address.isNotEmpty || _city.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [if (_address.isNotEmpty) _address, if (_city.isNotEmpty) _city].join(', '),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Overall stock indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                const Icon(Icons.water_drop, color: _red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stockLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _red,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasStock
                            ? '$_totalUnits total units across ${_stock.length} blood group${_stock.length != 1 ? 's' : ''}'
                            : 'No stock information available.',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Live stock grid ────────────────────────────────────────────────────────

  Widget _buildStockSection() {
    const allGroups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
    final displayGroups = allGroups.map((g) {
      final qty = _stock[g] ?? 0;
      final (status, fraction) = _stockLevel(qty);
      return (group: g, qty: qty, status: status, fraction: fraction);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Row(
                children: [
                  Icon(Icons.water_drop_outlined, color: _red, size: 18),
                  SizedBox(width: 6),
                  Text('Live Stock Levels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.autorenew, color: Colors.grey, size: 14),
                  SizedBox(width: 4),
                  Text('Live', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayGroups.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (_, i) {
              final item = displayGroups[i];
              final isCritical = item.status == 'Critical' || item.status == 'Unavailable';
              final isUnavailable = item.status == 'Unavailable';

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUnavailable ? const Color(0xFFF9FAFB) : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCritical && !isUnavailable
                        ? const Color(0xFFFFCDD2)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUnavailable
                            ? Colors.grey.shade200
                            : (isCritical ? const Color(0xFFCC0000) : const Color(0xFFFFEAEA)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.group,
                        style: TextStyle(
                          color: isUnavailable
                              ? Colors.grey
                              : (isCritical ? Colors.white : const Color(0xFFCC0000)),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.fraction,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isUnavailable ? Colors.grey.shade400 : const Color(0xFF990000),
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isUnavailable ? '—' : '${item.qty} units',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCritical ? FontWeight.bold : FontWeight.normal,
                        color: isCritical && !isUnavailable
                            ? const Color(0xFFCC0000)
                            : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      item.status,
                      style: TextStyle(
                        fontSize: 10,
                        color: isUnavailable ? Colors.grey.shade400 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Info section ───────────────────────────────────────────────────────────

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About this Centre',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          const Text(
            'This centre collects, stores, and distributes blood to nearby hospitals and clinics. '
            'Contact them directly for availability and donation procedures.',
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          if (_phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: _red),
                const SizedBox(width: 8),
                Text(_phone,
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w500,
                        fontSize: 13)),
              ],
            ),
          ],
          if (_address.isNotEmpty || _city.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [if (_address.isNotEmpty) _address, if (_city.isNotEmpty) _city].join(', '),
                    style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: const [
              Icon(Icons.accessible, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text('Wheelchair accessible facility',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
