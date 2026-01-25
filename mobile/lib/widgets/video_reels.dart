import 'dart:async';
import 'package:flutter/material.dart';
import 'video_full_screen.dart';

class VideoReels extends StatefulWidget {
  const VideoReels({super.key});

  @override
  State<VideoReels> createState() => _VideoReelsState();
}

class _VideoReelsState extends State<VideoReels> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  double _scrollPosition = 0;

  final List<String> _baseVideoPaths = const [
    'assets/videos/1.mp4',
    'assets/videos/2.mp4',
    'assets/videos/3.mp4',
    'assets/videos/4.mp4',
  ];

  // ✅ الشعارات الجديدة
  final List<String> _baseLogos = const [
    'assets/images/32.jpeg',
    'assets/images/841015.jpeg',
    'assets/images/879797.jpeg',
  ];
  
  late final List<String> videoPaths;
  late final List<String> logos;

  @override
  void initState() {
    super.initState();
    // مضاعفة القوائم للتمرير اللانهائي
    videoPaths = List.generate(10, (_) => _baseVideoPaths).expand((x) => x).toList();
    logos = List.generate(10, (_) => _baseLogos).expand((x) => x).toList();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients && mounted) {
        _scrollPosition += 1.0;

        final maxScroll = _scrollController.position.maxScrollExtent;
        final halfScroll = maxScroll / 2;
        
        if (_scrollPosition >= halfScroll) {
          _scrollController.jumpTo(0);
          _scrollPosition = 0;
        } else {
          _scrollController.jumpTo(_scrollPosition);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Center(
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // ✅ إيقاف التمرير اليدوي
          itemCount: videoPaths.length,
          itemBuilder: (context, index) {
            final logoPath = logos[index % logos.length];
            final actualIndex = index % _baseVideoPaths.length;
            return VideoThumbnailWidget(
              path: videoPaths[index],
              logo: logoPath,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => VideoFullScreenPage(
                          videoPaths: _baseVideoPaths,
                          initialIndex: actualIndex,
                        ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class VideoThumbnailWidget extends StatefulWidget {
  final String path;
  final String logo;
  final VoidCallback onTap;
  final EdgeInsetsGeometry margin;

  const VideoThumbnailWidget({
    super.key,
    required this.path,
    required this.logo,
    required this.onTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 10),
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 90,
        height: 90,
        margin: widget.margin,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ✅ الحافة الدائرية المتحركة
            RotationTransition(
              turns: _animationController,
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Color(0xFF9F57DB),
                      Color(0xFFF1A559),
                      Color(0xFFC8A5FC),
                      Color(0xFF9F57DB),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ الشعار الثابت داخل الدائرة
            Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: Image.asset(widget.logo, fit: BoxFit.cover),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
