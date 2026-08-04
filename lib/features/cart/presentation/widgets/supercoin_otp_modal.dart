import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/supercoin/data/repositories/supercoin_api.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';

class SuperCoinOTPModal extends ConsumerStatefulWidget {
  final String merchantWalletId;
  final String orderNumber;
  final String displayName;
  final double preloadedBalance;
  final double maxRedeemable;
  final void Function(SuperCoinHoldContext context) onAuthorized;
  final VoidCallback onSwitchToCashback;
  final VoidCallback onClose;

  const SuperCoinOTPModal({
    super.key,
    required this.merchantWalletId,
    required this.orderNumber,
    required this.displayName,
    required this.preloadedBalance,
    required this.maxRedeemable,
    required this.onAuthorized,
    required this.onSwitchToCashback,
    required this.onClose,
  });

  @override
  ConsumerState<SuperCoinOTPModal> createState() => _SuperCoinOTPModalState();
}

class _SuperCoinOTPModalState extends ConsumerState<SuperCoinOTPModal> {
  SuperCoinOtpStep _step = SuperCoinOtpStep.loadingBalance;
  double _balance = 0;
  double _coinAmount = 0;
  String _otp = '';
  String _prefilledOtp = '';
  String _merchantTransactionId = '';
  String? _error;
  bool _isLoading = false;
  String? _transactionTime;
  int _countdownSeconds = 900;
  bool _countdownExpired = false;
  int? _holdExpiryMs;
  Timer? _countdownTimer;

  SuperCoinIdentity? get _identity => ref.read(supercoinProvider.notifier).identity;

  @override
  void initState() {
    super.initState();
    _balance = widget.preloadedBalance;
    _coinAmount = widget.maxRedeemable > 0
        ? (widget.preloadedBalance < widget.maxRedeemable ? widget.preloadedBalance : widget.maxRedeemable)
        : widget.preloadedBalance;
    _loadBalance();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatCountdown(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _loadBalance() async {
    if (_identity == null) {
      setState(() => _step = SuperCoinOtpStep.ready);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(supercoinApiProvider);
      final result = await api.fetchBalance(_identity!);
      double bal = 0;
      for (final key in ['balance', 'totalBalance', 'availableBalance', 'amount']) {
        final val = result[key];
        if (val is num) {
          bal = val.toDouble();
          break;
        }
      }
      final coinAmt = widget.maxRedeemable > 0
          ? (bal < widget.maxRedeemable ? bal : widget.maxRedeemable)
          : bal;
      setState(() {
        _step = SuperCoinOtpStep.ready;
        _balance = bal;
        _coinAmount = coinAmt;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Unable to load your SuperCoin balance. Please try again.';
      });
    }
  }

  Future<void> _applyCoins() async {
    if (_identity == null) {
      setState(() => _error = 'SuperCoin identity not available.');
      return;
    }
    if (widget.merchantWalletId.isEmpty) {
      setState(() => _error = 'SuperCoin merchant wallet is not configured.');
      return;
    }
    if (widget.orderNumber.trim().isEmpty) {
      setState(() => _error = 'Order is not ready yet. Please try again.');
      return;
    }

    final txnId = '${widget.orderNumber}-SC';
    setState(() {
      _isLoading = true;
      _error = null;
      _merchantTransactionId = txnId;
    });
    try {
      final api = ref.read(supercoinApiProvider);
      final response = await api.initHold({
        'identity': _identity!.toJson(),
        'merchantWalletId': widget.merchantWalletId,
        'merchantTransactionId': txnId,
        'merchantReferenceId': widget.orderNumber,
        'amount': _coinAmount,
        'displayName': widget.displayName,
        'stampExpiry': DateTime.now().millisecondsSinceEpoch + 15 * 60 * 1000,
      });

      String? otp;
      if (response['otp'] != null) otp = response['otp'].toString();
      final txTime = response['transactionTime'] as String?;
      int holdExpiry = DateTime.now().millisecondsSinceEpoch + 15 * 60 * 1000;
      if (response['stampExpiry'] is num) {
        holdExpiry = (response['stampExpiry'] as num).toInt();
      }

      setState(() {
        _step = SuperCoinOtpStep.otpSent;
        _isLoading = false;
        _prefilledOtp = otp ?? '';
        _otp = otp ?? '';
        _transactionTime = txTime;
        _holdExpiryMs = holdExpiry;
      });

      _startCountdown(txTime, holdExpiry);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().contains('Exception')
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Failed to initiate SuperCoin hold. Please try again.';
      });
    }
  }

