import 'package:flutter/foundation.dart';

@immutable
class ProviderCompletionUtils {
  const ProviderCompletionUtils._();

  static const double baseCompletionMax = 0.30; // 30%
  static const int optionalTotalPercent = 70; // 70%

  static const List<String> sectionKeys = <String>[
    'service_details',
    'additional',
    'contact_full',
    'lang_loc',
    'content',
    'seo',
  ];

  static double baseCompletionFromMe(
    Map<String, dynamic>? me, {
    double baseMax = baseCompletionMax,
  }) {
    if (me == null) return 0.0;

    bool hasName() {
      final first = (me['first_name'] ?? '').toString().trim();
      final last = (me['last_name'] ?? '').toString().trim();
      final user = (me['username'] ?? '').toString().trim();
      return first.isNotEmpty || last.isNotEmpty || user.isNotEmpty;
    }

    bool hasPhone() => (me['phone'] ?? '').toString().trim().isNotEmpty;
    bool hasEmail() => (me['email'] ?? '').toString().trim().isNotEmpty;

    final parts = <bool>[hasName(), hasPhone(), hasEmail()];
    final done = parts.where((v) => v).length;
    final ratio = done / parts.length;
    return (baseMax * ratio).clamp(0.0, baseMax);
  }

  static Map<String, int> buildSectionWeights({
    List<String> keys = sectionKeys,
    int total = optionalTotalPercent,
  }) {
    // توزيع ثابت بدون كسور:
    // total / keys.length = base والباقي موزع 1% على أول عناصر بالترتيب.
    final base = total ~/ keys.length;
    var remainder = total - (base * keys.length);

    final weights = <String, int>{};
    for (final k in keys) {
      final extra = remainder > 0 ? 1 : 0;
      if (remainder > 0) remainder -= 1;
      weights[k] = base + extra;
    }
    return weights;
  }

  static double completionPercent({
    required Map<String, dynamic>? me,
    required Map<String, bool> sectionDone,
    Map<String, int>? weights,
    double baseMax = baseCompletionMax,
  }) {
    final w = weights ?? buildSectionWeights();
    final completedOptional = sectionDone.entries
        .where((e) => e.value)
        .fold<int>(0, (sum, e) => sum + (w[e.key] ?? 0));

    return (baseCompletionFromMe(me, baseMax: baseMax) + (completedOptional / 100.0)).clamp(0.0, 1.0);
  }
}
