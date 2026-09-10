const List<String> superCoinExcludedBrands = [
  "PCJ Gold Jewellery E-Gift Card",
  "Estele",
  "Bhima Jewellers - Coin E-Gift Card",
  "Amazon Prime Lite Edition-Giftbig",
  "Joyalukkas Diamond E-Gift Card",
  "Jos Alukkas Jewellery E-Gift Card",
  "Joyalukkas Gold and Diamond E-Gift Card",
  "Candere Gold Jewellery",
  "Reliance Jewels",
  "PC Chandra Gems Gold Coin E-Gift Card",
  "Tanishq",
  "Candere Diamond Jewellery",
  "PCJ Diamond Jewellery E-Gift Card",
  "BlueStone Gold Jewellery",
  "Giva Jewellery Gold E-Gift Card",
  "Bluestone Gemstone Studded E-Gift Card",
  "Kalyan Gold Coin E-Gift Card",
  "Euphoria Gold Coin E-Gift Card",
  "Joyalukkas Pure Gold E-Gift Card",
  "Giva Jewellery E-Gift Card",
  "PMJ Jewellers",
  "Bhima Jewellers - Jewellery E-Gift Card",
  "Marriott",
  "MakeMyTrip",
  "DPauls",
  "Taj Hotels",
  "Cleartrip",
  "Assembly",
  "IRCTC",
  "EaseMyTrip",
  "Samsonite",
  "tripXOXO",
  "American Tourister",
  "Amazon",
];

const List<String> superCoinExcludedBrandNameAliases = [
  "amazonprime",
  "amazonprimelite",
  "amazonprimeliteedition",
  "amazonprimeliteeditiongiftbig",
  "prime",
  "primevideo",
  "marriottbonvoy",
  "marriot",
  "make my trip",
  "makemytrip",
  "mmt",
  "american tourister",
  "americantourister",
  "american touristor",
  "americantouristor",
];

const List<String> superCoinExcludedBrandIds = [
  "2",    // Marriott
  "5",    // MakeMyTrip
  "24",   // DPauls
  "45",   // Taj Hotels
  "49",   // Cleartrip
  "54",   // Assembly
  "123",  // IRCTC
  "189",  // Marriott
  "191",  // EaseMyTrip
  "279",  // Samsonite
  "292",  // tripXOXO
  "296",  // American Tourister",
];

bool isSuperCoinExcluded(String brandName) {
  final normalized = brandName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  final raw = brandName.toLowerCase();

  final excludedByName = superCoinExcludedBrands.any((excluded) {
    final normalizedExcluded = excluded.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return normalized.contains(normalizedExcluded) || raw.contains(excluded.toLowerCase());
  });

  final excludedByAlias = superCoinExcludedBrandNameAliases.any((alias) =>
      normalized.contains(alias.replaceAll(RegExp(r'[^a-z0-9]+'), '')));

  return excludedByName || excludedByAlias;
}

bool isSuperCoinExcludedById(String brandId) {
  return superCoinExcludedBrandIds.contains(brandId);
}

bool isSuperCoinEligible({String? brandId, String? brandName}) {
  if (brandId != null && brandId.trim().isNotEmpty && isSuperCoinExcludedById(brandId.trim())) {
    return false;
  }
  if (brandName != null && brandName.trim().isNotEmpty && isSuperCoinExcluded(brandName.trim())) {
    return false;
  }
  return true;
}
