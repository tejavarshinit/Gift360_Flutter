import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/nearby/data/models/nearby_brand.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/payment/presentation/widgets/payment_details_sheet.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/payment/data/models/payment.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/core/utils/encryption.dart';
import 'package:gift360/core/providers/notification_provider.dart';
import 'package:gift360/theme/app_colors.dart';
import 'package:gift360/theme/app_text_styles.dart';
import 'package:gift360/widgets/location_loading.dart';
import 'package:gift360/widgets/location_confirm_modal.dart';
import 'package:gift360/widgets/nearby_search_bar.dart';
import 'package:gift360/widgets/category_chips.dart';
import 'package:gift360/widgets/nearby_brand_card.dart';
import 'package:gift360/widgets/nearby_state_widgets.dart';
import 'package:gift360/widgets/map_card.dart';

enum _LocationStatus { idle, requesting, granted, denied, confirming }

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});
  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  String _query = '';
  String _selectedCategory = 'Entertainment';
  _LocationStatus _locationStatus = _LocationStatus.idle;
  Position? _position;
  String _detectedAddress = '';
  bool _showConfirmModal = false;
  bool _isGeocoding = false;

  List<NearbyBrand> _brands = [];
  bool _isLoadingBrands = false;
  bool _hasError = false;

  bool _showPaymentSheet = false;
  Brand? _paymentBrand;
  bool _paymentLoading = false;
  String? _paymentError;

  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(baseUrl: AppConfig.storeApiUrl));
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    setState(() => _locationStatus = _LocationStatus.requesting);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { setState(() => _locationStatus = _LocationStatus.denied); return; }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) { setState(() => _locationStatus = _LocationStatus.denied); return; }
    }
    if (permission == LocationPermission.deniedForever) { setState(() => _locationStatus = _LocationStatus.denied); return; }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() { _position = position; _isGeocoding = true; });

    try {
      final dio = Dio();
      final res = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': position.latitude,
          'lon': position.longitude,
          'zoom': '18',
          'addressdetails': '1',
        },
        options: Options(headers: {'User-Agent': 'Gift360App/1.0'}),
      );
      final data = res.data as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>? ?? {};
      final city = address['city'] ?? address['town'] ?? address['village'] ?? address['county'] ?? '';
      final state = address['state'] ?? '';
      final country = address['country'] ?? '';
      final parts = [city, state, country].where((p) => p != null && p.toString().isNotEmpty);
      _detectedAddress = parts.join(', ');
    } catch (e, stack) {
      print('🔥 Geocoding error: $e');
      print('🔥 Stack: $stack');
    }
    setState(() => _isGeocoding = false);

    if (_detectedAddress.isNotEmpty) {
      setState(() { _showConfirmModal = true; _locationStatus = _LocationStatus.confirming; });
    } else {
      setState(() => _locationStatus = _LocationStatus.granted);
      _fetchNearbyBrands();
    }
  }

  void _onConfirmLocation() {
    setState(() { _showConfirmModal = false; _locationStatus = _LocationStatus.granted; });
    _fetchNearbyBrands();
  }

  Future<void> _fetchNearbyBrands() async {
    if (_position == null) return;
    setState(() { _isLoadingBrands = true; _hasError = false; });

    try {
      final response = await _dio.post('/v1/stores/nearby/brands', data: {'lat': _position!.latitude, 'lng': _position!.longitude, 'category': _selectedCategory});
      final data = response.data as Map<String, dynamic>;
      final brandsList = (data['brands'] as List<dynamic>?)?.map((b) => NearbyBrand.fromJson(b)).toList() ?? [];
      setState(() { _brands = brandsList; _isLoadingBrands = false; });
    } catch (e) {
      setState(() { _hasError = true; _isLoadingBrands = false; });
    }
  }

  void _onCategorySelect(String category) {
    setState(() => _selectedCategory = category);
    if (_locationStatus == _LocationStatus.granted) _fetchNearbyBrands();
  }

  void _onBuy(String brandId) {
    if (brandId.isEmpty) return;
    setState(() { _showPaymentSheet = true; _paymentBrand = null; _paymentLoading = true; _paymentError = null; });
    _fetchPaymentDetails(brandId);
  }

  Future<void> _fetchPaymentDetails(String brandId) async {
    try {
      final api = ref.read(brandsApiProvider);
      final details = await api.getBrandById(brandId);
      if (!mounted) return;
      setState(() { _paymentBrand = details; _paymentError = null; _paymentLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _paymentError = e.toString(); _paymentLoading = false; });
    }
  }

  void _handleAddToCart(Brand brand, double amount, int quantity) {
    ref.read(cartProvider.notifier).addToCart(AddToCartRequest(brandId: brand.brandId ?? '', brandName: brand.brandName ?? '', quantity: quantity, unitValue: amount, image: brand.resolvedImageUrl));
    ref.read(notificationProvider.notifier).addNotification(title: 'Added to Cart', message: '${brand.brandName} voucher has been added successfully into cart', type: 'success');
    setState(() { _showPaymentSheet = false; _paymentLoading = false; _paymentBrand = null; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${quantity}x ${brand.brandName} voucher(s) of ₹${amount.toInt()} added to cart')));
  }

  Future<void> _handlePay(Brand brand, double amount, int quantity) async {
    final user = ref.read(authProvider);
    if (user == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to make a payment'))); return; }
    final totalAmount = amount * quantity;
    final brandId = brand.brandId ?? '';
    if (brandId.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brand ID not available'))); return; }

    final paymentNotifier = ref.read(paymentProvider.notifier);
    try {
      final orderNumber = await paymentNotifier.createOrder(clientId: user.clientId, items: [{'brandId': brandId, 'quantity': quantity, 'unitValue': amount, 'lineTotal': totalAmount, 'meta': '{}'}], totalAmount: totalAmount);
      if (!mounted) return;
      if (orderNumber == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(paymentProvider).error ?? 'Failed to create order'))); return; }

      final valid = await paymentNotifier.validateOrder(cartTotal: totalAmount, walletAmount: 0, walletUsed: false);
      if (!mounted) return;
      if (!valid) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(paymentProvider).error ?? 'Order validation failed'))); return; }

      final tokenOk = await paymentNotifier.generateToken();
      if (!mounted) return;
      if (!tokenOk) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(paymentProvider).error ?? 'Failed to generate payment token'))); return; }

      final encryptedOrderRef = encryptOrderRef(orderNumber, user.clientId);
      final initiated = await paymentNotifier.initiatePayment(amount: totalAmount, productInfo: AppConfig.paymentProductInfo, frontendUrl: AppConfig.sabbpeFrontendUrl, customer: CustomerInfo(firstname: AppConfig.paymentCustFirstName, email: AppConfig.paymentCustEmail, phone: AppConfig.paymentCustMobile), encryptedOrderRef: encryptedOrderRef, clientId: user.clientId);
      if (!mounted) return;
      if (!initiated) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(paymentProvider).error ?? 'Payment initiation failed'))); return; }

      final paymentUrl = ref.read(paymentProvider).initiateResponse?.paymentUrl;
      if (paymentUrl == null || paymentUrl.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment URL not received from gateway'))); return; }

      setState(() { _showPaymentSheet = false; _paymentBrand = null; });
      context.push('/payment-webview', extra: {'paymentUrl': paymentUrl, 'orderNumber': orderNumber});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment error: ${e.toString()}')));
    }
  }

  List<NearbyBrand> get _filteredBrands {
    if (_query.isEmpty) return _brands;
    final q = _query.toLowerCase();
    return _brands.where((b) => b.brandName.toLowerCase().contains(q) || b.category.toLowerCase().contains(q)).toList();
  }

  bool get _showLoading => _locationStatus == _LocationStatus.requesting || _isGeocoding || (_locationStatus == _LocationStatus.granted && _isLoadingBrands);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              NearbySearchBar(value: _query, onChanged: (v) => setState(() => _query = v)),
              const SizedBox(height: 12),
              CategoryChips(selected: _selectedCategory, onSelect: _onCategorySelect),
              if (_locationStatus == _LocationStatus.granted) ...[const SizedBox(height: 12), MapCard(lat: _position?.latitude, lng: _position?.longitude)],
              const SizedBox(height: 12),
              Expanded(child: _buildContent()),
            ],
          ),
          if (_showLoading && !_showConfirmModal)
            Container(
              color: AppColors.background,
              child: Center(child: LocationLoadingWidget(text: _isGeocoding ? 'Detecting your location...' : 'Getting your location...')),
            ),
          if (_showConfirmModal) LocationConfirmModal(address: _detectedAddress, onConfirm: _onConfirmLocation),
          if (_showPaymentSheet)
            PaymentDetailsSheet(
              brand: _paymentBrand,
              loading: _paymentLoading,
              error: _paymentError,
              onClose: () => setState(() { _showPaymentSheet = false; _paymentLoading = false; _paymentError = null; _paymentBrand = null; }),
              onAddToCart: _handleAddToCart,
              onPay: _handlePay,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
      color: AppColors.background,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20)]),
              child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textDarkAlt),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Offers Near You', style: AppTextStyles.pageTitle),
                if (_locationStatus == _LocationStatus.granted && _detectedAddress.isNotEmpty)
                  Text(_detectedAddress.split(',').first, style: AppTextStyles.headerSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_showLoading || _showConfirmModal) return const SizedBox.shrink();
    if (_locationStatus == _LocationStatus.denied) return LocationPrompt(onRequest: _requestLocation);
    if (_hasError) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 24, offset: Offset(0, 12))]),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.red400, size: 16),
            const SizedBox(width: 8),
            Text('Unable to load nearby stores. Please try again.', style: AppTextStyles.errorText),
          ],
        ),
      );
    }
    if (_filteredBrands.isEmpty) return EmptyState(category: _selectedCategory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('${_filteredBrands.length} $_selectedCategory store${_filteredBrands.length != 1 ? 's' : ''} near you', style: AppTextStyles.countText),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: _filteredBrands.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => NearbyBrandCard(brand: _filteredBrands[index], onBuy: () => _onBuy(_filteredBrands[index].brandId)),
          ),
        ),
      ],
    );
  }
}
