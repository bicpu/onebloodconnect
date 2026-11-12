import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileStore {
  static const _bloodGroupPrefix = 'blood_group_';

  static Future<String?> getBloodGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_bloodGroupPrefix${user.uid}');
  }

  static Future<void> saveBloodGroup(String bloodGroup) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user found.',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_bloodGroupPrefix${user.uid}', bloodGroup);
  }
}
