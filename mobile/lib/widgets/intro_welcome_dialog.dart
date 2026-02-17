import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/colors.dart';

/// نافذة تعريفية فخمة تظهر عند فتح التطبيق لأول مرة في الجلسة.
class IntroWelcomeDialog extends StatefulWidget {
  const IntroWelcomeDialog({super.key});

  @override
  State<IntroWelcomeDialog> createState() => _IntroWelcomeDialogState();
}

class _IntroWelcomeDialogState extends State<IntroWelcomeDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: FadeInUp(
        duration: const Duration(milliseconds: 500),
        child: Container(
          width: screenWidth,
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepPurple.withOpacity(0.25),
                blurRadius: 40,
                spreadRadius: 2,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppColors.accentOrange.withOpacity(0.10),
                blurRadius: 60,
                spreadRadius: -5,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── الهيدر بتدرج فخم ──
                _buildHeader(isDark),

                // ── المحتوى ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  child: Column(
                    children: [
                      // وصف المنصة
                      FadeInUp(
                        delay: const Duration(milliseconds: 300),
                        child: Text(
                          'منصة نوافذ هي منصة سعودية رقمية مبتكرة تجمع بين '
                          'مزوّدي الخدمات وطالبيها في مكانٍ واحد، '
                          'لتسهيل التواصل والوصول إلى أفضل الخدمات بسرعة وشفافية.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13.5,
                            height: 1.7,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── ميزات المنصة ──
                      FadeInUp(
                        delay: const Duration(milliseconds: 450),
                        child: _buildFeatureRow(
                          icon: FontAwesomeIcons.magnifyingGlass,
                          title: 'استكشف الخدمات',
                          subtitle:
                              'تصفّح مئات مزوّدي الخدمات في مختلف المجالات',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeInUp(
                        delay: const Duration(milliseconds: 550),
                        child: _buildFeatureRow(
                          icon: FontAwesomeIcons.handshake,
                          title: 'تواصل مباشر',
                          subtitle:
                              'تواصل فوري مع مقدمي الخدمات واطلب عروض أسعار',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeInUp(
                        delay: const Duration(milliseconds: 650),
                        child: _buildFeatureRow(
                          icon: FontAwesomeIcons.shieldHalved,
                          title: 'موثوقية وشفافية',
                          subtitle: 'تقييمات حقيقية ومزوّدون معتمدون لراحتك',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeInUp(
                        delay: const Duration(milliseconds: 750),
                        child: _buildFeatureRow(
                          icon: FontAwesomeIcons.bolt,
                          title: 'مجاني للعملاء',
                          subtitle:
                              'استمتع بخدمات المنصة بالكامل بدون أي رسوم',
                          isDark: isDark,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── زر "ابدأ الاستكشاف" ──
                      FadeInUp(
                        delay: const Duration(milliseconds: 850),
                        child: _buildStartButton(context, isDark),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// هيدر بتدرج أرجواني فخم مع شعار وعنوان ترحيبي
  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.deepPurple,
            AppColors.lightPurple,
            AppColors.deepPurple.withOpacity(0.85),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        children: [
          // شعار المنصة
          ZoomIn(
            duration: const Duration(milliseconds: 600),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/p.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.window_rounded,
                      size: 42,
                      color: AppColors.deepPurple,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // عنوان الترحيب
          FadeInDown(
            delay: const Duration(milliseconds: 200),
            child: const Text(
              'مرحبًا بك في نوافذ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 6),

          FadeInDown(
            delay: const Duration(milliseconds: 350),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'نافذتك إلى عالم الخدمات',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// صف ميزة واحد بأيقونة ونص
  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : AppColors.primaryLight.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.deepPurple.withOpacity(0.20)
              : AppColors.deepPurple.withOpacity(0.08),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.deepPurple.withOpacity(0.15),
                  AppColors.lightPurple.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: FaIcon(
                icon,
                size: 18,
                color: AppColors.deepPurple,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.deepPurple,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    height: 1.4,
                    color: isDark
                        ? Colors.white60
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// زر "ابدأ الاستكشاف" بتصميم فخم
  Widget _buildStartButton(BuildContext context, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.deepPurple,
              AppColors.lightPurple,
            ],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepPurple.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.explore_rounded,
                color: Colors.white,
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                'ابدأ الاستكشاف',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
