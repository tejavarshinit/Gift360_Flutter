class BrandName {
  final String brandId;
  final String brandName;
  final String? category;

  const BrandName({
    required this.brandId,
    required this.brandName,
    this.category,
  });

  factory BrandName.fromJson(Map<String, dynamic> json) {
    return BrandName(
      brandId: json['BrandId'] as String? ?? json['brandId'] as String? ?? '',
      brandName: json['BrandName'] as String? ?? json['brandName'] as String? ?? '',
      category: json['Category'] as String? ?? json['category'] as String?,
    );
  }
}
