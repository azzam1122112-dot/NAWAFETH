import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class BannerWidget extends StatefulWidget {
  const BannerWidget({super.key});

  @override
  State<BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<BannerWidget>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller =
        VideoPlayerController.asset('assets/videos/V16.mp4')
          ..setLooping(true)
          ..setVolume(0)
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _isInitialized = true;
              });
              _controller.play(); // ✅ تشغيل الفيديو تلقائياً
            }
          });
  }

  /// 🔄 التحكم في حالة التطبيق (الخلفية / الأمام)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    if (state == AppLifecycleState.resumed) {
      if (!_controller.value.isPlaying) {
        _controller.play(); // ✅ استئناف عند الرجوع
      }
    } else if (state == AppLifecycleState.paused) {
      _controller.pause(); // ⏸ إيقاف عند الذهاب للخلفية (لتوفير موارد)
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose(); // ✅ إغلاق الكنترولر لتفادي التسريب
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // لدعم keepAlive

    if (!_isInitialized || !_controller.value.isInitialized) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 320,
        width: MediaQuery.of(context).size.width,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}
