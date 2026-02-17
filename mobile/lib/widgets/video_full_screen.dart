import 'dart:ui'; // لمؤثر الضباب (blur)
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../constants/colors.dart'; // ✅ AppColors من ملفك

class VideoFullScreenPage extends StatefulWidget {
  final List<String> videoPaths;
  final int initialIndex;
  final Future<void> Function()? onOpenProfile;
  final Future<void> Function(int index)? onReportContent;
  final Future<void> Function(int index)? onDeleteContent;

  const VideoFullScreenPage({
    super.key,
    required this.videoPaths,
    this.initialIndex = 0,
    this.onOpenProfile,
    this.onReportContent,
    this.onDeleteContent,
  });

  @override
  State<VideoFullScreenPage> createState() => _VideoFullScreenPageState();
}

class _VideoFullScreenPageState extends State<VideoFullScreenPage>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  late PageController _pageController;

  int _currentIndex = 0;
  bool _isInitialized = false;
  bool _hasError = false;

  // ✅ حالات الأزرار
  bool _isLiked = false;
  bool _isSaved = false;

  // ⚡ الرسالة التفاعلية (فقاعة الإعجاب / الحفظ)
  bool _showOverlayMessage = false;
  String _overlayText = "";
  IconData _overlayIcon = Icons.thumb_up;
  Color _overlayColor = AppColors.deepPurple;

  late AnimationController _bubbleAnimController;
  late Animation<double> _bubbleScaleAnim;

  // 💡 تلميح السحب بين الفيديوهات (يد تتحرك من اليمين لليسار)
  bool _showSwipeHint = false;
  late AnimationController _hintController;
  late Animation<Offset> _hintSlideAnim;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex.clamp(0, widget.videoPaths.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    // أنيميشن فقاعة الإعجاب/الحفظ
    _bubbleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bubbleScaleAnim = CurvedAnimation(
      parent: _bubbleAnimController,
      curve: Curves.easeOutBack,
    );

    // أنيميشن اليد التي تحاكي السحب
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _hintSlideAnim = Tween<Offset>(
      begin: const Offset(0.18, 0.0), // تبدأ من يمين
      end: const Offset(-0.02, 0.0), // تتحرك قليلاً لليسار
    ).animate(
      CurvedAnimation(parent: _hintController, curve: Curves.easeInOut),
    );

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    setState(() {
      _isInitialized = false;
      _hasError = false;
      _isLiked = false;
      _isSaved = false;
    });

    try {
      _controller?.pause();
      await _controller?.dispose();

      final controller = VideoPlayerController.asset(
        widget.videoPaths[_currentIndex],
      );
      _controller = controller;

      await controller.initialize();

      controller
        ..setLooping(true)
        ..setVolume(1.0)
        ..play();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      if (_currentIndex == 0) {
        _startSwipeHint();
      } else {
        _hideSwipeHint();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
      debugPrint('❌ خطأ في تحميل الفيديو: $e');
    }
  }

  Future<void> _startSwipeHint() async {
    if (!mounted) return;

    setState(() => _showSwipeHint = true);
    _hintController.repeat(reverse: true); // اليد تروح وتجي

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    _hideSwipeHint();
  }

  void _hideSwipeHint() {
    if (!mounted) return;
    _hintController.stop();
    _hintController.reset();
    if (_showSwipeHint) {
      setState(() => _showSwipeHint = false);
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized || _hasError || _controller == null) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
  }

  void _seekForward() {
    if (!_isInitialized || _hasError || _controller == null) return;
    final current = _controller!.value.position;
    final max = _controller!.value.duration;
    final target = current + const Duration(seconds: 10);
    _controller!.seekTo(target < max ? target : max);
  }

  void _seekBackward() {
    if (!_isInitialized || _hasError || _controller == null) return;
    final current = _controller!.value.position;
    final target = current - const Duration(seconds: 10);
    _controller!.seekTo(target > Duration.zero ? target : Duration.zero);
  }

  // ✅ معالجة النقر المزدوج على يمين الشاشة للتسريع
  void _handleDoubleTapRight() {
    _seekForward();
    _showBubbleMessage("+10 ثواني", Icons.fast_forward, AppColors.accentOrange);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _bubbleAnimController.dispose();
    _hintController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ✅ قائمة يمينية (الصورة + إعجاب + حفظ + الرئيسية)
  Widget _buildRightSideMenu() {
    return Positioned(
      right: 12,
      bottom: 110,
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              // ✅ إيقاف الفيديو مؤقتاً قبل الانتقال
              await _controller?.pause();

              if (widget.onOpenProfile != null) {
                await widget.onOpenProfile!.call();
              }

              if (mounted && _controller != null && _controller!.value.isInitialized) {
                _controller!.play();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.deepPurple, width: 3),
              ),
              child: CircleAvatar(
                radius: 27,
                backgroundColor: AppColors.primaryLight,
                child: const Icon(
                  Icons.person,
                  color: AppColors.deepPurple,
                  size: 28,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          InkWell(
            onTap: () {
              setState(() => _isLiked = !_isLiked);
              _showBubbleMessage(
                _isLiked ? "تم الإعجاب" : "تم إلغاء الإعجاب",
                Icons.thumb_up,
                AppColors.deepPurple,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _isLiked ? AppColors.deepPurple : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.thumb_up,
                size: 26,
                color: _isLiked ? Colors.white : AppColors.deepPurple,
              ),
            ),
          ),

          const SizedBox(height: 16),

          InkWell(
            onTap: () {
              setState(() => _isSaved = !_isSaved);
              _showBubbleMessage(
                _isSaved ? "تم الحفظ" : "تم إلغاء الحفظ",
                Icons.bookmark,
                AppColors.deepPurple,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _isSaved ? AppColors.deepPurple : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.bookmark,
                size: 26,
                color: _isSaved ? Colors.white : AppColors.deepPurple,
              ),
            ),
          ),

          const SizedBox(height: 16),

          _buildCircleIcon(Icons.home_rounded, "الرئيسية", () {
            Navigator.pop(context);
          }),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 26, color: AppColors.deepPurple),
        ),
      ),
    );
  }

  // ✅ رسالة فقاعة جميلة (للإعجاب/الحفظ)
  void _showBubbleMessage(String text, IconData icon, Color color) {
    setState(() {
      _overlayText = text;
      _overlayIcon = icon;
      _overlayColor = color;
      _showOverlayMessage = true;
    });

    _bubbleAnimController.forward(from: 0);

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _showOverlayMessage = false);
      }
    });
  }

  Widget _buildOverlayMessage() {
    if (!_showOverlayMessage) return const SizedBox.shrink();
    return Center(
      child: ScaleTransition(
        scale: _bubbleScaleAnim,
        child: AnimatedOpacity(
          opacity: _showOverlayMessage ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: _overlayColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _overlayColor.withOpacity(0.45),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_overlayIcon, color: Colors.white, size: 40),
                const SizedBox(height: 10),
                Text(
                  _overlayText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🧭 شريط علوي بسيط (زر إغلاق فقط)
  Widget _buildTopBar() {
    final paddingTop = MediaQuery.of(context).padding.top;

    final hasMenu = widget.onReportContent != null;
    final canDelete = widget.onDeleteContent != null;

    Future<void> openMenu() async {
      if (!hasMenu) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.flag_outlined, color: Colors.red),
                    title: const Text('الإبلاغ عن المحتوى', style: TextStyle(fontFamily: 'Cairo')),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final cb = widget.onReportContent;
                      if (cb != null) {
                        await cb(_currentIndex);
                      }
                    },
                  ),
                  if (canDelete)
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.black87),
                      title: const Text('حذف', style: TextStyle(fontFamily: 'Cairo')),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _confirmDelete();
                      },
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          );
        },
      );
    }

    return Positioned(
      top: paddingTop + 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          if (hasMenu)
            Container(
              decoration: BoxDecoration(
                color: AppColors.softBlue.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: openMenu,
                icon: const Icon(Icons.more_horiz, color: Colors.white),
                tooltip: 'خيارات',
              ),
            ),
          const Spacer(),
          if (canDelete)
            Container(
              decoration: BoxDecoration(
                color: AppColors.softBlue.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                tooltip: 'حذف',
              ),
            ),
          if (canDelete) const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.softBlue.withOpacity(0.55),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'إغلاق',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final cb = widget.onDeleteContent;
    if (cb == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف اللمحة', style: TextStyle(fontFamily: 'Cairo')),
            content: const Text('هل تريد حذف هذه اللمحة؟', style: TextStyle(fontFamily: 'Cairo')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        );
      },
    );

    if (shouldDelete == true) {
      await cb(_currentIndex);
    }
  }

  // 🎛 شريط تحكم سفلي — تقديم/تراجع/تشغيل + شريط تقدم
  Widget _buildBottomControls() {
    if (_controller == null || !_isInitialized || _hasError) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10, top: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, AppColors.softBlue.withOpacity(0.92)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller!,
                builder: (context, value, child) {
                  final position = value.position;
                  final duration = value.duration;
                  final totalMs =
                      duration.inMilliseconds == 0
                          ? 1
                          : duration.inMilliseconds;
                  final progress =
                      position.inMilliseconds.clamp(0, totalMs) / totalMs;

                  return Row(
                    children: [
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: SliderComponentShape.noOverlay,
                          ),
                          child: Slider(
                            value: progress,
                            onChanged: (v) {
                              final newPositionMs = (totalMs * v).toInt();
                              _controller!.seekTo(
                                Duration(milliseconds: newPositionMs),
                              );
                            },
                            activeColor: AppColors.accentOrange,
                            inactiveColor: Colors.white24,
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _smallRoundButton(
                    icon: Icons.replay_10,
                    onTap: _seekBackward,
                  ),
                  const SizedBox(width: 18),
                  _largePlayPauseButton(),
                  const SizedBox(width: 18),
                  _smallRoundButton(
                    icon: Icons.forward_10,
                    onTap: _seekForward,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallRoundButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.deepPurple),
      ),
    );
  }

  Widget _largePlayPauseButton() {
    final isPlaying =
        _isInitialized && !_hasError && _controller?.value.isPlaying == true;
    return InkWell(
      onTap: _togglePlayPause,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.deepPurple,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  // 💡 تلميح شفاف في منتصف الشاشة — اليد فوق النص، مرفوع للأعلى قليلاً
  Widget _buildSwipeHintOverlay() {
    if (!_showSwipeHint) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          // رفع التلميح قليلاً لفوق حتى لا يتداخل مع أيقونة التاجر والتكست
          alignment: const Alignment(0, -0.1),
          child: AnimatedOpacity(
            opacity: _showSwipeHint ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 👋 اليد المتحركة مكبّرة وباللون الموف
                SlideTransition(
                  position: _hintSlideAnim,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.35),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.deepPurple.withOpacity(0.7),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.pan_tool_alt_rounded,
                      color: AppColors.deepPurple,
                      size: 52,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // 📝 النص داخل كبسولة مستقلة (بدون اليد)
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.deepPurple.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "اسحب لأعلى أو لأسفل للانتقال بين الفيديوهات",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.softBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🎥 السحب بين المقاطع عمودياً (لأعلى/لأسفل) عبر PageView
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videoPaths.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              _initializeVideo();
            },
            itemBuilder: (_, index) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlayPause,
                onDoubleTapDown: (details) {
                  // تحديد موقع النقر: إذا كان في النصف الأيمن من الشاشة
                  final screenWidth = MediaQuery.of(context).size.width;
                  final tapX = details.globalPosition.dx;
                  
                  if (tapX > screenWidth / 2) {
                    // نقر مزدوج على يمين الشاشة → تسريع
                    _handleDoubleTapRight();
                  }
                },
                child: Center(
                  child:
                      _hasError
                          ? const Text(
                            'تعذر تحميل الفيديو',
                            style: TextStyle(color: Colors.white),
                          )
                          : !_isInitialized || _controller == null
                          ? const CircularProgressIndicator(color: Colors.white)
                          : AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                ),
              );
            },
          ),

          _buildTopBar(),
          _buildRightSideMenu(),
          _buildOverlayMessage(),
          _buildBottomControls(),
          _buildSwipeHintOverlay(),
        ],
      ),
    );
  }
}
