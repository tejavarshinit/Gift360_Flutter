/// Mirrors React's `src/lib/hidden-catalog-brands.ts`.
///
/// The SuperCoin E-Gift Voucher SKU must never appear on public catalog
/// surfaces (Home, search suggestions, search results, categories,
/// recommendations, brand lists). It is only reachable through the dedicated
/// SuperCoin convert flow (`/supercoin-voucher`).
const List<String> hiddenCatalogBrandCodes = ['EGCGBFKSCR001'];
const List<String> hiddenCatalogBrandIds = [
  'c1ae829e-0e78-4dfe-8432-c4c1ac9360e1',
];
const List<String> hiddenCatalogBrandNames = ['SuperCoin E-Gift Voucher'];

String _normalizeName(String? value) =>
    (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

bool isHiddenCatalogBrand(String? brandId, String? brandName, [String? brandCode]) {
  final resolvedId = (brandId ?? '').trim().toLowerCase();
  if (resolvedId.isNotEmpty && hiddenCatalogBrandIds.contains(resolvedId)) {
    return true;
  }
  final resolvedCode = (brandCode ?? '').trim().toUpperCase();
  if (resolvedCode.isNotEmpty && hiddenCatalogBrandCodes.contains(resolvedCode)) {
    return true;
  }
  final resolvedName = _normalizeName(brandName);
  if (resolvedName.isNotEmpty) {
    for (final name in hiddenCatalogBrandNames) {
      if (_normalizeName(name) == resolvedName) return true;
    }
  }
  return false;
}
