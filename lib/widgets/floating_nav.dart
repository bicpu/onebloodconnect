import 'package:flutter/material.dart';
import '../dashboard.dart';
import '../search_page.dart';
import '../donate_blood_page.dart';
import '../profile.dart';

class FloatingNav extends StatelessWidget {
  final int selectedIndex;
  final Color themeRed;
  const FloatingNav({Key? key, required this.selectedIndex, this.themeRed = const Color(0xFF8C1D18)}) : super(key: key);

  void _navigate(BuildContext context, int index) {
    if (index == selectedIndex) return;
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const DashboardPage()));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const SearchPage()));
    } else if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const DonateBloodPage()));
    } else if (index == 3) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const ProfilePage()));
    }
  }

  Widget _navItem(BuildContext context, {required IconData icon, required String label, required int index}) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => _navigate(context, index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? themeRed : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF64748B), size: 20),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(context, icon: Icons.home_filled, label: 'Home', index: 0),
          _navItem(context, icon: Icons.search_rounded, label: 'Search', index: 1),
          _navItem(context, icon: Icons.water_drop_outlined, label: 'Donate', index: 2),
          _navItem(context, icon: Icons.person_outline_rounded, label: 'Profile', index: 3),
        ],
      ),
    );
  }
}
