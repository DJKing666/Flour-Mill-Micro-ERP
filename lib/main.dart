import 'package:flutter/material.dart';
import 'models.dart';
import 'api_service.dart';
import 'storefront_screen.dart';
import 'receipt_dialog.dart';

void main() {
  runApp(const FlourMillPOSApp());
}

class FlourMillPOSApp extends StatelessWidget {
  const FlourMillPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flour Mill Micro-ERP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const MerchantPOSScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MerchantPOSScreen extends StatefulWidget {
  const MerchantPOSScreen({super.key});

  @override
  State<MerchantPOSScreen> createState() => _MerchantPOSScreenState();
}

class _MerchantPOSScreenState extends State<MerchantPOSScreen> {
  // Navigation State: 0 = Job-work, 1 = Retail, 2 = Web Orders
  int activeModeIndex = 0;

  List<CatalogItem> catalog = [];
  List<CartItem> cart = [];
  List<Map<String, dynamic>> incomingWebOrders = [];
  bool isLoading = false;

  // Job-work Form Controls
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _rateController = TextEditingController(text: "6.0");
  String _selectedMachine = "M1 (Wheat - Shed 1)";
  final List<String> _machines = [
    "M1 (Wheat - Shed 1)",
    "M2 (Coarse/Jowar - Shed 1)",
    "M3 (Spices/Besan - Shed 1)",
    "M4 (Expansion - Shed 2)",
  ];

  // Customer Controls
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _paymentMode = "Cash";

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() async {
    setState(() => isLoading = true);
    final items = await ApiService.fetchCatalog();
    final orders = await ApiService.fetchIncomingOrders();
    setState(() {
      catalog = items;
      incomingWebOrders = orders.where((o) => o['source'] == 'Web').toList();
      isLoading = false;
    });
  }

  void _addJobWorkToCart() {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;

    if (weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid grain weight.')),
      );
      return;
    }

    setState(() {
      cart.add(CartItem(
        title: "Grain Milling",
        weightKg: weight,
        ratePerKg: rate,
        isJobWork: true,
        assignedMachine: _selectedMachine,
      ));
      _weightController.clear();
    });
  }

  void _addRetailItemToCart(CatalogItem item, double kg) {
    setState(() {
      cart.add(CartItem(
        title: item.itemName,
        weightKg: kg,
        ratePerKg: item.pricePerKg,
        isJobWork: false,
      ));
    });
  }

  double get totalBillAmount => cart.fold(0, (sum, item) => sum + item.totalPrice);

