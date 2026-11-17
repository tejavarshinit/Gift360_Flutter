$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$blocRoot = Join-Path $root 'lib\bloc'
$presentationRoot = Join-Path $root 'lib\presentation'

function Write-Utf8($path, $content) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $content.Replace("`r`n", "`n"), $utf8)
}

$pages = @(
  @{ Folder = 'homepage'; Name = 'Homepage'; Max = '1120'; Import = 'package:gift360/features/home/presentation/screens/home_screen.dart'; Child = 'const HomeScreen()'; Params = '' },
  @{ Folder = 'categories'; Name = 'Categories'; Max = '1120'; Import = 'package:gift360/features/categories/presentation/screens/categories_screen.dart'; Child = 'const CategoriesScreen()'; Params = '' },
  @{ Folder = 'brands'; Name = 'Brands'; Max = '1120'; Import = 'package:gift360/features/brands/presentation/screens/brands_screen.dart'; Params = 'custom' },
  @{ Folder = 'brand_details'; Name = 'BrandDetails'; Max = '960'; Import = 'package:gift360/features/brands/presentation/screens/brand_details_screen.dart'; Params = 'custom' },
  @{ Folder = 'cart'; Name = 'Cart'; Max = '960'; Import = 'package:gift360/features/cart/presentation/screens/cart_screen.dart'; Child = 'const CartScreen()'; Params = '' },
  @{ Folder = 'orders'; Name = 'Orders'; Max = '1120'; Import = 'package:gift360/features/orders/presentation/screens/orders_screen.dart'; Child = 'const OrdersScreen()'; Params = '' },
  @{ Folder = 'my_orders'; Name = 'MyOrders'; Max = '1120'; Import = 'package:gift360/features/orders/presentation/screens/my_orders_screen.dart'; Child = 'const MyOrdersScreen()'; Params = '' },
  @{ Folder = 'order_checkout'; Name = 'OrderCheckout'; Max = '960'; Import = 'package:gift360/features/order/presentation/screens/order_checkout_screen.dart'; Params = 'custom' },
  @{ Folder = 'notifications'; Name = 'Notifications'; Max = '840'; Import = 'package:gift360/features/notifications/presentation/screens/notifications_screen.dart'; Child = 'const NotificationsScreen()'; Params = '' },
  @{ Folder = 'profile'; Name = 'Profile'; Max = '840'; Import = 'package:gift360/features/profile/presentation/screens/profile_screen.dart'; Child = 'const ProfileScreen()'; Params = '' },
  @{ Folder = 'login'; Name = 'Login'; Max = '560'; Import = 'package:gift360/features/auth/presentation/screens/login_screen.dart'; Params = 'custom' },
  @{ Folder = 'register'; Name = 'Register'; Max = '560'; Import = 'package:gift360/features/auth/presentation/screens/register_screen.dart'; Child = 'const RegisterScreen()'; Params = '' },
  @{ Folder = 'forgot_password'; Name = 'ForgotPassword'; Max = '560'; Import = 'package:gift360/features/auth/presentation/screens/forgot_password_screen.dart'; Child = 'const ForgotPasswordScreen()'; Params = '' },
  @{ Folder = 'reset_password'; Name = 'ResetPassword'; Max = '560'; Import = 'package:gift360/features/auth/presentation/screens/reset_password_screen.dart'; Params = 'custom' },
  @{ Folder = 'onboarding'; Name = 'Onboarding'; Max = ''; Import = 'package:gift360/features/onboarding/presentation/screens/onboarding_screen.dart'; Child = 'const OnboardingPage()'; Params = '' },
  @{ Folder = 'splash'; Name = 'Splash'; Max = ''; Import = ''; Params = 'bloc-only' },
  @{ Folder = 'welcome'; Name = 'Welcome'; Max = ''; Import = ''; Params = 'bloc-only' },
  @{ Folder = 'onboarding1'; Name = 'Onboarding1'; Max = ''; Import = ''; Params = 'bloc-only' },
  @{ Folder = 'onboarding2'; Name = 'Onboarding2'; Max = ''; Import = ''; Params = 'bloc-only' },
  @{ Folder = 'onboarding3'; Name = 'Onboarding3'; Max = ''; Import = ''; Params = 'bloc-only' },
  @{ Folder = 'distributor'; Name = 'Distributor'; Max = '840'; Import = 'package:gift360/features/landing/presentation/screens/distributor_screen.dart'; Child = 'const DistributorScreen()'; Params = '' },
  @{ Folder = 'corporate'; Name = 'Corporate'; Max = '840'; Import = 'package:gift360/features/landing/presentation/screens/corporate_screen.dart'; Child = 'const CorporateScreen()'; Params = '' },
  @{ Folder = 'reseller'; Name = 'Reseller'; Max = '840'; Import = 'package:gift360/features/landing/presentation/screens/reseller_screen.dart'; Child = 'const ResellerScreen()'; Params = '' },
  @{ Folder = 'reseller_login'; Name = 'ResellerLogin'; Max = '560'; Import = 'package:gift360/features/reseller/presentation/screens/reseller_login_screen.dart'; Child = 'const ResellerLoginScreen()'; Params = '' },
  @{ Folder = 'reseller_dashboard'; Name = 'ResellerDashboard'; Max = '1120'; Import = 'package:gift360/features/reseller/presentation/screens/reseller_dashboard_screen.dart'; Child = 'const ResellerDashboardScreen()'; Params = '' },
  @{ Folder = 'reseller_catalog'; Name = 'ResellerCatalog'; Max = '1120'; Import = 'package:gift360/features/reseller/presentation/screens/reseller_catalog_screen.dart'; Child = 'const ResellerCatalogScreen()'; Params = '' },
  @{ Folder = 'reseller_cart'; Name = 'ResellerCart'; Max = '960'; Import = 'package:gift360/features/reseller/presentation/screens/reseller_cart_screen.dart'; Child = 'const ResellerCartScreen()'; Params = '' },
  @{ Folder = 'reseller_reset_password'; Name = 'ResellerResetPassword'; Max = '560'; Import = 'package:gift360/features/reseller/presentation/screens/reseller_reset_password_screen.dart'; Params = 'custom' },
  @{ Folder = 'reseller_order_details'; Name = 'ResellerOrderDetails'; Max = '960'; Import = 'package:gift360/features/reseller/presentation/screens/reseller_order_details_screen.dart'; Params = 'custom' },
  @{ Folder = 'privacy'; Name = 'Privacy'; Max = '840'; Import = 'package:gift360/features/legal/presentation/screens/privacy_screen.dart'; Child = 'const PrivacyScreen()'; Params = '' },
  @{ Folder = 'terms'; Name = 'Terms'; Max = '840'; Import = 'package:gift360/features/legal/presentation/screens/terms_screen.dart'; Child = 'const TermsScreen()'; Params = '' },
  @{ Folder = 'refund'; Name = 'Refund'; Max = '840'; Import = 'package:gift360/features/legal/presentation/screens/refund_screen.dart'; Child = 'const RefundScreen()'; Params = '' },
  @{ Folder = 'delete_account'; Name = 'DeleteAccount'; Max = '720'; Import = 'package:gift360/features/legal/presentation/screens/delete_account_screen.dart'; Child = 'const DeleteAccountScreen()'; Params = '' },
  @{ Folder = 'offers'; Name = 'Offers'; Max = '1120'; Import = 'package:gift360/features/offers/presentation/screens/offers_screen.dart'; Child = 'const OffersScreen()'; Params = '' },
  @{ Folder = 'login_issues'; Name = 'LoginIssues'; Max = '840'; Import = 'package:gift360/features/legal/presentation/screens/login_issues_screen.dart'; Child = 'const LoginIssuesScreen()'; Params = '' },
  @{ Folder = 'faq'; Name = 'Faq'; Max = '840'; Import = 'package:gift360/features/faq/presentation/screens/faq_screen.dart'; Child = 'const FaqScreen()'; Params = '' },
  @{ Folder = 'faq_topic'; Name = 'FaqTopic'; Max = '840'; Import = 'package:gift360/features/faq/presentation/screens/faq_topic_screen.dart'; Params = 'custom' },
  @{ Folder = 'blogs'; Name = 'Blogs'; Max = '960'; Import = 'package:gift360/features/blogs/presentation/screens/blog_screen.dart'; Child = 'const BlogScreen()'; Params = '' },
  @{ Folder = 'blog_page'; Name = 'BlogPage'; Max = '960'; Import = 'package:gift360/features/blog/presentation/screens/blog_page.dart'; Child = 'const BlogPage()'; Params = '' },
  @{ Folder = 'blog_detail'; Name = 'BlogDetail'; Max = '840'; Import = 'package:gift360/features/blog/presentation/screens/single_blog_page.dart'; Params = 'custom' },
  @{ Folder = 'spin_wheel'; Name = 'SpinWheel'; Max = ''; Import = 'package:gift360/features/spin_wheel/presentation/screens/spin_wheel_screen.dart'; Child = 'const SpinWheelScreen()'; Params = '' },
  @{ Folder = 'rewards'; Name = 'Rewards'; Max = '960'; Import = 'package:gift360/features/rewards/presentation/screens/rewards_screen.dart'; Child = 'const RewardsScreen()'; Params = '' },
  @{ Folder = 'supercoin_voucher'; Name = 'SupercoinVoucher'; Max = '840'; Import = 'package:gift360/features/supercoin/presentation/screens/supercoin_voucher_screen.dart'; Child = 'const SuperCoinVoucherScreen()'; Params = '' },
  @{ Folder = 'bulk_purchase'; Name = 'BulkPurchase'; Max = '960'; Import = 'package:gift360/features/bulk_purchase/presentation/screens/bulk_purchase_screen.dart'; Child = 'const BulkPurchaseScreen()'; Params = '' },
  @{ Folder = 'nearby'; Name = 'Nearby'; Max = ''; Import = 'package:gift360/features/nearby/presentation/screens/nearby_screen.dart'; Child = 'const NearbyScreen()'; Params = '' },
  @{ Folder = 'payment'; Name = 'Payment'; Max = '720'; Import = 'package:gift360/features/payment/presentation/screens/payment_screen.dart'; Child = 'const PaymentScreen()'; Params = '' },
  @{ Folder = 'payment_webview'; Name = 'PaymentWebview'; Max = ''; Import = 'package:gift360/features/payment/presentation/screens/payment_webview_screen.dart'; Params = 'custom' },
  @{ Folder = 'payment_result'; Name = 'PaymentResult'; Max = '720'; Import = 'package:gift360/features/payment/presentation/screens/payment_result_screen.dart'; Params = 'custom' }
)

