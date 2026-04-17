import 'package:my_logbook_app/features/auth/models/user_model.dart';

// login_controller.dart
class LoginController {
  // Database sederhana (Hardcoded)
  // final String _validUsername = "admin";
  // final String _validPassword = "123";
  // Support multi user:
  // username:password
  Map<String, UserModel> users = {
    "admin": UserModel(
      id: "1",
      username: "admin",
      password: "123",
      role: "Ketua",
      teamId: "1",
    ),
    "maulana": UserModel(
      id: "2",
      username: "maulana",
      password: "2808",
      role: "Anggota",
      teamId: "1",
    ),
    "farras": UserModel(
      id: "3",
      username: "farras",
      password: "1502",
      role: "Asisten",
      teamId: "1",
    ),
    "andi": UserModel(
      id: "4",
      username: "andi",
      password: "123",
      role: "Ketua",
      teamId: "2",
    ),
  };

  // Fungsi pengecekan (Logic-Only)
  // Fungsi ini mengembalikan true jika cocok, false jika salah.
  bool login(String username, String password) {
    if (users.containsKey(username) && users[username]!.password == password) {
      return true;
    }
    return false;
  }

  UserModel getUser(String username) {
    return users[username]!;
  }
}
