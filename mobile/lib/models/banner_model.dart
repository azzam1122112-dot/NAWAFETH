/// نموذج بانر الإعلان — يطابق PromoHomeBannerAssetSerializer
class BannerModel {
  final int id;
  final int? providerId;
  final String? providerDisplayName;
  final String? providerUsername;
  final String fileType; // "image" | "video"
  final String? fileUrl;
  final String? caption;
  final String? redirectUrl;
  final String? createdAt;

  BannerModel({
    required this.id,
    this.providerId,
    this.providerDisplayName,
    this.providerUsername,
    this.fileType = 'image',
    this.fileUrl,
    this.caption,
    this.redirectUrl,
    this.createdAt,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] as int? ?? 0,
      providerId: json['provider_id'] as int?,
      providerDisplayName: json['provider_display_name'] as String?,
      providerUsername: json['provider_username'] as String?,
      fileType: json['file_type'] as String? ?? 'image',
      fileUrl: json['file_url'] as String?,
      caption: json['caption'] as String?,
      redirectUrl: json['redirect_url'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  bool get isVideo => fileType == 'video';
}
