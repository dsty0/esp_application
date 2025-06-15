import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Simpan status login dan tokenId (gunakan FCM token jika ada)
  Future<void> saveLoginStatus(User user) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);

    // Ambil FCM token (jika dipakai untuk notifikasi/device tracking)
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await prefs.setString('tokenId', fcmToken);
    } else {
      await prefs.setString('tokenId', user.uid); // fallback pakai UID
    }
  }

  // Cek apakah user sudah login
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLogged = prefs.getBool('isLoggedIn') ?? false;
    final user = _auth.currentUser;
    return isLogged && user != null;
  }

  // Ambil tokenId dari SharedPreferences
  Future<String?> getTokenId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('tokenId');
  }

  // Logout dan hapus sesi login
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Logout error: $e'); // opsional untuk logging
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Optional: Ambil current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