$exports = New-Object System.Collections.Generic.List[string]

foreach ($page in $pages) {
  $folder = $page.Folder
  $name = $page.Name
  $event = @"
import 'package:equatable/equatable.dart';

sealed class ${name}Event extends Equatable {
  const ${name}Event();

  @override
  List<Object?> get props => const [];
}

class ${name}Started extends ${name}Event {
  const ${name}Started();
}

class ${name}Refreshed extends ${name}Event {
  const ${name}Refreshed();
}
"@
  $state = @"
import 'package:equatable/equatable.dart';

enum ${name}Status { initial, loading, ready, failure }

class ${name}State extends Equatable {
  const ${name}State({
    this.status = ${name}Status.initial,
    this.message = '',
  });

  final ${name}Status status;
  final String message;

  ${name}State copyWith({${name}Status? status, String? message}) {
    return ${name}State(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}
"@
  $bloc = @"
import 'package:flutter_bloc/flutter_bloc.dart';

import '${folder}_event.dart';
import '${folder}_state.dart';

class ${name}Bloc extends Bloc<${name}Event, ${name}State> {
  ${name}Bloc() : super(const ${name}State()) {
    on<${name}Started>(_onStarted);
    on<${name}Refreshed>(_onRefreshed);
  }

  void _onStarted(${name}Started event, Emitter<${name}State> emit) {
    emit(state.copyWith(status: ${name}Status.ready, message: ''));
  }

  void _onRefreshed(${name}Refreshed event, Emitter<${name}State> emit) {
    emit(state.copyWith(status: ${name}Status.ready, message: ''));
  }
}
"@
  Write-Utf8 (Join-Path $blocRoot "$folder\${folder}_event.dart") $event
  Write-Utf8 (Join-Path $blocRoot "$folder\${folder}_state.dart") $state
  Write-Utf8 (Join-Path $blocRoot "$folder\${folder}_bloc.dart") $bloc

  if ($page.Params -eq 'bloc-only' -or $page.Params -eq 'custom') { continue }

  $maxArg = if ([string]::IsNullOrEmpty($page.Max)) { '' } else { "maxContentWidth: $($page.Max)," }
  $view = @"
import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/$folder/${folder}_bloc.dart';
import 'package:gift360/bloc/$folder/${folder}_event.dart';
import 'package:gift360/bloc/$folder/${folder}_state.dart';
import '$($page.Import)';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ${name}View extends StatelessWidget {
  const ${name}View({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<${name}Bloc, ${name}Event, ${name}State>(
      create: ${name}Bloc.new,
      started: const ${name}Started(),
      $maxArg
      child: $($page.Child),
    );
  }
}
"@
  Write-Utf8 (Join-Path $presentationRoot "$folder\${folder}_view.dart") $view
  $exports.Add("export '$folder/${folder}_view.dart';")
}

$custom = @{
  brands = @"
import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/brands/brands_bloc.dart';
import 'package:gift360/bloc/brands/brands_event.dart';
import 'package:gift360/bloc/brands/brands_state.dart';
import 'package:gift360/features/brands/presentation/screens/brands_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class BrandsView extends StatelessWidget {
  const BrandsView({
    super.key,
    this.initialSearch,
    this.initialCategory,
    this.initialSuperCoinsOnly = false,
    this.initialDiscountRanges = const [],
  });

  final String? initialSearch;
  final String? initialCategory;
  final bool initialSuperCoinsOnly;
  final List<String> initialDiscountRanges;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<BrandsBloc, BrandsEvent, BrandsState>(
      create: BrandsBloc.new,
      started: const BrandsStarted(),
      maxContentWidth: 1120,
      child: BrandsScreen(
        initialSearch: initialSearch,
        initialCategory: initialCategory,
        initialSuperCoinsOnly: initialSuperCoinsOnly,
        initialDiscountRanges: initialDiscountRanges,
      ),
    );
  }
}
"@
  brand_details = @"
import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/brand_details/brand_details_bloc.dart';
import 'package:gift360/bloc/brand_details/brand_details_event.dart';
import 'package:gift360/bloc/brand_details/brand_details_state.dart';
import 'package:gift360/features/brands/presentation/screens/brand_details_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class BrandDetailsView extends StatelessWidget {
  const BrandDetailsView({super.key, required this.brandId});

  final String brandId;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<BrandDetailsBloc, BrandDetailsEvent, BrandDetailsState>(
      create: BrandDetailsBloc.new,
      started: const BrandDetailsStarted(),
      maxContentWidth: 960,
      child: BrandDetailsScreen(brandId: brandId),
    );
  }
}
"@
  order_checkout = @"
