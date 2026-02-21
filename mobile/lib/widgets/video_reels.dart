import 'package:flutter/material.dart';
import 'dart:async';

import '../constants/colors.dart';
import '../models/provider_portfolio_item.dart';
import '../screens/home_media_viewer_screen.dart';
import '../services/home_feed_service.dart';

class VideoReels extends StatefulWidget {
  const VideoReels({super.key});

  @override
  State<VideoReels> createState() => _VideoReelsState();
}

class _VideoReelsState extends State<VideoReels> {
  final HomeFeedService _feed = HomeFeedService.instance;
  final PageController _controller = PageController(viewportFraction: 0.28);
  Timer? _autoTimer;

  bool _loading = true;
  int _active = 0;
  List<ProviderPortfolioItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final media = await _feed.getMediaItems(limit: 24);
      var videos = media
          .where((e) => e.fileType.toLowerCase().contains('video'))
          .take(9)
          .toList();
      if (videos.isEmpty) {
        videos = media.take(9).toList();
      }
      if (!mounted) return;
      setState(() {
        _items = videos;
        _loading = false;
      });
      _startAutoScroll();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
      });
    }
  }

  void _startAutoScroll() {
    _autoTimer?.cancel();
    if (_items.length < 2) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_controller.hasClients || !mounted) return;
      final next = (_active + 1) % _items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) return const SizedBox(height: 8);

    return SizedBox(
      height: 110,
      child: PageView.builder(
        controller: _controller,
        onPageChanged: (v) => setState(() => _active = v),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final active = index == _active;
          return GestureDetector(
            onTap: () async {
              await Navigator.of(context).push(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 280),
                  pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
                    opacity: animation,
                    child: HomeMediaViewerScreen(
                      items: _items,
                      initialIndex: index,
                    ),
                  ),
                ),
              );
            },
            child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: active ? 72 : 62,
                        height: active ? 72 : 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: active
                              ? const LinearGradient(
                                  colors: [Color(0xFF6A0DAD), Color(0xFF2C0066)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: active ? null : Colors.grey.shade200,
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF6A0DAD).withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: CustomPaint(
                          painter: _DashedCirclePainter(
                            color: active
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppColors.primaryDark.withValues(alpha: 0.5),
                            strokeWidth: 2,
                            dashLength: 5,
                            gapLength: 4,
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active ? Colors.white.withValues(alpha: 0.15) : Colors.white,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: active ? Colors.white : AppColors.deepPurple,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'فيديو',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: active ? FontWeight.bold : FontWeight.w500,
                          color: active ? const Color(0xFF2C0066) : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final radius = (size.shortestSide / 2) - strokeWidth;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * 3.141592653589793 * radius;
    final dashCount =
        (circumference / (dashLength + gapLength)).floor().clamp(10, 240);
    final sweep = (2 * 3.141592653589793) / dashCount;
    final dashSweep = sweep * (dashLength / (dashLength + gapLength));

    for (int i = 0; i < dashCount; i++) {
      final start = sweep * i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}
