import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/token_auth_service.dart';

class UnifiedOnboardingScreen extends StatefulWidget {
  const UnifiedOnboardingScreen({super.key});

  @override
  State<UnifiedOnboardingScreen> createState() =>
      _UnifiedOnboardingScreenState();
}

class _UnifiedOnboardingScreenState extends State<UnifiedOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Welcome To The Fun\nMagic Media',
      description:
          'Watch Fun Video, Party And Live Streams,\nChat With People From Around The Globe,\nAnd Get Rewards!',
      image: 'assets/svg/onboarding_one.svg',
      backgroundColor: const Color(0xFF2C3E50),
    ),
    OnboardingData(
      title: 'Best Social App To\nMake New Friends',
      description:
          'AncientFlip LIVE/PARTY Allows You To Live-\nStream Your Favorite Moments, Make\nFriends From All Around The World.',
      image: 'assets/svg/onboarding_two.svg',
      backgroundColor: const Color(0xFF2C3E50),
      hasWave: true,
    ),
    OnboardingData(
      title: 'Enjoy Your Life\nEvery Time',
      description:
          'Watch 24/7 Live Stream To Kill Boredom In\nThis Digital Era With AncientFlip',
      image: 'assets/svg/onboarding_three.svg',
      backgroundColor: const Color(0xFF2C3E50),
      isLast: true,
    ),
  ];

  Future<void> _complete() async {
    await TokenAuthService.markOnboardingCompleted();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pages[_currentPage].backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (int page) {
                setState(() => _currentPage = page);
              },
              itemBuilder: (context, index) {
                return _buildPage(_pages[index]);
              },
            ),

            // Top Skip Button
            if (_currentPage < _pages.length - 1)
              Positioned(
                top: 16,
                right: 24,
                child: TextButton(
                  onPressed: _complete,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ),

            // Bottom Navigation Area
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => _buildIndicator(index),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _complete();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4ECDC4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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

  Widget _buildPage(OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          if (data.hasWave)
            Align(
              alignment: Alignment.topRight,
              child: SvgPicture.asset(
                'assets/svg/onboarding_two_wave.svg',
                height: 80,
              ),
            ),
          SizedBox(
            height: 300,
            child: SvgPicture.asset(data.image, fit: BoxFit.contain),
          ),
          const Spacer(flex: 1),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildIndicator(int index) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 6,
      width: isActive ? 24 : 6,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF4ECDC4) : Colors.white24,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String image;
  final Color backgroundColor;
  final bool hasWave;
  final bool isLast;

  OnboardingData({
    required this.title,
    required this.description,
    required this.image,
    required this.backgroundColor,
    this.hasWave = false,
    this.isLast = false,
  });
}
