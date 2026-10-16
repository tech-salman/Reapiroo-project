class ServiceModel {
  final String id;
  final String nameKey;
  final String defaultName;
  final String iconName;
  final String category;
  final double basePrice;
  final double rating;

  const ServiceModel({
    required this.id,
    required this.nameKey,
    required this.defaultName,
    required this.iconName,
    required this.category,
    required this.basePrice,
    this.rating = 4.8,
  });
}
