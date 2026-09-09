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

/// The sack sizes rice is sold in across the Philippines.
///
/// Every one of these is shown on every product, whether or not the seller
/// offers it, because a buyer looking for a 5 kg bag needs to see that it is
/// not sold here - an absent option is indistinguishable from an option that
/// was never scrolled to.
const List<double> kStandardWeightsKg = [1, 2, 5, 10, 25, 50];

/// One weight as the buyer meets it: its price, and whether it can be bought.
///
/// Two separate things stop a size being buyable, and they need different
/// words. The seller may not sell that size at all, or they may sell it and
/// have run too low - "only 10 kg left" makes 25 kg and 50 kg unbuyable even
/// though both are on the list.
class WeightOption {
  const WeightOption({
    required this.tier,
    required this.price,
    required this.offered,
    required this.inStock,
  });

  final WeightTier tier;
  final double price;
  final bool offered;
  final bool inStock;

  bool get available => offered && inStock;
  double get weightKg => tier.weightKg;
  String get label => tier.label;

  String get unavailableReason => offered
      ? 'Not enough stock left for this size'
      : 'This seller does not sell this size';
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

  /// Every standard size, plus anything non-standard the seller added, in
  /// ascending order - each marked with whether it can actually be bought.
  ///
  /// The seller's own tier is used where there is one, so their bulk discount
  /// is applied; the rest are priced straight off the per-kilo rate, which is
  /// what they would cost if the seller did sell them.
  List<WeightOption> get weightOptions {
    final offered = {for (final t in sellableTiers) t.weightKg: t};
    final weights = {...kStandardWeightsKg, ...offered.keys}.toList()..sort();

    return [
      for (final kg in weights)
        WeightOption(
          tier: offered[kg] ?? WeightTier(weightKg: kg, discountPercent: 0),
          price: priceFor(offered[kg] ?? WeightTier(weightKg: kg, discountPercent: 0)),
          offered: offered.containsKey(kg),
          // Stock is kept in kilograms, so one sack of this size has to fit
          // inside what is left.
          inStock: stock >= kg,
        ),
    ];
  }

  /// The cheapest size somebody can actually put in a basket, or null when the
  /// seller has nothing left that fits any size they sell.
  WeightOption? get firstAvailableOption {
    for (final option in weightOptions) {
      if (option.available) return option;
    }
    return null;
  }

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
