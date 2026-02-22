import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/provider_portfolio_item.dart';
import '../screens/home_media_viewer_screen.dart';
import '../services/home_feed_service.dart';

class ProviderMediaGrid extends StatefulWidget {
  const ProviderMediaGrid({super.key});

  @override
  State<ProviderMediaGrid> createState() => _ProviderMediaGridState();
}

class _ProviderMediaGridState extends State<ProviderMediaGrid> {
  final HomeFeedService _feed = HomeFeedService.instance;
  bool _loading = true;
  List<ProviderPortfolioItem> _items = const [];

  Future<void> _openItem(BuildContext context, ProviderPortfolioItem item) async {
    final idx = _items.indexWhere((e) => e.id == item.id);
    final initial = idx < 0 ? 0 : idx;
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: HomeMediaViewerScreen(
            items: _items,
            initialIndex: initial,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await _feed.getMediaItems(limit: 12);

      if (!mounted) return;
      setState(() {
        _items = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_items.isEmpty) return const SizedBox.shrink();

    final cardWidth = (MediaQuery.of(context).size.width - 48) / 2;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _items.map((item) {
              final isVideo = item.fileType.toLowerCase().contains('video');
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openItem(context, item),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: cardWidth,
                    height: 136,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.20)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (!isVideo)
                          Image.network(
                            item.fileUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stackTrace) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                            ),
                          )
                        else
                          Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: Icon(Icons.videocam_rounded, color: Colors.grey.shade600, size: 34),
                          ),
                        if (isVideo)
                          Center(
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
