import 'package:flutter/material.dart';
import 'package:my_logbook_app/features/auth/login_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // 1. Data Driven: Memisahkan data dari logic UI agar lebih rapi.
  final List<Map<String, String>> _onboardingData = [
    {
      "image": "assets/images/onboarding_1.png",
      "title": "Selamat Datang",
      "body":
          "Aplikasi Logbook untuk mencatat kegiatan sehari-hari dengan efisien.",
    },
    {
      "image": "assets/images/onboarding_2.png",
      "title": "Catat Kegiatanmu",
      "body": "Tuliskan kegiatanmu sehari-hari dengan mudah dan terorganisir.",
    },
    {
      "image": "assets/images/onboarding_3.png",
      "title": "Mulai Menulis",
      "body": "Tingkatkan produktivitasmu. Ayo mulai menulis logbook sekarang!",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Modern clean look
      body: SafeArea(
        child: Column(
          children: [
            // Expanded PageView: Memberikan area swipe yang luas
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingData.length,
                onPageChanged: (value) {
                  setState(() {
                    _currentIndex = value;
                  });
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Spacer untuk visual balance
                        const Spacer(),
                        Image(
                          image: AssetImage(_onboardingData[index]['image']!),
                          height: 280,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _onboardingData[index]['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _onboardingData[index]['body']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey, // Modern typography color
                            height: 1.5, // Line height agar mudah dibaca
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicator & Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  // Dot Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _onboardingData.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentIndex == index
                            ? 24
                            : 8, // Efek memanjang
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? Colors.blue
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Modern Button: Full width
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentIndex < _onboardingData.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginView(),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue, // Sesuaikan tema
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0, // Flat design lebih modern
                      ),
                      child: Text(
                        _currentIndex == _onboardingData.length - 1
                            ? "Mulai Sekarang"
                            : "Lanjut",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
