import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../constants/colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class OnboardItem {
  final Widget icon; // ✅ هنا صار ويدجت مش IconData بس عشان نستعمل شعار مخصص
  final String title;
  final String desc;

  OnboardItem(this.icon, this.title, this.desc);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ✅ الصفحات الثلاثة
  final List<OnboardItem> onboardingData = [
    OnboardItem(
      // شعار التطبيق ✅
      const Icon(Icons.widgets, size: 80, color: AppColors.deepPurple),
      "مرحبا بك في نوافذ",
      "منصتك الأولى لربط العملاء بمقدمي الخدمات.",
    ),
    OnboardItem(
      const FaIcon(
        FontAwesomeIcons.users,
        size: 80,
        color: AppColors.deepPurple,
      ),
      "لكل عميل ومقدم خدمة",
      "اختر خدماتك أو اعرض خبراتك وابدأ التواصل مباشرة.",
    ),
    OnboardItem(
      const FaIcon(
        FontAwesomeIcons.bolt,
        size: 80,
        color: AppColors.deepPurple,
      ),
      "انطلق الآن",
      "جرب تجربة سلسة وسريعة لتصل لما تريد خلال ثوانٍ.",
    ),
  ];

  void _nextPage() {
    if (_currentPage < onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _skip() => _finishOnboarding();

  void _finishOnboarding() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: onboardingData.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final item = onboardingData[index];
                  return _buildPage(item.icon, item.title, item.desc);
                },
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(Widget iconWidget, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BounceInDown(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: iconWidget, // ✅ شعار أو أيقونة ديناميكية
            ),
          ),

          const SizedBox(height: 40),

          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: "Cairo",
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 18),

          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Cairo",
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              onboardingData.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: _currentPage == index ? 26 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color:
                      _currentPage == index
                          ? Colors.deepPurple
                          : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow:
                      _currentPage == index
                          ? [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                          : [],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _skip,
                child: const Text(
                  "تخطي",
                  style: TextStyle(
                    fontFamily: "Cairo",
                    fontSize: 16,
                    color: Colors.deepOrange,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(18),
                  elevation: 5,
                ),
                child: Icon(
                  _currentPage == onboardingData.length - 1
                      ? Icons.check
                      : Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
