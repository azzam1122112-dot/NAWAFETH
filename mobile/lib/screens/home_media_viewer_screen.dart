import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../constants/colors.dart';
import '../models/provider_portfolio_item.dart';
import 'provider_profile_screen.dart';

class HomeMediaViewerScreen extends StatefulWidget {
  final List<ProviderPortfolioItem> items;
  final int initialIndex;

  const HomeMediaViewerScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<HomeMediaViewerScreen> createState() => _HomeMediaViewerScreenState();
}

class _HomeMediaViewerScreenState extends State<HomeMediaViewerScreen> {
  late final PageController _pageController;
  late int _index;

  VideoPlayerController? _video;
  bool _videoReady = false;
  final Set<int> _liked = <int>{};
  final Set<int> _saved = <int>{};
  bool _showSwipeHint = true;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _index);
    _loadCurrentVideo();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showSwipeHint = false);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _video?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool _isVideo(ProviderPortfolioItem item) {
    return item.fileType.toLowerCase().contains('video');
  }

  Future<void> _loadCurrentVideo() async {
    if (!mounted) return;
    final item = widget.items[_index];
    final isVideo = _isVideo(item);

    await _video?.dispose();
    _video = null;
    _videoReady = false;
    if (!isVideo) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(item.fileUrl));
      _video = controller;
      await controller.initialize();
      controller
        ..setLooping(true)
        ..play();
      if (!mounted) return;
      setState(() {
        _videoReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoReady = false;
      });
    }
  }

  Future<void> _openProvider(ProviderPortfolioItem item) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderProfileScreen(
          providerId: item.providerId.toString(),
          providerName: item.providerDisplayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('لا يوجد محتوى')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.items.length,
            onPageChanged: (i) async {
              _index = i;
              await _loadCurrentVideo();
            },
            itemBuilder: (context, i) {
              final item = widget.items[i];
              final isVideo = _isVideo(item);
              final isCurrent = i == _index;

              return GestureDetector(
                onTap: () {
                  if (!isVideo) return;
                  final c = _video;
                  if (!isCurrent || c == null || !_videoReady) return;
                  if (c.value.isPlaying) {
                    c.pause();
                  } else {
                    c.play();
                  }
                  setState(() {});
                },
                child: Center(
                  child: isVideo
                      ? (!isCurrent || _video == null || !_videoReady)
                          ? const CircularProgressIndicator(color: Colors.white)
                          : AspectRatio(
                              aspectRatio: _video!.value.aspectRatio,
                              child: VideoPlayer(_video!),
                            )
                      : InteractiveViewer(
                          child: Image.network(
                            item.fileUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, error, stackTrace) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                              size: 64,
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 28),
              onPressed: () {},
            ),
          ),
          Positioned(
            right: 12,
            bottom: 110,
            child: Builder(
              builder: (context) {
                final current = widget.items[_index];
                final liked = _liked.contains(current.id);
                final saved = _saved.contains(current.id);
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => _openProvider(current),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.deepPurple, width: 2.5),
                        ),
                        child: const CircleAvatar(
                          radius: 25,
                          child: Icon(Icons.person),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _CircleAction(
                      icon: liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      onTap: () {
                        setState(() {
                          if (liked) {
                            _liked.remove(current.id);
                          } else {
                            _liked.add(current.id);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    _CircleAction(
                      icon: saved ? Icons.bookmark : Icons.bookmark_border,
                      onTap: () {
                        setState(() {
                          if (saved) {
                            _saved.remove(current.id);
                          } else {
                            _saved.add(current.id);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    _CircleAction(
                      icon: Icons.home_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: 12,
            right: 64,
            bottom: 26,
            child: Builder(
              builder: (context) {
                final current = widget.items[_index];
                final title = current.caption.trim().isEmpty
                    ? current.providerDisplayName
                    : current.caption;
                return Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                );
              },
            ),
          ),
          if (_showSwipeHint)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swipe_up_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'اسحب للأعلى للمحتوى التالي',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleAction({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.deepPurple),
      ),
    );
  }
}
