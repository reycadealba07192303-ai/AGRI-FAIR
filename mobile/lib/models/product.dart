import '../services/api_config.dart';

/// One weight a bag comes in, with the discount the seller set for it.
///
/// The tiers are the seller's, not the app's. An earlier version computed them
/// from a hardcoded discount ladder, which meant the phone and the web could
/// quote different prices for the same sack.
class WeightTier {
  const WeightTier({required this.weightKg, required this.discountPercent});

  final double weightKg;
  final double discountPercent;

  factory WeightTier.fromJson(Map<String, dynamic> json) {
    return WeightTier(
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 1,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
    );
  }

  String get label => weightKg % 1 == 0
      ? '${weightKg.toInt()} kg'
      : '${weightKg.toStringAsFixed(1)} kg';

  double priceFrom(double pricePerKg) =>
      (pricePerKg * weightKg * (1 - discountPercent / 100)).roundToDouble();
}

/// The seller as the product screen needs them: enough for a card, not the
/// whole profile. Tapping the card loads the rest from /sellers/:id.
class ProductSeller {
  const ProductSeller({
    required this.id,
    required this.name,
    required this.isVerified,
    this.avatarUrl = '',
    this.businessName = '',
    this.averageRating = 0,
    this.productCount = 0,
  });

  final int id;
  final String name;
  final bool isVerified;
  final String avatarUrl;
  final String businessName;
  final double averageRating;
  final int productCount;

  String get displayName => businessName.isNotEmpty ? businessName : name;
  String get avatarImageUrl => ApiConfig.mediaUrl(avatarUrl);

  factory ProductSeller.fromJson(Map<String, dynamic> json) {
    return ProductSeller(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      isVerified: json['isVerified'] == true,
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
      businessName: (json['businessName'] ?? '').toString(),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      productCount: (json['productCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.variety,
    required this.pricePerKg,
    required this.description,
    required this.stock,
    required this.weightTiers,
    required this.images,
    required this.averageRating,
    required this.reviewCount,
    required this.soldCount,
    this.seller,
  });

  /// The Mongo `_id`. Every other call - cart, review, order - is addressed by
  /// it, so a product without one cannot take part in anything.
  final String id;
  final String name;
  final String variety;
  final double pricePerKg;
  final String description;
  final int stock;
  final List<WeightTier> weightTiers;
  final List<String> images;
  final double averageRating;
  final int reviewCount;
  final int soldCount;

  /// Only the detail response carries this; list rows leave it null.
  final ProductSeller? seller;

  bool get inStock => stock > 0;

  /// Images arrive server-relative (`/uploads/...`) and need the origin.
  List<String> get imageUrls => images.map(ApiConfig.mediaUrl).toList();
  String get primaryImageUrl => imageUrls.isEmpty ? '' : imageUrls.first;

  /// Falls back to a single 1 kg option so a seller who set no tiers still has
  /// something buyable, rather than a detail screen with no way to add to cart.
  List<WeightTier> get sellableTiers => weightTiers.isEmpty
      ? const [WeightTier(weightKg: 1, discountPercent: 0)]
      : (List<WeightTier>.from(weightTiers)
        ..sort((a, b) => a.weightKg.compareTo(b.weightKg)));

  double priceFor(WeightTier tier) => tier.priceFrom(pricePerKg);
  double get startingPrice => pricePerKg.roundToDouble();

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawSeller = json['seller'];

    return Product(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      // `variety` is the schema's word. `category` is only a query alias, but
      // reading both keeps this working against either spelling.
      variety: (json['variety'] ?? json['category'] ?? '').toString(),
      pricePerKg: (json['price'] as num?)?.toDouble() ?? 0,
      description: (json['description'] ?? '').toString(),
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      weightTiers: (json['weightTiers'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(WeightTier.fromJson)
              .toList() ??
          const [],
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      soldCount: (json['soldCount'] as num?)?.toInt() ?? 0,
      seller: rawSeller is Map<String, dynamic>
          ? ProductSeller.fromJson(rawSeller)
          : null,
    );
  }
}

/// The rice types the backend accepts, in the order the filter shows them.
/// `all` is the app's own row, not a value the server knows.
class RiceVariety {
  const RiceVariety(this.value, this.label);

  final String value;
  final String label;

  static const all = RiceVariety('', 'All');

  static const values = [
    all,
    RiceVariety('Jasmine', 'Jasmine'),
    RiceVariety('Sinandomeng', 'Sinandomeng'),
    RiceVariety('Brown Rice', 'Brown'),
    RiceVariety('Black Rice', 'Black'),
    RiceVariety('Red Rice', 'Red'),
    RiceVariety('Glutinous (Malagkit)', 'Malagkit'),
    RiceVariety('Other', 'Other'),
  ];
}
