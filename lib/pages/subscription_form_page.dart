import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/subscription_service.dart';
import 'package:eharvest_mobile/pages/account_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

class SubscriptionFormPage extends StatefulWidget {
  final Produce? produce;
  final ProduceSubscription? subscription;

  const SubscriptionFormPage({super.key, this.produce, this.subscription});

  @override
  State<SubscriptionFormPage> createState() => _SubscriptionFormPageState();
}

class _SubscriptionFormPageState extends State<SubscriptionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _pickupAddressController = TextEditingController();
  final List<_SubscriptionItemDraft> _items = [];
  String _frequency = 'WEEKLY';
  String _currency = 'USD';
  bool _requiresLogistics = true;
  DateTime _startDate = DateTime.now();
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    final subscription = widget.subscription;
    final produce = widget.produce;
    if (subscription != null) {
      _frequency = subscription.frequency;
      _currency = subscription.currency;
      _requiresLogistics = subscription.requiresLogistics;
      _pickupAddressController.text = subscription.pickupAddress ?? '';
      _startDate = subscription.startDate;
      _items.addAll(
        subscription.items.map(
          (item) => _SubscriptionItemDraft(
            produceId: item.produceId,
            name: 'Produce #${item.produceId}',
            quantity: item.quantity,
            unitPrice: item.unitPrice,
          ),
        ),
      );
    } else if (produce != null) {
      _items.add(
        _SubscriptionItemDraft(
          produceId: produce.id,
          name: produce.name,
          quantity: 1,
          unitPrice: produce.price,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pickupAddressController.dispose();
    super.dispose();
  }

  int? _farmerId() {
    return widget.subscription?.farmerId ??
        widget.produce?.farmer?.id ??
        widget.produce?.farmerId;
  }

  double get _total {
    return _items.fold(
      0,
      (total, item) => total + (item.quantity * item.unitPrice),
    );
  }

  String _dateLabel(DateTime value) {
    return intl.DateFormat('yyyy-MM-dd HH:mm').format(value);
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDate),
    );
    setState(() {
      _startDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _startDate.hour,
        time?.minute ?? _startDate.minute,
      );
    });
  }

  String _toLocalIso(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}T'
        '${two(local.hour)}:${two(local.minute)}:00';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final farmerId = _farmerId();
    final buyerId = _isEditing
        ? widget.subscription!.buyerId
        : await AuthService.getUserId();
    if (buyerId == null || farmerId == null || farmerId <= 0) {
      setState(() {
        _error = 'Could not resolve buyer or farmer for this subscription.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final payload = {
      'buyerId': buyerId,
      'farmerId': farmerId,
      'frequency': _frequency,
      'requiresLogistics': _requiresLogistics,
      'pickupAddress': _requiresLogistics
          ? null
          : _pickupAddressController.text.trim(),
      'currency': _currency,
      'startDate': _toLocalIso(_startDate),
      'items': _items.map((item) => item.toJson()).toList(),
    };

    try {
      if (_isEditing) {
        await SubscriptionService.updateSubscription(
          widget.subscription!.id,
          payload,
        );
      } else {
        await SubscriptionService.createSubscription(payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Subscription updated.' : 'Subscription created.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Subscription' : 'Create Subscription'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.produce != null) _produceHeader(widget.produce!),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: _decoration('Frequency', Icons.repeat),
              items: const [
                DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                DropdownMenuItem(value: 'BIWEEKLY', child: Text('Biweekly')),
                DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _frequency = value ?? _frequency),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: _decoration('Currency', Icons.payments_outlined),
              items: const [
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'ZIG', child: Text('ZIG')),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _currency = value ?? _currency),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _submitting ? null : _pickStartDate,
              child: InputDecorator(
                decoration: _decoration('Start date', Icons.event),
                child: Text(_dateLabel(_startDate)),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _requiresLogistics,
              activeThumbColor: Color(primaryColour),
              title: const Text('Requires logistics'),
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _requiresLogistics = value),
            ),
            if (!_requiresLogistics) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _pickupAddressController,
                enabled: !_submitting,
                decoration: _decoration(
                  'Pickup address',
                  Icons.location_on_outlined,
                ),
                validator: (value) {
                  if (!_requiresLogistics && (value ?? '').trim().isEmpty) {
                    return 'Pickup address is required.';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) {
              return _itemTile(entry.key, entry.value);
            }),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subscription total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$_currency ${_total.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Color(primaryColour),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(primaryColour),
                  foregroundColor: Colors.white,
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isEditing ? 'Save Changes' : 'Create Subscription'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _produceHeader(Produce produce) {
    final farmerName = produce.farmer?.displayName ?? 'Farmer #${_farmerId()}';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: Icon(Icons.eco, color: Color(primaryColour)),
        ),
        title: Text(produce.name),
        subtitle: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkWell(
              onTap: () {
                final id = _farmerId();
                if (id != null && id > 0) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountPage(id: id),
                    ),
                  );
                }
              },
              child: Text(
                farmerName,
                style: const TextStyle(
                  color: Color(primaryColour),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(' - USD ${produce.price.toStringAsFixed(2)}'),
          ],
        ),

      ),
    );
  }

  Widget _itemTile(int index, _SubscriptionItemDraft item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Unit price: ${item.unitPrice.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _submitting || item.quantity <= 1
                  ? null
                  : () => setState(() => item.quantity--),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 54,
              child: TextFormField(
                enabled: !_submitting,
                initialValue: item.quantity.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(isDense: true),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed < 1) return 'Min 1';
                  return null;
                },
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0) {
                    setState(() => item.quantity = parsed);
                  }
                },
              ),
            ),
            IconButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() => item.quantity++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _SubscriptionItemDraft {
  final int produceId;
  final String name;
  int quantity;
  final double unitPrice;

  _SubscriptionItemDraft({
    required this.produceId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'produceId': produceId,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }
}