import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/order_checkout/order_checkout_bloc.dart';
import 'package:gift360/bloc/order_checkout/order_checkout_event.dart';
import 'package:gift360/bloc/order_checkout/order_checkout_state.dart';
import 'package:gift360/features/order/presentation/screens/order_checkout_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class OrderCheckoutView extends StatelessWidget {
  const OrderCheckoutView({super.key, required this.orderNumber});

  final String orderNumber;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<OrderCheckoutBloc, OrderCheckoutEvent, OrderCheckoutState>(
      create: OrderCheckoutBloc.new,
      started: const OrderCheckoutStarted(),
      maxContentWidth: 960,
      child: OrderCheckoutScreen(orderNumber: orderNumber),
    );
  }
}
"@
  login = @"
import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/login/login_bloc.dart';
import 'package:gift360/bloc/login/login_event.dart';
import 'package:gift360/bloc/login/login_state.dart';
import 'package:gift360/features/auth/presentation/screens/login_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key, this.isSessionExpired = false});

  final bool isSessionExpired;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<LoginBloc, LoginEvent, LoginState>(
      create: LoginBloc.new,
      started: const LoginStarted(),
      maxContentWidth: 560,
      child: LoginScreen(isSessionExpired: isSessionExpired),
    );
  }
}
"@
  reset_password = @"