  void _processCheckout() async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty.')));
      return;
    }

    // Capture values before clearing state
    final isJobWork = cart.any((i) => i.isJobWork);
    final jobItem = cart.firstWhere(
      (i) => i.isJobWork && i.assignedMachine != null,
      orElse: () => CartItem(title: '', weightKg: 0, ratePerKg: 0),
    );
    final assignedMachine = jobItem.assignedMachine;
    final summaryDetails = cart.map((i) => i.summary).join('\n');
    final billTotal = totalBillAmount;
    final enteredPhone = _phoneController.text.trim().isEmpty ? "9999999999" : _phoneController.text.trim();
    final enteredName = _nameController.text.trim().isEmpty ? "Walk-in Guest" : _nameController.text.trim();
    final selectedMode = _paymentMode;
    final orderTypeStr = isJobWork ? "Job-Work" : "Retail";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await ApiService.submitOrder(
      customerName: enteredName,
      customerPhone: enteredPhone,
      orderType: orderTypeStr,
      items: cart,
      totalAmount: billTotal,
      paymentMode: selectedMode,
    );

    Navigator.pop(context); // Close loading indicator

    if (res['success'] == true) {
      final generatedOrderId = res['orderId'] ?? 'ORD-LIVE';

      setState(() {
        cart.clear();
        _phoneController.clear();
        _nameController.clear();
      });
      _refreshData();

      // Automatically launch the thermal receipt modal
      showDialog(
        context: context,
        builder: (_) => ThermalReceiptDialog(
          orderId: generatedOrderId,
          customerName: enteredName,
          customerPhone: enteredPhone,
          orderType: orderTypeStr,
          orderDetails: summaryDetails,
          totalAmount: billTotal,
          paymentMode: selectedMode,
          assignedMachine: isJobWork ? assignedMachine : null,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${res['error']}')));
    }
  }

  void _confirmWebOrderPayment(String orderId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await ApiService.verifyPayment(orderId);
    Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order $orderId marked SUCCESS in Google Sheets!'), backgroundColor: Colors.green),
      );
      _refreshData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status. Check internet connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MillFlow Micro-ERP | Counter POS'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Sync Data',
          ),
          IconButton(
            icon: const Icon(Icons.storefront),
            tooltip: 'Open Customer Storefront',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerStorefrontScreen()),
              ).then((_) => _refreshData());
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // ---------------- LEFT COLUMN: OPERATIONS (60%) ----------------
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<int>(
                    segments: [
                      const ButtonSegment(value: 0, icon: Icon(Icons.build_circle_outlined), label: Text('Grinding')),
                      const ButtonSegment(value: 1, icon: Icon(Icons.storefront_outlined), label: Text('Retail Flour')),
                      ButtonSegment(
                        value: 2,
                        icon: const Icon(Icons.mark_email_unread_outlined),
                        label: Text('Web Orders (${incomingWebOrders.length})'),
                      ),
                    ],
                    selected: {activeModeIndex},
                    onSelectionChanged: (set) => setState(() => activeModeIndex = set.first),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: activeModeIndex == 0
                        ? _buildJobWorkSection()
                        : activeModeIndex == 1
                            ? _buildRetailSection()
                            : _buildWebOrdersSection(),
                  ),
                ],
              ),
            ),
          ),

          const VerticalDivider(width: 1),

          // ---------------- RIGHT COLUMN: BILLING & CART (40%) ----------------
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Counter Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone Number', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Customer Name', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: cart.isEmpty
                        ? const Center(child: Text('No items in current counter bill.'))
                        : ListView.separated(
                            itemCount: cart.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final item = cart[idx];
                              return ListTile(
                                dense: true,
                                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  item.isJobWork
                                      ? '${item.weightKg} kg × ₹${item.ratePerKg} | ${item.assignedMachine}'
                                      : '${item.weightKg} kg × ₹${item.ratePerKg}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('₹${item.totalPrice.toStringAsFixed(1)}'),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => setState(() => cart.removeAt(idx)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.brown.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Payable:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('₹${totalBillAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Payment: '),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Cash'),
                              selected: _paymentMode == 'Cash',
                              onSelected: (_) => setState(() => _paymentMode = 'Cash'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('UPI'),
                              selected: _paymentMode == 'UPI',
                              onSelected: (_) => setState(() => _paymentMode = 'UPI'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
                            icon: const Icon(Icons.receipt_long),
                            label: const Text('PUNCH & QUEUE ORDER', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _processCheckout,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Incoming Web Orders Queue with UTR Verification and Slip Preview
  Widget _buildWebOrdersSection() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (incomingWebOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No pending web orders found in queue.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: incomingWebOrders.length,
      itemBuilder: (ctx, idx) {
        final order = incomingWebOrders[idx];
        final utr = order['upiUtr']?.toString() ?? "";
        final paymentStatus = order['paymentStatus']?.toString() ?? "Pending";
        final totalAmt = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${order['orderId']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('₹$totalAmt',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.brown)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Customer: ${order['customerName']} (${order['customerPhone']})'),
                Text('Address: ${order['deliveryAddress']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Text('Items: ${order['orderDetails']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                const Divider(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: paymentStatus == 'Success' ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: paymentStatus == 'Success' ? Colors.green : Colors.amber.shade800,
                        ),
                      ),
                      child: Text(
                        'Payment: $paymentStatus',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: paymentStatus == 'Success' ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        utr.isNotEmpty ? 'UTR: $utr' : 'UTR: Not submitted yet',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: utr.isNotEmpty ? Colors.blue.shade900 : Colors.grey,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.brown),
                      tooltip: 'Preview Packing Slip',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => ThermalReceiptDialog(
                            orderId: order['orderId'] ?? 'ORD-WEB',
                            customerName: order['customerName'] ?? 'Customer',
                            customerPhone: order['customerPhone'] ?? '',
                            orderType: 'Retail (Web Delivery)',
                            orderDetails: order['orderDetails'] ?? '',
                            totalAmount: totalAmt,
                            paymentMode: order['paymentMode'] ?? 'UPI',
                            assignedMachine: null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('VERIFY PAYMENT & CONFIRM ORDER'),
                    onPressed: () => _confirmWebOrderPayment(order['orderId']),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Grinding Calculator Form
  Widget _buildJobWorkSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Walk-in Grain Grinding Calculator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Grain Inward Weight (kg)', suffixText: 'kg', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Grinding Charge per kg', prefixText: '₹', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedMachine,
              decoration: const InputDecoration(labelText: 'Assign to Machine / Shed', border: OutlineInputBorder()),
              items: _machines.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) => setState(() => _selectedMachine = val!),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add Job to Bill'),
                onPressed: _addJobWorkToCart,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Retail Product Cards
  Widget _buildRetailSection() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    final retailItems = catalog.where((i) => i.category == 'Flour_Sales').toList();

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: retailItems.length,
      itemBuilder: (ctx, idx) {
        final item = retailItems[idx];
        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.itemName, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${item.pricePerKg} / kg', style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
                Text('Stock: ${item.stockAvailableKg} kg', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _addRetailItemToCart(item, 1.0),
                        child: const Text('+1kg'),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _addRetailItemToCart(item, 5.0),
                        child: const Text('+5kg'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}