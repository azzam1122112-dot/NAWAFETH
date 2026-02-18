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
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_scrollController.hasClients && mounted && _providers.isNotEmpty) {
        _scrollPosition += 116.0; // card width + spacing
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0 && _scrollPosition >= maxScroll) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOut,
          );
          _scrollPosition = 0;
        } else {
          _scrollController.animateTo(
            _scrollPosition,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOut,
          );
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
          providerImage: provider.imageUrl,
          providerVerified: provider.isVerifiedBlue,
          // We can pass more if needed, but Detail screen should fetch full data
        ),
      ),
    );
  }

  ImageProvider? _providerImage(ProviderProfile provider) {
    final raw = (provider.imageUrl ?? '').trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return NetworkImage(raw);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 78, child: Center(child: CircularProgressIndicator()));
    if (_providers.isEmpty) return const SizedBox(height: 8);

    return SizedBox(
      height: 82,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _providers.length,
        itemBuilder: (context, index) {
          final profile = _providers[index];
          final avatar = _providerImage(profile);
          return GestureDetector(
            onTap: () => _openProfileDetail(context, profile),
            child: Container(
              width: 84,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.18)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.softBlue,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundImage: avatar,
                          child: avatar == null
                              ? const Icon(Icons.person, color: Colors.white, size: 18)
                              : null,
                        ),
                      ),
                      Positioned(
                        left: -2,
                        top: -2,
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (profile.ratingAvg > 0 ? profile.ratingAvg.round() : 4).toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
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