import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/reset_password/reset_password_bloc.dart';
import 'package:gift360/bloc/reset_password/reset_password_event.dart';
import 'package:gift360/bloc/reset_password/reset_password_state.dart';
import 'package:gift360/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ResetPasswordView extends StatelessWidget {
  const ResetPasswordView({super.key, this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<ResetPasswordBloc, ResetPasswordEvent, ResetPasswordState>(
      create: ResetPasswordBloc.new,
      started: const ResetPasswordStarted(),
      maxContentWidth: 560,
      child: ResetPasswordScreen(token: token),
    );
  }
}
"@
  reseller_reset_password = @"
import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/reseller_reset_password/reseller_reset_password_bloc.dart';
import 'package:gift360/bloc/reseller_reset_password/reseller_reset_password_event.dart';
import 'package:gift360/bloc/reseller_reset_password/reseller_reset_password_state.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_reset_password_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ResellerResetPasswordView extends StatelessWidget {
  const ResellerResetPasswordView({super.key, this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<
      ResellerResetPasswordBloc,
      ResellerResetPasswordEvent,
      ResellerResetPasswordState
    >(
      create: ResellerResetPasswordBloc.new,
      started: const ResellerResetPasswordStarted(),
      maxContentWidth: 560,
      child: ResellerResetPasswordScreen(token: token),
    );
  }
}
"@
  reseller_order_details = @"
