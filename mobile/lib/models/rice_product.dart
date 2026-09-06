import 'package:flutter/material.dart';

class RiceWeightOption {
  final String label;
  final double kg;
  final double price;

  const RiceWeightOption({
    required this.label,
    required this.kg,
    required this.price,
  });
}

class RiceCategory {
  final String id;
  final String label;
  final IconData icon;
  const RiceCategory(this.id, this.label, this.icon);
}

class RiceProduct {
  final String name;
  final String category;
  final double basePricePerKg;
  final double rating;
  final int sold;
  final Color tagColor;
  final String tag;
  final String description;
  final String imagePath;

  const RiceProduct({
    required this.name,
    required this.category,
    required this.basePricePerKg,
    required this.rating,
    required this.sold,
    required this.tagColor,
    required this.tag,
    required this.description,
    required this.imagePath,
  });

  List<RiceWeightOption> get weightOptions => [
        RiceWeightOption(label: '1 kg', kg: 1, price: _p(basePricePerKg * 1)),
        RiceWeightOption(label: '5 kg', kg: 5, price: _p(basePricePerKg * 5 * 0.95)),
        RiceWeightOption(label: '10 kg', kg: 10, price: _p(basePricePerKg * 10 * 0.90)),
        RiceWeightOption(label: '25 kg', kg: 25, price: _p(basePricePerKg * 25 * 0.85)),
        RiceWeightOption(label: '50 kg', kg: 50, price: _p(basePricePerKg * 50 * 0.80)),
      ];

  double get startingPrice => _p(basePricePerKg);

  static double _p(double v) => v.roundToDouble();
}

const riceCategories = [
  RiceCategory('all', 'All', Icons.grid_view_rounded),
  RiceCategory('white', 'White Rice', Icons.rice_bowl_outlined),
  RiceCategory('brown', 'Brown Rice', Icons.eco_outlined),
  RiceCategory('jasmine', 'Jasmine', Icons.local_florist_outlined),
  RiceCategory('glutinous', 'Glutinous', Icons.water_drop_outlined),
  RiceCategory('specialty', 'Specialty', Icons.star_outline_rounded),
];

const riceProducts = [
  RiceProduct(
    name: 'Premium Jasmine Rice',
    category: 'jasmine',
    basePricePerKg: 64,
    rating: 4.9,
    sold: 1240,
    tagColor: Color(0xFF8DB89A),
    tag: 'Best Seller',
    description:
        'Aromatic long-grain jasmine rice with a delicate floral fragrance. '
        'Sourced from premium farms in Northern Luzon, this rice cooks up '
        'fluffy and slightly sticky—perfect for everyday meals or special occasions.',
    imagePath: 'assets/products/jasmine.png',
  ),
  RiceProduct(
    name: 'Sinandomeng Rice',
    category: 'white',
    basePricePerKg: 50,
    rating: 4.8,
    sold: 980,
    tagColor: Color(0xFF4A7C59),
    tag: 'Popular',
    description:
        'The classic Filipino all-day rice. Sinandomeng is known for its '
        'mild aroma and clean taste that pairs perfectly with any viand. '
        'A staple in Filipino households for generations.',
    imagePath: 'assets/products/sinandomeng.png',
  ),
  RiceProduct(
    name: 'Organic Brown Rice',
    category: 'brown',
    basePricePerKg: 90,
    rating: 4.7,
    sold: 730,
    tagColor: Color(0xFFC9A96E),
    tag: 'Organic',
    description:
        'Unpolished whole-grain brown rice packed with fiber, vitamins, and '
        'minerals. Certified organic and naturally processed to retain all '
        'its nutritional benefits. Ideal for health-conscious individuals.',
    imagePath: 'assets/products/brown.png',
  ),
  RiceProduct(
    name: 'Dinorado Rice',
    category: 'white',
    basePricePerKg: 90,
    rating: 4.9,
    sold: 620,
    tagColor: Color(0xFF4A7C59),
    tag: 'Premium',
    description:
        'An heirloom aromatic variety from the Mountain Province. Dinorado '
        'rice has a distinct sweet fragrance and a soft, slightly sticky '
        'texture when cooked. Often reserved for special occasions.',
    imagePath: 'assets/products/dinorado.png',
  ),
  RiceProduct(
    name: 'Glutinous Malagkit',
    category: 'glutinous',
    basePricePerKg: 76,
    rating: 4.6,
    sold: 410,
    tagColor: Color(0xFF8DB89A),
    tag: 'Local',
    description:
        'Traditional sticky glutinous rice, the key ingredient in beloved '
        'Filipino delicacies like kakanin, suman, and biko. Naturally sweet '
        'flavor with a chewy, sticky texture after cooking.',
    imagePath: 'assets/products/malagkit.png',
  ),
  RiceProduct(
    name: 'Black Rice',
    category: 'specialty',
    basePricePerKg: 220,
    rating: 4.8,
    sold: 390,
    tagColor: Color(0xFF1B3829),
    tag: 'Rare',
    description:
        'An ancient grain packed with powerful antioxidants and anthocyanins. '
        'Black rice turns deep purple when cooked and has a rich, nutty flavor. '
        'A premium choice for health-focused and gourmet cooking.',
    imagePath: 'assets/products/black.png',
  ),
  RiceProduct(
    name: 'Red Cargo Rice',
    category: 'specialty',
    basePricePerKg: 98,
    rating: 4.5,
    sold: 310,
    tagColor: Color(0xFFC9A96E),
    tag: 'Healthy',
    description:
        'Minimally processed red cargo rice retains its bran layer, providing '
        'a rich earthy flavor and superior nutritional value. High in fiber '
        'and essential minerals for a wholesome diet.',
    imagePath: 'assets/products/red_cargo.png',
  ),
  RiceProduct(
    name: 'Basmati Rice',
    category: 'specialty',
    basePricePerKg: 280,
    rating: 4.7,
    sold: 280,
    tagColor: Color(0xFF4A7C59),
    tag: 'Imported',
    description:
        'Premium imported long-grain basmati rice with a signature nutty aroma '
        'and non-sticky texture when cooked. Ideal for biryani, pilaf, and '
        'gourmet rice dishes. Aged for enhanced fragrance.',
    imagePath: 'assets/products/basmati.png',
  ),
];
