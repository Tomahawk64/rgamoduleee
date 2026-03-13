// lib/core/constants/app_images.dart
//
// Semantic asset-image constants so every screen references the
// same paths and swapping artwork only requires editing this file.
//

/// All local asset images shipped with the app.
///
/// 16 images total:
///   image1–image4   → hero banners / main carousel
///   image5–image8   → pooja / package visuals
///   image9–image11  → shop product kits
///   image12–image14 → pandit profile photos
///   image15         → brand / splash logo (PNG)
///   image16         → consultation / spiritual guidance
abstract final class AppImages {
  static const String _base = 'assets/images';

  // ── Hero Banners (carousel on home screen) ─────────────────────────────
  static const String heroBanner1     = '$_base/image1.jpg';
  static const String heroBanner2     = '$_base/image2.jpg';
  static const String heroBanner3     = '$_base/image3.jpg';
  static const String heroBanner4     = '$_base/image4.jpg';

  // ── Pooja / Package visuals ────────────────────────────────────────────
  static const String poojaSatyanarayan = '$_base/image5.jpg';
  static const String poojaNavgraha     = '$_base/image6.jpg';
  static const String poojaGanpati      = '$_base/image7.jpg';
  static const String poojaLakshmi      = '$_base/image8.jpg';

  // ── Shop product kit photos ────────────────────────────────────────────
  static const String shopKit1 = '$_base/image9.jpg';
  static const String shopKit2 = '$_base/image10.jpg';
  static const String shopKit3 = '$_base/image11.jpg';

  // ── Pandit profile photos ──────────────────────────────────────────────
  static const String pandit1 = '$_base/image12.jpg';
  static const String pandit2 = '$_base/image13.jpg';
  static const String pandit3 = '$_base/image14.jpg';

  // ── Brand / logo (PNG) ─────────────────────────────────────────────────
  static const String brandLogo = '$_base/image15.png';

  // ── Consultation / spiritual guidance ──────────────────────────────────
  static const String consultation = '$_base/image16.jpg';

  // ── Convenience lists for cycling through ──────────────────────────────

  static const List<String> heroBanners = [
    heroBanner1, heroBanner2, heroBanner3, heroBanner4,
  ];

  static const List<String> poojaImages = [
    poojaSatyanarayan, poojaNavgraha, poojaGanpati, poojaLakshmi,
  ];

  static const List<String> shopImages = [shopKit1, shopKit2, shopKit3];

  static const List<String> panditImages = [pandit1, pandit2, pandit3];

  static const List<String> allImages = [
    heroBanner1, heroBanner2, heroBanner3, heroBanner4,
    poojaSatyanarayan, poojaNavgraha, poojaGanpati, poojaLakshmi,
    shopKit1, shopKit2, shopKit3,
    pandit1, pandit2, pandit3,
    brandLogo,
    consultation,
  ];
}
