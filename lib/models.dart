class CatalogItem {
  final String itemId;
  final String itemName;
  final String category;
  final double pricePerKg;
  final double stockAvailableKg;
  final bool webVisibility;
  final String imageUrl;

  CatalogItem({
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.pricePerKg,
    required this.stockAvailableKg,
    required this.webVisibility,
    required this.imageUrl,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      pricePerKg: (json['pricePerKg'] as num?)?.toDouble() ?? 0.0,
      stockAvailableKg: (json['stockAvailableKg'] as num?)?.toDouble() ?? 0.0,
      webVisibility: json['webVisibility'] == true,
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }
}

class CartItem {
  final String title;
  final double weightKg;
  final double ratePerKg;
  final bool isJobWork;
  final String? assignedMachine;

  CartItem({
    required this.title,
    required this.weightKg,
    required this.ratePerKg,
    this.isJobWork = false,
    this.assignedMachine,
  });

  double get totalPrice => weightKg * ratePerKg;

  String get summary => isJobWork
      ? '$title ($weightKg kg @ ₹$ratePerKg/kg) [Mach: $assignedMachine]'
      : '$title ($weightKg kg @ ₹$ratePerKg/kg)';
}