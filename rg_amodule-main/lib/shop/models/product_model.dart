// lib/shop/models/product_model.dart

enum ProductCategory {
  all,
  satyanarayanKit,
  grihPraveshKit,
  marriageKit,
  navgrahaKit;

  String get label {
    switch (this) {
      case ProductCategory.all:
        return 'All';
      case ProductCategory.satyanarayanKit:
        return 'Satyanarayan Kit';
      case ProductCategory.grihPraveshKit:
        return 'Grih Pravesh Kit';
      case ProductCategory.marriageKit:
        return 'Marriage Kit';
      case ProductCategory.navgrahaKit:
        return 'Navgraha Kit';
    }
  }

  String get shortLabel {
    switch (this) {
      case ProductCategory.all:
        return 'All';
      case ProductCategory.satyanarayanKit:
        return 'Satyanarayan';
      case ProductCategory.grihPraveshKit:
        return 'Grih Pravesh';
      case ProductCategory.marriageKit:
        return 'Marriage';
      case ProductCategory.navgrahaKit:
        return 'Navgraha';
    }
  }
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePaise,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.stock,
    required this.includes,
    this.isBestSeller = false,
    this.imageAsset,
  });

  final String id;
  final String name;
  final String description;

  /// Price in paise (1 INR = 100 paise).
  final int pricePaise;
  final ProductCategory category;
  final double rating;
  final int reviewCount;
  final int stock;

  /// Bullet list of items included in the kit.
  final List<String> includes;
  final bool isBestSeller;

  /// Optional local asset path, e.g. 'assets/images/image9.jpg'.
  final String? imageAsset;

  // ── Computed ──────────────────────────────────────────────────────────────

  /// e.g. "₹599"
  String get formattedPrice {
    final rupees = pricePaise ~/ 100;
    if (rupees >= 1000) {
      return '₹${(rupees / 1000).toStringAsFixed(rupees % 1000 == 0 ? 0 : 1)}k';
    }
    return '₹$rupees';
  }

  /// Full price string without abbreviation, e.g. "₹1,499"
  String get formattedPriceFull {
    final rupees = pricePaise ~/ 100;
    final str = rupees.toString();
    if (str.length > 3) {
      final pre = str.substring(0, str.length - 3);
      final post = str.substring(str.length - 3);
      return '₹$pre,$post';
    }
    return '₹$str';
  }

  bool get inStock => stock > 0;
}

// ── Mock Catalogue ────────────────────────────────────────────────────────────

