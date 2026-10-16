class OfferModel {
  final String id;
  final String title;
  final String description;
  final String code;
  final int discountPercent;
  final String validUntil;
  final String bannerType;

  const OfferModel({
    required this.id,
    required this.title,
    required this.description,
    required this.code,
    required this.discountPercent,
    required this.validUntil,
    this.bannerType = 'gold',
  });
}
