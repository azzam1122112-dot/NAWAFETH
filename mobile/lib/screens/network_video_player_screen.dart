import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class NetworkVideoPlayerScreen extends StatefulWidget {
  final String url;
  final String? title;

  const NetworkVideoPlayerScreen({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<NetworkVideoPlayerScreen> createState() => _NetworkVideoPlayerScreenState();
}

class _NetworkVideoPlayerScreenState extends State<NetworkVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await controller.initialize();
    await controller.setLooping(true);
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _ready = true;
    });
    await controller.play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'فيديو';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: !_ready || _controller == null
            ? const CircularProgressIndicator(color: Colors.white)
            : AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller!),
                    Positioned(
                      bottom: 18,
                      left: 18,
                      right: 18,
                      child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.deepPurple,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (_controller!.value.isPlaying) {
                          _controller!.pause();
                          setState(() {});
                        } else {
                          _controller!.play();
                          setState(() {});
                        }
                      },
                      child: AnimatedOpacity(
                        opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(28),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 44),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
