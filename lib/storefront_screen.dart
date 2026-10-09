import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'api_service.dart';

class CustomerStorefrontScreen extends StatefulWidget {
  const CustomerStorefrontScreen({super.key});

  @override
  State<CustomerStorefrontScreen> createState() => _CustomerStorefrontScreenState();
}

class _CustomerStorefrontScreenState extends State<CustomerStorefrontScreen> {
  static const String merchantUpiId = "9731974669@upi";
  static const String merchantBusinessName = "MillFlow Direct";

  List<CatalogItem> items = [];
  bool isLoading = true;
  final Map<String, int> cartQuantities = {};

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _promoController = TextEditingController();

  double discountPercent = 0.0;
  String promoFeedback = "";

  @override
  void initState() {
    super.initState();
    _loadStorefrontCatalog();
  }

  void _loadStorefrontCatalog() async {
    setState(() => isLoading = true);
    final catalog = await ApiService.fetchCatalog();
    setState(() {
      items = catalog.where((item) => item.webVisibility && item.category == 'Flour_Sales').toList();
      isLoading = false;
    });
  }

  void _updateQuantity(String itemId, int delta) {
    setState(() {
      final current = cartQuantities[itemId] ?? 0;
      final updated = current + delta;
      if (updated <= 0) {
        cartQuantities.remove(itemId);
      } else {
        cartQuantities[itemId] = updated;
      }
    });
  }

  double get subtotalAmount {
    double total = 0.0;
    cartQuantities.forEach((itemId, qty) {
      final item = items.firstWhere((i) => i.itemId == itemId, orElse: () => items.first);
      total += (item.pricePerKg * qty);
    });
    return total;
  }

  double get finalPayableAmount {
    return subtotalAmount * (1.0 - discountPercent);
  }

  void _applyPromo() {
    final code = _promoController.text.trim().toUpperCase();
    setState(() {
      if (code == "FRESH10") {
        discountPercent = 0.10;
        promoFeedback = "Coupon Applied! 10% Off on your order.";
      } else if (code.isEmpty) {
        discountPercent = 0.0;
        promoFeedback = "";
      } else {
        discountPercent = 0.0;
        promoFeedback = "Invalid coupon code.";
      }
    });
  }

  void _initiateUpiFlow(String orderId, double amount) async {
    final rawUpiString =
        'upi://pay?pa=$merchantUpiId&pn=${Uri.encodeComponent(merchantBusinessName)}&am=${amount.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent(orderId)}';
    final upiUrl = Uri.parse(rawUpiString);

    if (await canLaunchUrl(upiUrl)) {
      await launchUrl(upiUrl, mode: LaunchMode.externalApplication);
    }

    if (!mounted) return;
    _showUtrInputDialog(orderId, amount, rawUpiString);
  }

  void _showUtrInputDialog(String orderId, double amount, String rawUpiString) {
    final utrController = TextEditingController();
    final qrApiUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(rawUpiString)}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete UPI Payment', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Payable: ₹${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown)),
              Text('Order Ref: $orderId', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              Image.network(
                qrApiUrl,
                width: 160,
                height: 160,
                errorBuilder: (_, __, ___) => const Icon(Icons.qr_code, size: 80),
              ),
              const SizedBox(height: 12),
              const Text(
                'Scan above or complete payment in your UPI app, then paste the 12-digit UTR / Ref No. below:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: utrController,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: const InputDecoration(
                  labelText: '12-Digit UPI UTR / Ref Number',
                  hintText: 'e.g. 428901234567',
                  border: OutlineInputBorder(),
                  counterText: "",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => cartQuantities.clear());
            },
            child: const Text('I will pay on Delivery'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
            onPressed: () async {
              final utr = utrController.text.trim();
              if (utr.length != 12) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid 12-digit UTR number.')),
                );
                return;
              }

              Navigator.pop(ctx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              final res = await ApiService.submitUtr(orderId: orderId, upiUtr: utr);
              Navigator.pop(context); // close loader

              if (res['success'] == true) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Payment Recorded!'),
                    content: Text('UTR $utr received. The mill will verify and dispatch your order shortly.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() => cartQuantities.clear());
                        },
                        child: const Text('Done'),
                      )
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to submit UTR: ${res['error']}')),
                );
              }
            },
            child: const Text('Submit UTR'),
          ),
        ],
      ),
    );
  }

  void _submitWebOrder() async {
    if (cartQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your basket is empty.')));
      return;
    }
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().length < 10 ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill Name, Phone, and Delivery Address.')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final summary = cartQuantities.entries.map((entry) {
      final item = items.firstWhere((i) => i.itemId == entry.key);
      return '${item.itemName} (${entry.value}kg)';
    }).join(', ');

    final res = await ApiService.submitWebOrder(
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      deliveryAddress: _addressController.text.trim(),
      promoCode: _promoController.text.trim().toUpperCase(),
      orderDetails: summary,
      totalAmount: finalPayableAmount,
    );

    Navigator.pop(context);

    if (res['success'] == true) {
      final orderId = res['orderId'] ?? 'ORD-WEB';
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Order Placed Successfully!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order ID: $orderId'),
              Text('Payable Amount: ₹${finalPayableAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              const Text('Select your payment method:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => cartQuantities.clear());
              },
              child: const Text('Cash on Delivery'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _initiateUpiFlow(orderId, finalPayableAmount);
              },
              child: const Text('Pay via UPI'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: ${res['error']}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fresh Flours | Direct Mill Store'),
        backgroundColor: Colors.brown.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.brown.shade800, Colors.brown.shade600]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('100% Stone-Ground Fresh Flour',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Milled fresh upon order. No preservatives.',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          SizedBox(height: 6),
                          Text('Use code FRESH10 for 10% off your first delivery!',
                              style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Select Your Flours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...items.map((item) {
                      final qty = cartQuantities[item.itemId] ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.brown.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.grain, color: Colors.brown, size: 32),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.itemName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text('₹${item.pricePerKg.toStringAsFixed(0)} / kg',
                                        style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    color: Colors.grey.shade700,
                                    onPressed: qty > 0 ? () => _updateQuantity(item.itemId, -1) : null,
                                  ),
                                  Text('$qty kg',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: Colors.brown),
                                    onPressed: () => _updateQuantity(item.itemId, 1),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    }),
                    if (cartQuantities.isNotEmpty) ...[
                      const Divider(height: 32),
                      const Text('Delivery & Checkout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(labelText: 'WhatsApp Phone Number', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'Flat / Society / Street Address', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _promoController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Promo Code (e.g. FRESH10)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.brown, foregroundColor: Colors.white),
                            onPressed: _applyPromo,
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                      if (promoFeedback.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(promoFeedback,
                            style: TextStyle(
                                color: discountPercent > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration:
                            BoxDecoration(color: Colors.brown.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal:'),
                                Text('₹${subtotalAmount.toStringAsFixed(2)}'),
                              ],
                            ),
                            if (discountPercent > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Discount (10%):', style: TextStyle(color: Colors.green)),
                                  Text('- ₹${(subtotalAmount * discountPercent).toStringAsFixed(2)}',
                                      style: const TextStyle(color: Colors.green)),
                                ],
                              ),
                            ],
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Payable:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('₹${finalPayableAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.brown)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown.shade800, foregroundColor: Colors.white),
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: const Text('CONFIRM ORDER & PROCEED',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: _submitWebOrder,
                        ),
                      ),
                      const SizedBox(height: 30),
                    ]
                  ],
                ),
              ),
            ),
    );
  }
}