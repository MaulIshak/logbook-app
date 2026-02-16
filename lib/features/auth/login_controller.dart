// login_controller.dart
class LoginController {
  // Database sederhana (Hardcoded)
  // final String _validUsername = "admin";
  // final String _validPassword = "123";
  // Support multi user:
  // username:password
  Map<String, String> users = {"admin": "123", "maulana": "2808"};

  // Fungsi pengecekan (Logic-Only)
  // Fungsi ini mengembalikan true jika cocok, false jika salah.
  bool login(String username, String password) {
    if (users.containsKey(username) && users[username] == password) {
      return true;
    }
    return false;
  }
}