  void _startCountdown(String? txTime, int holdExpiryMs) {
    _countdownTimer?.cancel();
    int remaining = 900;

    if (txTime != null) {
      try {
        final startMs = DateTime.parse(txTime).millisecondsSinceEpoch;
        final endMs = startMs + 15 * 60 * 1000;
        remaining = ((endMs - DateTime.now().millisecondsSinceEpoch) / 1000).round().clamp(0, 900);
      } catch (_) {
        remaining = ((holdExpiryMs - DateTime.now().millisecondsSinceEpoch) / 1000).round().clamp(0, 900);
      }
    }

    setState(() {
      _countdownSeconds = remaining;
      _countdownExpired = remaining <= 0;
    });

    if (remaining <= 0) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = _countdownSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        setState(() {
          _countdownSeconds = 0;
          _countdownExpired = true;
        });
        widget.onClose();
      } else {
        setState(() => _countdownSeconds = next);
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_otp.trim().length < 6) {
      setState(() => _error = 'Please enter a valid 6-digit OTP.');
      return;
    }
    if (_merchantTransactionId.isEmpty || widget.merchantWalletId.isEmpty) {
      setState(() => _error = 'Missing transaction context. Please start over.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(supercoinApiProvider);
      final response = await api.authorizeHold({
        'identity': _identity!.toJson(),
        'merchantWalletId': widget.merchantWalletId,
        'merchantTransactionId': _merchantTransactionId,
        'otp': _otp.trim(),
      });

      final txnState = response['transactionState']?.toString().toUpperCase();
      if (txnState == 'SUCCESSFUL' || txnState == 'SUCCESS') {
        _countdownTimer?.cancel();
        setState(() {
          _step = SuperCoinOtpStep.authorized;
          _isLoading = false;
        });
        widget.onAuthorized(SuperCoinHoldContext(
          merchantTransactionId: _merchantTransactionId,
          merchantWalletId: widget.merchantWalletId,
          amount: _coinAmount,
          stampExpiry: _holdExpiryMs,
          transactionTime: _transactionTime,
        ));
      } else {
        setState(() {
          _isLoading = false;
          _error = response['message']?.toString() ?? 'OTP verification failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().contains('Exception')
            ? e.toString().replaceFirst('Exception: ', '')
            : 'OTP verification failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop overlay (matches Radix DialogOverlay — dims background,
        // does not close on outside tap since OTP flow disables that too).
        Positioned.fill(
          child: GestureDetector(
            onTap: () {},
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),
        // Centered content card (matches Radix DialogContent).
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Loading Balance
        if (_step == SuperCoinOtpStep.loadingBalance) ...[
          Row(
            children: [
              Image.asset(
                'assets/images/SuperCOin-removebg-preview.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 6),
              const Text('SuperCoins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Loading your SuperCoin balance...', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF6D5AE6)),
          ),
        ],

        // Ready
        if (_step == SuperCoinOtpStep.ready) ...[
          Row(
            children: [
              Image.asset(
                'assets/images/SuperCOin-removebg-preview.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 6),
              const Text('Use SuperCoins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/SuperCOin-removebg-preview.png',
                      width: 16,
                      height: 16,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Balance: ${_balance.toStringAsFixed(2)} coins',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Image.asset(
                      'assets/images/SuperCOin-removebg-preview.png',
                      width: 14,
                      height: 14,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You can use ${_coinAmount.toStringAsFixed(2)} coins on this order',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF2D2D2D)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.savings_outlined, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      'Save ${_coinAmount.toStringAsFixed(2)} coins',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isLoading || _coinAmount <= 0 ? null : _applyCoins,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Apply Coins', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],

        // OTP Sent
        if (_step == SuperCoinOtpStep.otpSent) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Verify OTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Text('Enter the OTP sent to your mobile number to use your SuperCoins.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 16),
          if (!_countdownExpired && _countdownSeconds > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF9747FF)),
                  const SizedBox(width: 6),
                  Text(
                    'Use your SuperCoins within ${_formatCountdown(_countdownSeconds)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF9747FF)),
                  ),
                ],
              ),
            ),
          if (_countdownExpired)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Time expired. Please try again.', style: TextStyle(color: Colors.red, fontSize: 13)),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: 240,
            child: TextField(
              maxLength: 6,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 8),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => setState(() => _otp = value),
              decoration: InputDecoration(
                counterText: '',
                hintText: '------',
                hintStyle: TextStyle(color: Colors.grey[300], letterSpacing: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF9747FF), width: 2),
                ),
              ),
            ),
          ),
          if (_prefilledOtp.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('OTP pre-filled for testing: $_prefilledOtp', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _countdownTimer?.cancel();
                            widget.onClose();
                          },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFD7BDFF),
                      foregroundColor: const Color(0xFF2D2D2D),
                      side: const BorderSide(color: Color(0xFFD7BDFF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isLoading || _otp.length < 6 ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9747FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Verify', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],

        // Authorized
        if (_step == SuperCoinOtpStep.authorized) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('SuperCoins Applied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 32, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/SuperCOin-removebg-preview.png',
                width: 16,
                height: 16,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
              Text('${_coinAmount.toStringAsFixed(2)} coins applied', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/SuperCOin-removebg-preview.png',
                width: 14,
                height: 14,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
              Text('You saved ${_coinAmount.toStringAsFixed(2)} coins', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                _countdownTimer?.cancel();
                widget.onClose();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onSwitchToCashback,
            child: const Text('Switch to Cashback instead', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ),
        ],
      ],
    );
  }
}
