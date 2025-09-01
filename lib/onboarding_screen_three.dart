import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/token_auth_service.dart';

class OnboardingScreenThree extends StatefulWidget {
  const OnboardingScreenThree({super.key});

  @override
  State<OnboardingScreenThree> createState() => _OnboardingScreenThreeState();
}

class _OnboardingScreenThreeState extends State<OnboardingScreenThree>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      // Skip button
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: TextButton(
                            onPressed: () async {
                              await TokenAuthService.markOnboardingCompleted();
                              // Navigate directly to home screen
                              if (context.mounted) {
                                Navigator.of(context).pushReplacementNamed('/');
                              }
                            },
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(flex: 1),

                      // Main SVG Illustration with scale animation
                      Transform.scale(
                        scale: _scaleAnimation.value,
                        child: SizedBox(
                          height: 280,
                          width: double.infinity,
                          child: SvgPicture.asset(
                            'assets/svg/onboarding_three.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const Spacer(flex: 1),

                      // Title text
                      const Text(
                        'Enjoy Your Life\nEvery Time',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Description text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text(
                          'Watch 24/7 Live Stream To Kill Boredom In\nThis Digital Era With AncientFlip',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:
                                MediaQuery.of(context).size.width < 360
                                    ? 13
                                    : 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                            height: 1.4,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Page indicators - third screen active
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Inactive indicator 1
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Inactive indicator 2
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Active indicator (third screen)
                          Container(
                            width: 32,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ECDC4),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Get Started Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () async {
                            await TokenAuthService.markOnboardingCompleted();
                            // Navigate directly to home screen
                            if (context.mounted) {
                              Navigator.of(context).pushReplacementNamed('/');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4ECDC4),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
