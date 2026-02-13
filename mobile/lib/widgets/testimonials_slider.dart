import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../services/home_feed_service.dart';

class TestimonialsSlider extends StatefulWidget {
  const TestimonialsSlider({super.key});

  @override
  State<TestimonialsSlider> createState() => _TestimonialsSliderState();
}

class _TestimonialsSliderState extends State<TestimonialsSlider> {
  final PageController _controller = PageController(viewportFraction: 0.85);
  final HomeFeedService _feed = HomeFeedService.instance;

  int _currentIndex = 0;
  Timer? _autoTimer;
  bool _loading = true;
  List<Map<String, dynamic>> _testimonials = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _feed.getTestimonials(limit: 8);

      if (!mounted) return;
      setState(() {
        _testimonials = items;
        _loading = false;
      });

      _startAutoSlide();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _testimonials = const [];
        _loading = false;
      });
    }
  }

  void _startAutoSlide() {
    _autoTimer?.cancel();
    if (_testimonials.length < 2) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients || !mounted) return;
      _currentIndex++;
      if (_currentIndex >= _testimonials.length) _currentIndex = 0;
      _controller.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_testimonials.isEmpty) return const SizedBox.shrink();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تقييمات العملاء',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.deepPurple,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: PageView.builder(
              controller: _controller,
              itemCount: _testimonials.length,
              itemBuilder: (context, index) {
                final t = _testimonials[index];
                final rating = (t['rating'] is int) ? t['rating'] as int : 5;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.20)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.primaryDark,
                            radius: 16,
                            child: Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t['name'].toString(),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t['comment'].toString(),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            size: 16,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