import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/reseller_order_details/reseller_order_details_bloc.dart';
import 'package:gift360/bloc/reseller_order_details/reseller_order_details_event.dart';
import 'package:gift360/bloc/reseller_order_details/reseller_order_details_state.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_order_details_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ResellerOrderDetailsView extends StatelessWidget {
  const ResellerOrderDetailsView({
    super.key,
    required this.details,
    this.createdAt,
    this.avatarInitial = 'R',
    this.onHome,
    this.onProfile,
  });

  final Map<String, dynamic> details;
  final String? createdAt;
  final String avatarInitial;
  final VoidCallback? onHome;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<
      ResellerOrderDetailsBloc,
      ResellerOrderDetailsEvent,
      ResellerOrderDetailsState
    >(
      create: ResellerOrderDetailsBloc.new,
      started: const ResellerOrderDetailsStarted(),
      maxContentWidth: 960,
      child: ResellerOrderDetailsScreen(
        details: details,
        createdAt: createdAt,
        avatarInitial: avatarInitial,
        onHome: onHome,
        onProfile: onProfile,
      ),
    );
  }
}
"@
  faq_topic = @"
import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/faq_topic/faq_topic_bloc.dart';
import 'package:gift360/bloc/faq_topic/faq_topic_event.dart';
import 'package:gift360/bloc/faq_topic/faq_topic_state.dart';
import 'package:gift360/features/faq/presentation/screens/faq_topic_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class FaqTopicView extends StatelessWidget {
  const FaqTopicView({super.key, required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<FaqTopicBloc, FaqTopicEvent, FaqTopicState>(
      create: FaqTopicBloc.new,
      started: const FaqTopicStarted(),
      maxContentWidth: 840,
      child: FaqTopicScreen(topicId: topicId),
    );
  }
}
"@
  blog_detail = @"
import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/blog_detail/blog_detail_bloc.dart';
import 'package:gift360/bloc/blog_detail/blog_detail_event.dart';
import 'package:gift360/bloc/blog_detail/blog_detail_state.dart';
import 'package:gift360/features/blog/presentation/screens/single_blog_page.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class BlogDetailView extends StatelessWidget {
  const BlogDetailView({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<BlogDetailBloc, BlogDetailEvent, BlogDetailState>(
      create: BlogDetailBloc.new,
      started: const BlogDetailStarted(),
      maxContentWidth: 840,
      child: SingleBlogPage(id: id),
    );
  }
}
"@
  payment_webview = @"
import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/payment_webview/payment_webview_bloc.dart';
import 'package:gift360/bloc/payment_webview/payment_webview_event.dart';
import 'package:gift360/bloc/payment_webview/payment_webview_state.dart';
import 'package:gift360/features/payment/presentation/screens/payment_webview_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class PaymentWebviewView extends StatelessWidget {
  const PaymentWebviewView({
    super.key,
    required this.paymentUrl,
    this.orderNumber,
  });

  final String paymentUrl;
  final String? orderNumber;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<PaymentWebviewBloc, PaymentWebviewEvent, PaymentWebviewState>(
      create: PaymentWebviewBloc.new,
      started: const PaymentWebviewStarted(),
      child: PaymentWebViewScreen(
        paymentUrl: paymentUrl,
        orderNumber: orderNumber,
      ),
    );
  }
}
"@
  payment_result = @"
import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/payment_result/payment_result_bloc.dart';
import 'package:gift360/bloc/payment_result/payment_result_event.dart';
import 'package:gift360/bloc/payment_result/payment_result_state.dart';
import 'package:gift360/features/payment/presentation/screens/payment_result_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class PaymentResultView extends StatelessWidget {
  const PaymentResultView({
    super.key,
    this.status,
    this.txnId,
    this.error,
    this.orderNumber,
  });

  final String? status;
  final String? txnId;
  final String? error;
  final String? orderNumber;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<PaymentResultBloc, PaymentResultEvent, PaymentResultState>(
      create: PaymentResultBloc.new,
      started: const PaymentResultStarted(),
      maxContentWidth: 720,
      child: PaymentResultScreen(
        status: status,
        txnId: txnId,
        error: error,
        orderNumber: orderNumber,
      ),
    );
  }
}
"@
}

foreach ($key in $custom.Keys) {
  Write-Utf8 (Join-Path $presentationRoot "$key\${key}_view.dart") $custom[$key]
  $exports.Add("export '$key/${key}_view.dart';")
}

$exportFile = ($exports | Sort-Object) -join "`n"
Write-Utf8 (Join-Path $presentationRoot 'presentation.dart') "$exportFile`n"
Write-Output "Generated $($pages.Count) blocs and $($exports.Count) views"
