import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/provider.dart';
import '../screens/provider_profile_screen.dart';
import '../services/home_feed_service.dart';

class VideoReels extends StatefulWidget {
  const VideoReels({super.key});

  @override
  State<VideoReels> createState() => _VideoReelsState();
}

class _VideoReelsState extends State<VideoReels> {
  final HomeFeedService _feed = HomeFeedService.instance;
  bool _loading = true;
  List<ProviderProfile> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final providers = await _feed.getTopProviders(limit: 12);
      if (!mounted) return;
      setState(() {
        _items = providers;
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

  ImageProvider _providerImage(ProviderProfile p) {
    final raw = (p.imageUrl ?? '').trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return NetworkImage(raw);
    }
    return AssetImage(p.placeholderImage);
  }

  void _openProvider(ProviderProfile p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderProfileScreen(
          providerId: p.id.toString(),
          providerName: p.displayName,
          providerImage: p.placeholderImage,
          providerVerified: p.isVerifiedBlue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 112,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final p = _items[index];
          return GestureDetector(
            onTap: () => _openProvider(p),
            child: Container(
              width: 88,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    padding: const EdgeInsets.all(2),
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
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: CircleAvatar(
                        backgroundImage: _providerImage(p),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (p.displayName ?? 'مزود').trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.softBlue,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
