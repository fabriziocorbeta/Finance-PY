import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../services/exchange_rate_service.dart';
import 'package:provider/provider.dart';

typedef ExchangeRateChanged = void Function(String? exchangeRate);

/// Shared dual-tab exchange-rate entry widget, mirroring the web app's
/// "Convertir" / "Calcular tasa" tabs (app/views/shared/_exchange_rate_tabs.html.erb
/// + app/javascript/controllers/exchange_rate_form_controller.js).
///
/// The rate value that gets submitted (via [onRateChanged]) is always an
/// opaque decimal String -- never round-tripped through a `double` -- to
/// avoid reintroducing the binary-float rounding this feature exists to
/// avoid. `double` arithmetic is only ever used for on-screen previews.
class ExchangeRateEntry extends StatefulWidget {
  final String sourceAmount;
  final String fromCurrency;
  final String toCurrency;
  final String date; // yyyy-MM-dd
  final ExchangeRateChanged onRateChanged;

  const ExchangeRateEntry({
    super.key,
    required this.sourceAmount,
    required this.fromCurrency,
    required this.toCurrency,
    required this.date,
    required this.onRateChanged,
  });

  @override
  State<ExchangeRateEntry> createState() => _ExchangeRateEntryState();
}

/// Pads a decimal string to at least [minDecimals] digits using plain
/// string manipulation -- never Number/toFixed, which would reintroduce
/// the binary-float rounding this feature exists to avoid.
String padMinDecimals(String decimalString, {int minDecimals = 2}) {
  final parts = decimalString.split('.');
  final integerPart = parts[0];
  final decimalPart = parts.length > 1 ? parts[1] : '';
  return '$integerPart.${decimalPart.padRight(minDecimals, '0')}';
}

class _ExchangeRateEntryState extends State<ExchangeRateEntry>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _rateController = TextEditingController();
  final _destinationAmountController = TextEditingController();
  final _exchangeRateService = ExchangeRateService();

  String? _rateHint;
  bool _loading = false;
  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scheduleFetch();
  }

  @override
  void didUpdateWidget(covariant ExchangeRateEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fromCurrency != widget.fromCurrency ||
        oldWidget.toCurrency != widget.toCurrency ||
        oldWidget.date != widget.date ||
        oldWidget.sourceAmount != widget.sourceAmount) {
      _scheduleFetch();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _rateController.dispose();
    _destinationAmountController.dispose();
    super.dispose();
  }

  bool get _sameCurrency => widget.fromCurrency == widget.toCurrency;

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      _destinationAmountController.clear();
    } else {
      _rateController.clear();
    }
    widget.onRateChanged(null);
    setState(() {});
  }

  void _scheduleFetch() {
    _debounce?.cancel();

    if (_sameCurrency) {
      widget.onRateChanged(null);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), _fetchRate);
  }

  Future<void> _fetchRate() async {
    final requestId = ++_requestId;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted || requestId != _requestId) return;

    setState(() => _loading = true);

    final result = await _exchangeRateService.getRate(
      accessToken: accessToken,
      from: widget.fromCurrency,
      to: widget.toCurrency,
      date: widget.date,
    );

    if (!mounted || requestId != _requestId) return;

    setState(() {
      _loading = false;

      if (result['success'] == true && result['sameCurrency'] != true) {
        final rate = result['rate'] as String?;
        _rateHint = result['rateHint'] as String?;
        if (rate != null && _tabController.index == 0) {
          _rateController.text = padMinDecimals(rate);
          widget.onRateChanged(_rateController.text);
        }
      } else if (result['error'] == 'not_found') {
        _rateHint = result['rateHint'] as String?;
        _rateController.clear();
        widget.onRateChanged(null);
      } else {
        _rateHint = null;
      }
    });
  }

  void _onRateFieldChanged(String value) {
    widget.onRateChanged(value.isEmpty ? null : value);
    setState(() {});
  }

  void _onDestinationAmountChanged(String value) {
    final sourceAmount = double.tryParse(widget.sourceAmount);
    final destAmount = double.tryParse(value);

    if (sourceAmount != null && sourceAmount != 0 && destAmount != null) {
      final rate = destAmount / sourceAmount;
      final formatted = padMinDecimals(rate.toStringAsFixed(14), minDecimals: 2);
      widget.onRateChanged(formatted);
    } else {
      widget.onRateChanged(null);
    }
    setState(() {});
  }

  double? _previewDestinationAmount() {
    final sourceAmount = double.tryParse(widget.sourceAmount);
    final rate = double.tryParse(_rateController.text);
    if (sourceAmount == null || rate == null) return null;
    return sourceAmount * rate;
  }

  double? _previewRate() {
    final sourceAmount = double.tryParse(widget.sourceAmount);
    final destAmount = double.tryParse(_destinationAmountController.text);
    if (sourceAmount == null || sourceAmount == 0 || destAmount == null) return null;
    return destAmount / sourceAmount;
  }

  @override
  Widget build(BuildContext context) {
    if (_sameCurrency) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final previewDestination = _previewDestinationAmount();
    final previewRate = _previewRate();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Convertir'),
            Tab(text: 'Calcular tasa'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: manual/prefilled rate -> computed destination amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: _onRateFieldChanged,
                    decoration: InputDecoration(
                      labelText: 'Tasa de cambio',
                      suffixIcon: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Monto convertido'),
                        Text(
                          previewDestination != null
                              ? '${previewDestination.toStringAsFixed(2)} ${widget.toCurrency}'
                              : '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Tab 2: destination amount -> computed implied rate
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _destinationAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: _onDestinationAmountChanged,
                    decoration: InputDecoration(
                      labelText: 'Monto en ${widget.toCurrency}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tasa de cambio'),
                        Text(
                          previewRate != null ? previewRate.toStringAsFixed(4) : '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_rateHint != null) ...[
          const SizedBox(height: 4),
          Text(
            _rateHint!,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
