// login_view.dart
import 'package:flutter/material.dart';
import 'package:my_logbook_app/features/auth/login_controller.dart';
import 'package:my_logbook_app/features/logbook/counter_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final LoginController _controller = LoginController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Key untuk validasi form
  bool _isObscure = true;

  // Logic tetap sama, hanya dipanggil dari UI yang berbeda
  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      // Dismiss keyboard agar lebih rapi saat loading/pindah
      FocusScope.of(context).unfocus();

      String user = _userController.text.trim();
      String pass = _passController.text.trim();

      if (_controller.login(user, pass)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CounterView(username: user)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Username atau Password salah."),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating, // Floating agar lebih modern
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 1. SingleChildScrollView: Mencegah error "Bottom Overflowed" saat keyboard muncul
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Header Section: Menggantikan AppBar standar
                const Text(
                  "Selamat Datang Kembali!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Silakan masuk untuk melanjutkan logbook.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // 3. Input Fields dengan Styling Modern
                TextFormField(
                  controller: _userController,
                  decoration: InputDecoration(
                    labelText: "Username",
                    hintText: "Masukkan username Anda",
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? "Username wajib diisi"
                      : null,
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _passController,
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    labelText: "Password",
                    hintText: "Masukkan password Anda",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                      icon: Icon(
                        _isObscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.grey,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? "Password wajib diisi"
                      : null,
                ),

                const SizedBox(height: 24),

                // 4. Primary Button: Full Width & Tinggi
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Masuk",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
