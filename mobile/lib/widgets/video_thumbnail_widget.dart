import 'package:flutter/material.dart';

class VideoThumbnailWidget extends StatelessWidget {
  final String path;
  final String logo;
  final EdgeInsets margin;
  final VoidCallback? onTap;

  const VideoThumbnailWidget({
    super.key,
    required this.path,
    required this.logo,
    this.margin = const EdgeInsets.symmetric(horizontal: 6),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // We intentionally avoid generating a real video thumbnail here to keep
    // the widget lightweight and build-friendly in release mode.
    // `logo` is used as the visual preview; `path` is kept for future use.
    final child = Container(
      width: 90,
      height: 90,
      margin: margin,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: AssetImage(logo),
          fit: BoxFit.cover,
        ),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.15),
        ),
        child: const Center(
          child: Icon(
            Icons.play_circle_fill,
            size: 34,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (onTap == null) return child;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: child,
    );
  }
}
