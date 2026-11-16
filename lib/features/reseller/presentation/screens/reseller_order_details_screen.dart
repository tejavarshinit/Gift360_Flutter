import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gift360/features/reseller/data/reseller_csv.dart';
import 'package:gift360/features/reseller/data/reseller_store.dart';

String _orderMoney(num? value) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
).format(value ?? 0);

/// Reseller "Order details" page - port of the React `selectedOrder` view in
/// `pages/ResellerDashboard.tsx`: DetailHeader, order summary card with the
/// Excel export, then one card per line item with credential boxes.
class ResellerOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> details;
  final String? createdAt;
  final String avatarInitial;
  final VoidCallback? onHome;
  final VoidCallback? onProfile;

  const ResellerOrderDetailsScreen({
    super.key,
    required this.details,
    this.createdAt,
    this.avatarInitial = 'R',
    this.onHome,
    this.onProfile,
  });

  @override
  State<ResellerOrderDetailsScreen> createState() =>
      _ResellerOrderDetailsScreenState();
}

class _ResellerOrderDetailsScreenState
    extends State<ResellerOrderDetailsScreen> {
  bool _exporting = false;

  String get _orderNumber => (widget.details['orderNumber'] ?? '').toString();

  String get _clientOrderRef =>
      (widget.details['clientOrderRef'] ?? '').toString();

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// React `statusChip()` colors.
  (Color, Color) _statusColors(String status) {
    final s = status.toUpperCase();
    if (s == 'COMPLETED' || s == 'COMPLETE') {
      return (const Color(0xFFECFDF5), const Color(0xFF059669));
    }
    if (s == 'FAILED') return (const Color(0xFFFEF2F2), const Color(0xFFDC2626));
    if (s == 'PLACED' || s == 'PROCESSING') {
      return (const Color(0xFFFFFBEB), const Color(0xFFD97706));
    }
    return (const Color(0xFFF3F4F6), const Color(0xFF4B5563));
  }

  Widget _statusChip(String status, {required bool compact}) {
    final (background, foreground) = _statusColors(status);
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  /// React `Row` - label left, semibold value right.
  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF4B5563)),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// React `CopyRow` - hides itself when the value is empty.
  Widget _copyRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _copy(value, label),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// React `CredentialRows` - Card no. / PIN / Code / Expiry / activation link.
  Widget _credentialRows(Map<String, dynamic> cred) {
    final card = (cred['cardNumber'] ?? '').toString();
    final pin = (cred['cardPin'] ?? '').toString();
    final code = (cred['activationCode'] ?? '').toString();
    final url = (cred['activationUrl'] ?? '').toString();
    final expiry = (cred['expiry'] ?? '').toString();
    final expiryText = expiry.length >= 10 ? expiry.substring(0, 10) : expiry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _copyRow('Card no.', card),
        const SizedBox(height: 6),
        _copyRow('PIN', pin),
        const SizedBox(height: 6),
        _copyRow('Code', code),
        if (expiryText.isNotEmpty) ...[
          const SizedBox(height: 6),
          _row('Expiry', expiryText),
        ],
        if (url.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                'Open activation link',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6D28D9),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _exportOrder() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final csv = resellerOrderToCsv(
        widget.details,
        createdAt: widget.createdAt,
      );
      final tag =
          _clientOrderRef.isNotEmpty ? _clientOrderRef : _orderNumber;
      final safeTag = tag.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
      final fileName = 'order-$safeTag.csv';
      final path = await shareCsvFile(csv, fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path == null
                ? 'CSV copied to clipboard'
                : 'Excel downloaded — $fileName',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't create the Excel file. Please try again."),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _orderSummaryCard() {
    final details = widget.details;
    final total = (details['totalAmount'] as num?)?.toDouble() ?? 0;
    final discount = (details['discountAmount'] as num?)?.toDouble() ?? 0;
    final status = (details['status'] ?? '').toString();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _clientOrderRef.isNotEmpty ? _clientOrderRef : _orderNumber,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _orderNumber,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(status, compact: false),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          _row('Total charged', _orderMoney(total)),
          const SizedBox(height: 6),
          _row('Discount', discount > 0 ? '−${_orderMoney(discount)}' : '—'),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _exporting ? null : _exportOrder,
              icon: const Icon(Icons.grid_on, size: 16),
              label: Text(
                _exporting ? 'Exporting...' : 'Download order (Excel)',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6D28D9),
                side: const BorderSide(color: Color(0xFFC4B5FD)),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final credentials = (item['credentials'] as List?) ?? const [];
    final brandName = (item['brandName'] ?? '').toString();
    final brandSku = (item['brandSku'] ?? '').toString();
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
    final netAmount = (item['netAmount'] as num?)?.toDouble() ?? 0;
    final discountPercent = item['discountPercent'];
    final discountAmount = (item['discountAmount'] as num?)?.toDouble() ?? 0;
    final status = (item['fulfillmentStatus'] ?? '').toString();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brandName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$brandSku · $quantity × ${_orderMoney(unitPrice)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(status, compact: true),
            ],
          ),
          const SizedBox(height: 8),
          _row('Net amount', _orderMoney(netAmount)),
          const SizedBox(height: 4),
          if (discountPercent != null &&
              (discountPercent as num).toDouble() > 0)
            _row(
              'Discount',
              '$discountPercent% (−${_orderMoney(discountAmount)})',
            ),
          ...credentials.whereType<Map>().map((cred) {
            return Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDE9FE)),
              ),
              child: _credentialRows(cred.cast<String, dynamic>()),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = (widget.details['items'] as List?) ?? const [];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // DetailHeader
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 512),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  size: 20,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Order details',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (widget.onHome != null)
                              InkWell(
                                onTap: widget.onHome,
                                customBorder: const CircleBorder(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF5F3FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.home_rounded,
                                    size: 16,
                                    color: Color(0xFF6D28D9),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: widget.onProfile,
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFA855F7),
                                      Color(0xFF3B82F6),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  widget.avatarInitial,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 512),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: [
                    _orderSummaryCard(),
                    ...items.whereType<Map>().map(
                          (item) => _itemCard(item.cast<String, dynamic>()),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
