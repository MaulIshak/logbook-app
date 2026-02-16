import 'package:flutter/material.dart';
import 'package:my_logbook_app/features/auth/login_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  int step = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Halaman Onboarding", style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            Text(
              "$step",
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (step < 3) {
                  setState(() {
                    step++;
                  });
                } else if (step >= 3) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginView()),
                  );
                  //pindah ke halaman login
                }
              },
              child: const Text("Lanjut"),
            ),
          ],
        ),
      ),
    );
  }
}
