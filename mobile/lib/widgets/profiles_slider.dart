import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../screens/provider_profile_screen.dart';
import '../services/home_feed_service.dart';
import '../models/provider.dart';

class ProfilesSlider extends StatefulWidget {
  const ProfilesSlider({super.key});

  @override
  State<ProfilesSlider> createState() => _ProfilesSliderState();
}

class _ProfilesSliderState extends State<ProfilesSlider> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  double _scrollPosition = 0;
  List<ProviderProfile> _providers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProviders();
  }

  Future<void> _fetchProviders() async {
    final list = await HomeFeedService.instance.getTopProviders(limit: 20);
    if (mounted) {
      if (list.isEmpty) {
        setState(() => _loading = false);
      } else {
        // Double the list for infinite scroll feel if small
        final loopList = list.length < 5
            ? List.generate(4, (_) => list).expand((x) => x).toList()
            : list;
        setState(() {
          _providers = loopList;
          _loading = false;
        });
        _startAutoScroll();
      }
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients && mounted && _providers.isNotEmpty) {
        _scrollPosition += 1.0;
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0 && _scrollPosition >= maxScroll) {
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

  void _openProfileDetail(BuildContext context, ProviderProfile provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderProfileScreen(
          providerId: provider.id.toString(),
          providerName: provider.displayName,
          providerImage: provider.placeholderImage,
          providerVerified: provider.isVerifiedBlue,
          // We can pass more if needed, but Detail screen should fetch full data
        ),
      ),
    );
  }

  ImageProvider _providerImage(ProviderProfile provider) {
    final raw = (provider.imageUrl ?? '').trim();
    if (raw.isEmpty) return AssetImage(provider.placeholderImage);
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return NetworkImage(raw);
    }
    return AssetImage(provider.placeholderImage);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
    if (_providers.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 140,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _providers.length,
        itemBuilder: (context, index) {
          final profile = _providers[index];
          return GestureDetector(
            onTap: () => _openProfileDetail(context, profile),
            child: Container(
              width: 90,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: AppColors.softBlue,
                        child: CircleAvatar(
                          radius: 32,
                          backgroundImage: _providerImage(profile),
                        ),
                      ),
                      if (profile.isVerifiedBlue)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Transform.translate(
                            offset: const Offset(6, 6),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified,
                                color: Colors.blue,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.displayName ?? 'مستخدم',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      overflow: TextOverflow.ellipsis,
                    ),
                    textAlign: TextAlign.center,
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
