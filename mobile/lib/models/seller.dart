import '../services/api_config.dart';

/// A seller's public face, as the backend chooses to show it.
///
/// There is no document file or reference number here, and no payout account,
/// because the API does not send them: a buyer sees that a permit passed
/// review, never the permit. Do not add fields hoping the server will fill
/// them - it will not.
class SellerProfile {
  const SellerProfile({
    required this.id,
    required this.name,
    required this.isVerified,
    required this.verifiedCredentials,
    required this.acceptsGcash,
    required this.averageRating,
    required this.reviewCount,
    required this.productCount,
    required this.totalSold,
    this.avatarUrl = '',
    this.bio = '',
    this.sellerType = '',
    this.businessName = '',
    this.farmName = '',
    this.farmLocation = '',
    this.farmSize = '',
    this.farmPhotos = const [],
    this.memberSince,
  });

  final int id;
  final String name;
  final bool isVerified;

  /// Which kinds of permit passed review - `BIR`, `DTI`, `MAYORS_PERMIT`...
  final List<String> verifiedCredentials;
  final bool acceptsGcash;

  final double averageRating;
  final int reviewCount;
  final int productCount;
  final int totalSold;

  final String avatarUrl;
  final String bio;
  final String sellerType;
  final String businessName;
  final String farmName;
  final String farmLocation;
  final String farmSize;
  final List<String> farmPhotos;
  final DateTime? memberSince;

  String get displayName => businessName.isNotEmpty ? businessName : name;
  String get avatarImageUrl => ApiConfig.mediaUrl(avatarUrl);
  List<String> get farmPhotoUrls => farmPhotos.map(ApiConfig.mediaUrl).toList();

  /// A trader or retailer has no farm, so the farm block is hidden rather than
  /// shown with blank labels.
  bool get hasFarm => farmName.isNotEmpty || farmLocation.isNotEmpty;

  String get sellerTypeLabel {
    switch (sellerType) {
      case 'farmer':
        return 'Farmer';
      case 'trader':
        return 'Trader';
      case 'retailer':
        return 'Retailer';
      case 'cooperative':
        return 'Cooperative';
      default:
        return 'Seller';
    }
  }

  static const _credentialLabels = {
    'BIR': 'BIR registration',
    'DTI': 'DTI registration',
    'SEC': 'SEC registration',
    'MAYORS_PERMIT': "Mayor's permit",
    'BARANGAY': 'Barangay clearance',
    'ORGANIC_CERT': 'Organic certification',
    'OTHER': 'Other document',
  };

  static String credentialLabel(String code) =>
      _credentialLabels[code] ?? code;

  factory SellerProfile.fromJson(Map<String, dynamic> json) {
    return SellerProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      isVerified: json['isVerified'] == true,
      verifiedCredentials: (json['verifiedCredentials'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      acceptsGcash: json['acceptsGcash'] == true,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      productCount: (json['productCount'] as num?)?.toInt() ?? 0,
      totalSold: (json['totalSold'] as num?)?.toInt() ?? 0,
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
      bio: (json['bio'] ?? '').toString(),
      sellerType: (json['sellerType'] ?? '').toString(),
      businessName: (json['businessName'] ?? '').toString(),
      farmName: (json['farmName'] ?? '').toString(),
      farmLocation: (json['farmLocation'] ?? '').toString(),
      farmSize: (json['farmSize'] ?? '').toString(),
      farmPhotos: (json['farmPhotos'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      memberSince: DateTime.tryParse((json['memberSince'] ?? '').toString()),
    );
  }
}

/// A shop as it appears in the directory - enough for a card, not the whole
/// profile. Tapping one loads [SellerProfile] from /sellers/:id.
class ShopSummary {
  const ShopSummary({
    required this.id,
    required this.name,
    required this.isVerified,
    required this.productCount,
    required this.totalSold,
    required this.varieties,
    required this.fromPrice,
    required this.averageRating,
    required this.reviewCount,
    this.businessName = '',
    this.avatarUrl = '',
    this.sellerType = '',
    this.farmLocation = '',
  });

  final int id;
  final String name;
  final bool isVerified;
  final int productCount;
  final int totalSold;

  /// Which kinds of rice this shop actually stocks, so a card can say so
  /// without fetching every listing to find out.
  final List<String> varieties;
  final double fromPrice;
  final double averageRating;
  final int reviewCount;
  final String businessName;
  final String avatarUrl;
  final String sellerType;
  final String farmLocation;

  String get displayName => businessName.isNotEmpty ? businessName : name;
  String get avatarImageUrl => ApiConfig.mediaUrl(avatarUrl);

  String get varietyLine => varieties.isEmpty
      ? 'Rice'
      : varieties.length <= 2
          ? varieties.join(' · ')
          : '${varieties.take(2).join(' · ')} +${varieties.length - 2}';

  factory ShopSummary.fromJson(Map<String, dynamic> json) {
    return ShopSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      isVerified: json['isVerified'] == true,
      productCount: (json['productCount'] as num?)?.toInt() ?? 0,
      totalSold: (json['totalSold'] as num?)?.toInt() ?? 0,
      varieties:
          (json['varieties'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      fromPrice: (json['fromPrice'] as num?)?.toDouble() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      businessName: (json['businessName'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
      sellerType: (json['sellerType'] ?? '').toString(),
      farmLocation: (json['farmLocation'] ?? '').toString(),
    );
  }
}
