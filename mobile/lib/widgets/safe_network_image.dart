import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A set of URLs that returned 404 during this app session.
/// We skip network requests for these entirely to avoid hammering the server.
final Set<String> _brokenUrlCache = {};

/// A replacement for [Image.network] that:
/// 1. Uses [CachedNetworkImage] for disk caching.
/// 2. Remembers 404 URLs in-memory so they are never retried this session.
/// 3. Shows [placeholder] while loading and [errorWidget] on failure.
class SafeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // If the URL was already known to be broken, skip the network call.
    if (imageUrl.isEmpty || _brokenUrlCache.contains(imageUrl)) {
      return _fallback();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (_, url, error) {
        // Mark this URL as broken so future rebuilds don't retry.
        _brokenUrlCache.add(url);
        return _fallback();
      },
    );
  }

  Widget _fallback() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
        );
  }

  /// Clear the broken-URL cache (e.g. after a user re-uploads media).
  static void clearBrokenCache() => _brokenUrlCache.clear();

  /// Remove a single URL from the broken cache (e.g. after re-upload).
  static void removeBrokenUrl(String url) => _brokenUrlCache.remove(url);
}
