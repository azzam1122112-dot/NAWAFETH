import '../models/provider.dart';
import '../models/provider_portfolio_item.dart';
import 'providers_api.dart';
import 'reviews_api.dart';

class HomeFeedService {
  HomeFeedService._();

  static final HomeFeedService instance = HomeFeedService._();

  final ProvidersApi _providersApi = ProvidersApi();
  final ReviewsApi _reviewsApi = ReviewsApi();

  static const Duration _ttl = Duration(minutes: 3);

  DateTime? _providersAt;
  List<ProviderProfile>? _providersCache;
  Future<List<ProviderProfile>>? _providersInFlight;

  DateTime? _portfolioAt;
  List<ProviderPortfolioItem>? _portfolioCache;
  Future<List<ProviderPortfolioItem>>? _portfolioInFlight;

  DateTime? _testimonialsAt;
  List<Map<String, dynamic>>? _testimonialsCache;
  Future<List<Map<String, dynamic>>>? _testimonialsInFlight;

  bool _isFresh(DateTime? at) {
    if (at == null) return false;
    return DateTime.now().difference(at) <= _ttl;
  }

  List<ProviderProfile> _rankProviders(List<ProviderProfile> providers) {
    final list = [...providers];
    list.sort((a, b) {
      final likesCmp = b.likesCount.compareTo(a.likesCount);
      if (likesCmp != 0) return likesCmp;
      final ratingCmp = b.ratingAvg.compareTo(a.ratingAvg);
      if (ratingCmp != 0) return ratingCmp;
      return b.followersCount.compareTo(a.followersCount);
    });
    return list;
  }

  Future<List<ProviderProfile>> getProviders({bool forceRefresh = false}) async {
    if (!forceRefresh && _providersCache != null && _isFresh(_providersAt)) {
      return _providersCache!;
    }
    if (!forceRefresh && _providersInFlight != null) {
      return _providersInFlight!;
    }

    final future = _providersApi.getProviders().then(_rankProviders);
    _providersInFlight = future;
    try {
      final data = await future;
      _providersCache = data;
      _providersAt = DateTime.now();
      return data;
    } finally {
      _providersInFlight = null;
    }
  }

  Future<List<ProviderProfile>> getTopProviders({
    int limit = 12,
    bool forceRefresh = false,
  }) async {
    final providers = await getProviders(forceRefresh: forceRefresh);
    return providers.take(limit).toList();
  }

  Future<List<ProviderPortfolioItem>> _getPortfolioPool({bool forceRefresh = false}) async {
    if (!forceRefresh && _portfolioCache != null && _isFresh(_portfolioAt)) {
      return _portfolioCache!;
    }
    if (!forceRefresh && _portfolioInFlight != null) {
      return _portfolioInFlight!;
    }

    final future = () async {
      final providers = await getTopProviders(limit: 8, forceRefresh: forceRefresh);
      if (providers.isEmpty) return <ProviderPortfolioItem>[];

      final portfolios = await Future.wait(
        providers.map((p) => _providersApi.getProviderPortfolio(p.id)),
      );

      final merged = <ProviderPortfolioItem>[
        for (final list in portfolios) ...list.where((e) => e.fileUrl.trim().isNotEmpty),
      ];
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged;
    }();

    _portfolioInFlight = future;
    try {
      final data = await future;
      _portfolioCache = data;
      _portfolioAt = DateTime.now();
      return data;
    } finally {
      _portfolioInFlight = null;
    }
  }

  Future<List<ProviderPortfolioItem>> getBannerItems({
    int limit = 6,
    bool forceRefresh = false,
  }) async {
    final pool = await _getPortfolioPool(forceRefresh: forceRefresh);
    return pool.take(limit).toList();
  }

  Future<List<ProviderPortfolioItem>> getMediaItems({
    int limit = 12,
    bool forceRefresh = false,
  }) async {
    final pool = await _getPortfolioPool(forceRefresh: forceRefresh);
    return pool.take(limit).toList();
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString());
  }

  Future<List<Map<String, dynamic>>> getTestimonials({
    int limit = 8,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _testimonialsCache != null && _isFresh(_testimonialsAt)) {
      return _testimonialsCache!.take(limit).toList();
    }
    if (!forceRefresh && _testimonialsInFlight != null) {
      final data = await _testimonialsInFlight!;
      return data.take(limit).toList();
    }

    final future = () async {
      final providers = await getTopProviders(limit: 8, forceRefresh: forceRefresh);
      if (providers.isEmpty) return <Map<String, dynamic>>[];

      final reviewsByProvider = await Future.wait(
        providers.map((p) async {
          final reviews = await _reviewsApi.getProviderReviews(p.id);
          return {'provider': p, 'reviews': reviews};
        }),
      );

      final items = <Map<String, dynamic>>[];
      for (final row in reviewsByProvider) {
        final reviews = (row['reviews'] as List).whereType<Map>().toList();
        for (final raw in reviews) {
          final review = Map<String, dynamic>.from(raw);
          final comment = (review['comment'] ?? '').toString().trim();
          if (comment.isEmpty) continue;
          final rating = (_asInt(review['rating']) ?? 5).clamp(1, 5);
          items.add({
            'name': (review['client_name'] ?? review['client_phone'] ?? 'عميل').toString(),
            'comment': comment,
            'rating': rating,
          });
          if (items.length >= 20) break;
        }
        if (items.length >= 20) break;
      }
      return items;
    }();

    _testimonialsInFlight = future;
    try {
      final data = await future;
      _testimonialsCache = data;
      _testimonialsAt = DateTime.now();
      return data.take(limit).toList();
    } finally {
      _testimonialsInFlight = null;
    }
  }
}
