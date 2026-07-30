import 'package:gift360/features/brands/data/models/brand_name.dart';
import 'package:gift360/features/brands/data/repositories/brand_names_api.dart';

class BrandNamesRepository {
  final BrandNamesApi _api;

  BrandNamesRepository(this._api);

  Future<List<BrandName>> getBrandNames() async {
    return await _api.getBrandNames();
  }
}
