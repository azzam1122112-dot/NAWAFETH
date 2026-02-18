import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/provider_portfolio_item.dart';
import '../screens/home_media_viewer_screen.dart';
import '../services/home_feed_service.dart';

class BannerWidget extends StatefulWidget {
  const BannerWidget({super.key});

  @override
  State<BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<BannerWidget> {
  final HomeFeedService _feed = HomeFeedService.instance;
  final PageController _controller = PageController();
  Timer? _timer;

  bool _loading = true;
  int _index = 0;
  List<ProviderPortfolioItem> _banners = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final banners = await _feed.getBannerItems(limit: 6);

      if (!mounted) return;
      setState(() {
        _banners = banners;
        _loading = false;
      });
      _startAutoSlide();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _banners = const [];
        _loading = false;
      });
    }
  }

  void _startAutoSlide() {
    _timer?.cancel();
    if (_banners.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_controller.hasClients || !mounted) return;
      _index = (_index + 1) % _banners.length;
      _controller.animateToPage(
        _index,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_banners.isEmpty) {
      return Container(
        height: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppColors.deepPurple, AppColors.primaryDark],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: const Center(
          child: Text(
            'مرحباً بك في نوافذ',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final item = _banners[i];
              final isVideo = item.fileType.toLowerCase().contains('video');
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (!isVideo)
                    Image.network(
                      item.fileUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) => Container(color: Colors.grey.shade300),
                    )
                  else
                    Container(
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Icon(Icons.videocam_rounded, size: 44, color: Colors.black54),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.black.withValues(alpha: 0.10),
                        ],
                      ),
                    ),
                  ),
                  if (isVideo)
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.40),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                      ),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 280),
                            pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
                              opacity: animation,
                              child: HomeMediaViewerScreen(
                                items: _banners,
                                initialIndex: i,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    right: 14,
                    left: 14,
                    bottom: 16,
                    child: Text(
                      item.caption.trim().isEmpty ? item.providerDisplayName : item.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 16 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
