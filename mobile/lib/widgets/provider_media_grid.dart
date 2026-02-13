import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/provider_portfolio_item.dart';
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
  int _visibleCount = 4;

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

    final visibleMedia = _items.take(_visibleCount).toList();
    final cardWidth = (MediaQuery.of(context).size.width - 48) / 2;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: visibleMedia.map((item) {
              final isVideo = item.fileType.toLowerCase().contains('video');
              return Container(
                width: cardWidth,
                height: 128,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.20)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      item.fileUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                      ),
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
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (_items.length > 4)
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (_visibleCount < _items.length) {
                      _visibleCount = (_visibleCount + 4).clamp(0, _items.length);
                    } else {
                      _visibleCount = 4;
                    }
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(
                  _visibleCount < _items.length ? Icons.expand_more : Icons.expand_less,
                  size: 20,
                ),
                label: Text(
                  _visibleCount < _items.length ? 'عرض المزيد' : 'عرض أقل',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
