import 'package:flutter/material.dart';

class BankDetailsPage extends StatelessWidget {
  final String name;
  final String address;
  final String distance;
  final String stockInfo;

  const BankDetailsPage({
    super.key,
    required this.name,
    required this.address,
    required this.distance,
    required this.stockInfo,
  });

  static const Color themeRed = Color(0xFF8C1D18);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: themeRed),
                        const SizedBox(width: 6),
                        Expanded(child: Text(address, style: const TextStyle(color: Colors.grey))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(distance, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    Text('Current Stock', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(stockInfo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.phone),
                          label: const Text('Call Bank'),
                          style: ElevatedButton.styleFrom(backgroundColor: themeRed),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.directions_outlined),
                          label: const Text('Get Directions'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text('About', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('This center collects, stores and distributes blood to nearby hospitals and clinics. Please contact them directly for availability and donation procedures.'),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    // Placeholder for requesting blood workflow
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: themeRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Request From This Bank', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