final kMockProducts = <ProductModel>[
  // ── Satyanarayan Kit ──────────────────────────────────────────────────────
  const ProductModel(
    id: 'prod_001',
    name: 'Satyanarayan Puja Basic Kit',
    description:
        'Everything you need to perform the traditional Satyanarayan Puja at home. '
        'This carefully assembled kit includes all essential samagri as '
        'prescribed in Skanda Purana. Perfect for family rituals and festivals.',
    pricePaise: 59900,
    category: ProductCategory.satyanarayanKit,
    rating: 4.5,
    reviewCount: 234,
    stock: 50,
    imageAsset: 'assets/images/image5.jpg',
    includes: [
      'Satyanarayan Katha book',
      'Panchamrit ingredients (milk, curd, honey, sugar, ghee)',
      'Banana leaves (10 pcs)',
      'Sandalwood paste & kumkum',
      'Mauli (sacred thread)',
      'Camphor & agarbatti set',
      'Puja plate (thali)',
    ],
  ),
  const ProductModel(
    id: 'prod_002',
    name: 'Satyanarayan Puja Deluxe Kit',
    description:
        'An enhanced puja kit with premium quality samagri and a brass idol. '
        'Ideal for special occasions and annual celebrations of Satyanarayan Vrat.',
    pricePaise: 79900,
    category: ProductCategory.satyanarayanKit,
    rating: 4.7,
    reviewCount: 189,
    stock: 30,
    isBestSeller: true,
    imageAsset: 'assets/images/image9.jpg',
    includes: [
      'Satyanarayan Katha book (illustrated)',
      'Panchamrit set (premium)',
      'Banana leaves & flowers (variety pack)',
      'Brass Vishnu idol (4 inch)',
      'Sandalwood paste, kumkum & haldi',
      'Mauli & kalava threads',
      'Camphor, dhoop & premium agarbatti',
      'Copper puja thali set',
      'Supari & dry fruits mix',
    ],
  ),
  const ProductModel(
    id: 'prod_003',
    name: 'Satyanarayan Premium Kit with Idol',
    description:
        'Premium grade puja samagri sourced from Varanasi, featuring a hand-crafted '
        'brass Lord Vishnu idol and all ritual requisites for a grand ceremony.',
    pricePaise: 109900,
    category: ProductCategory.satyanarayanKit,
    rating: 4.8,
    reviewCount: 97,
    stock: 15,
    imageAsset: 'assets/images/image5.jpg',
    includes: [
      'Hand-crafted Brass Vishnu Idol (6 inch)',
      'Satyanarayan Katha & Chalisa book set',
      'Panchamrit premium set',
      'Varanasi-sourced floral arrangement',
      'Complete sindoor & abir set',
      'Copper kalash & puja items',
      'Premium dhoop, camphor & agarbatti',
      'Prasad mix (sheera ingredients)',
      'Puja cloth & betel leaves pack',
      'Mauli, janeu & sacred items set',
    ],
  ),

  // ── Grih Pravesh Kit ──────────────────────────────────────────────────────
  const ProductModel(
    id: 'prod_004',
    name: 'Grih Pravesh Essential Kit',
    description:
        'A compact yet complete kit for the auspicious Grih Pravesh ceremony. '
        'Moving into a new home is a sacred milestone — begin it the right way.',
    pricePaise: 79900,
    category: ProductCategory.grihPraveshKit,
    rating: 4.4,
    reviewCount: 156,
    stock: 40,
    imageAsset: 'assets/images/image10.jpg',
    includes: [
      'Kumkum & haldi pack',
      'Coconut (1 pc) & betel leaves',
      'Mango leaf torans (2 strings)',
      'Mauli & red cloth',
      'Camphor, dhoop & agarbatti',
      'Kalash & mud pot set',
      'Supari & dry fruits pouch',
    ],
  ),
  const ProductModel(
    id: 'prod_005',
    name: 'Grih Pravesh Deluxe Kit',
    description:
        'Complete housewarming ceremony kit with Vastu Shanti items, premium '
        'decorative torans, and all traditional samagri. Makes the new home auspicious.',
    pricePaise: 119900,
    category: ProductCategory.grihPraveshKit,
    rating: 4.6,
    reviewCount: 203,
    stock: 25,
    isBestSeller: true,
    imageAsset: 'assets/images/image10.jpg',
    includes: [
      'Vastu Yantra (copper plated)',
      'Premium mango leaf & marigold toran',
      'Laxmi-Ganesh idol pair (3 inch)',
      'Copper kalash + coconut set',
      'Complete kumkum, haldi, sindoor pack',
      'Camphor, loban & premium dhoop',
      'Mauli, kalava & janeu set',
      'Turmeric rootlets (7 pcs)',
      'Puja thali with diya set',
    ],
  ),
  const ProductModel(
    id: 'prod_006',
    name: 'Grih Pravesh Premium Kit',
    description:
        'The complete premium package for a grand housewarming ceremony including '
        'Vastu Shanti samagri, Navgraha plants, silver coins, and more.',
    pricePaise: 179900,
    category: ProductCategory.grihPraveshKit,
    rating: 4.8,
    reviewCount: 74,
    stock: 10,
    imageAsset: 'assets/images/image11.jpg',
    includes: [
      'Silver-plated Laxmi-Ganesh idol pair',
      'Vastu Yantra (silver plated)',
      'Navgraha herbs & plants set',
      'Premium toran & rangoli set',
      'Complete samagri × 2 (main + backup)',
      'Copper kalash & copper thali set',
      'Silver coin (2 pcs) — for door',
      'Camphor, loban, premium agarbatti × 3',
      'Full flower decoration pack',
      'Prasad distribution box',
    ],
  ),

  // ── Marriage Kit ──────────────────────────────────────────────────────────
  const ProductModel(
    id: 'prod_007',
    name: 'Vivah Puja Basic Kit',
    description:
        'Essential samagri for a traditional Hindu wedding ceremony. Contains '
        'all ritual items required for Kanyadaan, Saptapadi, and Mangalsutra rituals.',
    pricePaise: 149900,
    category: ProductCategory.marriageKit,
    rating: 4.6,
    reviewCount: 322,
    stock: 35,
    imageAsset: 'assets/images/image11.jpg',
    includes: [
      'Laja (puffed rice) 1 kg',
      'Sindoor & alta set',
      'Mangalsutra thread (raw)',
      'Kumkum, haldi & turmeric pack',
      'Mauli & sacred threads set',
      'Camphor, dhoop, agarbatti',
      'Betel leaves & supari (100 pcs)',
      'Puja ghee (pure cow) 250 ml',
      'Kalash, coconut & mango leaves',
    ],
  ),
  const ProductModel(
    id: 'prod_008',
    name: 'Vivah Puja Complete Kit',
    description:
        'Comprehensive wedding ceremony kit covering all major rituals — from '
        'Ganesh Puja and Var Mala to Saptapadi and Grih Pravesh after marriage.',
    pricePaise: 249900,
    category: ProductCategory.marriageKit,
    rating: 4.8,
    reviewCount: 418,
    stock: 20,
    isBestSeller: true,
    imageAsset: 'assets/images/image9.jpg',
    includes: [
      'Ganesh idol for mandap',
      'Full Saptapadi samagri set',
      'Laja × 2 kg, sindoor, alta',
      'Mangalsutra thread + chain',
      'Yagya kund (small) + havan samagri',
      'Coconut × 5, kalash × 2',
      'Puja ghee (pure) 500 ml',
      'Complete flower & decoration pack',
      'Betel leaves & dry fruits (bulk)',
      'Sacred thread sets (bride & groom)',
      'Thali set (5 pcs) + silver diyas',
    ],
  ),
  const ProductModel(
    id: 'prod_009',
    name: 'Wedding Samagri Premium Pack',
    description:
        'The most elaborate wedding puja kit for grand ceremonies. Includes '
        'all items for multiple-day rituals, havan, and post-ceremony puja.',
    pricePaise: 399900,
    category: ProductCategory.marriageKit,
    rating: 4.9,
    reviewCount: 211,
    stock: 8,
    imageAsset: 'assets/images/image11.jpg',
    includes: [
      'Full 3-day ceremony samagri',
      'Havan kund (medium) + materials',
      'Mahurat Ganesh & Laxmi idol set',
      'Premium sindoor & decoration pack',
      'Silver-plated puja thali set (pair)',
      'Navgraha puja add-on items',
      'Bulk betel, flower & dry fruit packs',
      'Pure ghee × 2 litres',
      'Kundali-based custom muhurat card',
      'Shagun envelope & blessings pack',
    ],
  ),

  // ── Navgraha Kit ──────────────────────────────────────────────────────────
  const ProductModel(
    id: 'prod_010',
    name: 'Navgraha Shanti Kit',
    description:
        'Perform Navgraha Shanti puja at home to pacify and strengthen all '
        'nine planetary deities. Based on traditional Vedic methodology.',
    pricePaise: 69900,
    category: ProductCategory.navgrahaKit,
    rating: 4.5,
    reviewCount: 178,
    stock: 45,
    imageAsset: 'assets/images/image6.jpg',
    includes: [
      'Navgraha yantra (copper)',
      'Nine coloured cloths (1 each)',
      'Nine grain set (nava dhanya)',
      'Navgraha specific flowers & leaves',
      'Sesame (til), jaggery & rice',
      'Camphor, dhoop & agarbatti set',
      'Mauli & nine colour threads',
    ],
  ),
  const ProductModel(
    id: 'prod_011',
    name: 'Navgraha Pooja Complete Kit',
    description:
        'A thorough Navgraha puja kit with individual dravyas for each planet, '
        'individual coloured diyas, and a detailed procedure booklet.',
    pricePaise: 99900,
    category: ProductCategory.navgrahaKit,
    rating: 4.7,
    reviewCount: 145,
    stock: 28,
    isBestSeller: true,
    imageAsset: 'assets/images/image6.jpg',
    includes: [
      'Navgraha yantra (silver-plated)',
      'Nine individual puja sets (1 per planet)',
      'Nava dhanya + navgraha flower pack',
      'Nine coloured diyas',
      'Pure ghee 200 ml',
      'Havan samagri (navgraha blend)',
      'Procedure & mantra booklet',
      'Kalash + coconut set',
    ],
  ),
  const ProductModel(
    id: 'prod_012',
    name: 'Navgraha Premium Kit with Idols',
    description:
        'Premium Navgraha puja package featuring hand-crafted brass idols of all '
        'nine planetary deities and the complete samagri for an extended ritual.',
    pricePaise: 149900,
    category: ProductCategory.navgrahaKit,
    rating: 4.8,
    reviewCount: 92,
    stock: 12,
    imageAsset: 'assets/images/image8.jpg',
    includes: [
      'Set of 9 Navgraha brass idols (2 inch)',
      'Silver-plated Navgraha yantra',
      'Complete individual puja sets × 9',
      'Nava dhanya (premium bulk)',
      'Nine coloured silk cloths',
      'Navgraha-specific havan samagri',
      'Pure cow ghee 500 ml',
      'Premium dhoop & camphor set',
      'Copper kalash × 9 (mini)',
      'Detailed Navgraha katha & procedure book',
    ],
  ),
];
