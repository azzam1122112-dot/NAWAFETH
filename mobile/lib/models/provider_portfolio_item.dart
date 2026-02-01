class ProviderPortfolioItem {
  final int id;
  final int providerId;
  final String providerDisplayName;
  final String? providerUsername;
  final String fileType; // image | video
  final String fileUrl;
  final String caption;
  final DateTime createdAt;

  const ProviderPortfolioItem({
    required this.id,
    required this.providerId,
    required this.providerDisplayName,
    required this.providerUsername,
    required this.fileType,
    required this.fileUrl,
    required this.caption,
    required this.createdAt,
  });

  factory ProviderPortfolioItem.fromJson(Map<String, dynamic> json) {
    return ProviderPortfolioItem(
      id: json['id'],
      providerId: json['provider_id'],
      providerDisplayName: (json['provider_display_name'] ?? '').toString(),
      providerUsername: (json['provider_username'] ?? '').toString().trim().isEmpty
          ? null
          : (json['provider_username'] ?? '').toString(),
      fileType: (json['file_type'] ?? 'image').toString(),
      fileUrl: (json['file_url'] ?? '').toString(),
      caption: (json['caption'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
