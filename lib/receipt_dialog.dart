import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'printer_service.dart';
import 'printer_dialog.dart';

class ThermalReceiptDialog extends StatelessWidget {
  final String orderId;
  final String customerName;
  final String customerPhone;
  final String orderType;
  final String orderDetails;
  final double totalAmount;
  final String paymentMode;
  final String? assignedMachine;

  const ThermalReceiptDialog({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.customerPhone,
    required this.orderType,
    required this.orderDetails,
    required this.totalAmount,
    required this.paymentMode,
    this.assignedMachine,
  });

  @override
  Widget build(BuildContext context) {
    // Registered UPI ID for dynamic QR generation
    const merchantUpiId = "9731974669@upi";
    const merchantName = "MillFlow Direct";

    final upiPayload =
        'upi://pay?pa=$merchantUpiId&pn=${Uri.encodeComponent(merchantName)}&am=${totalAmount.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent(orderId)}';
    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(upiPayload)}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          width: 320, // Standard 58mm / 80mm thermal paper scale
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Mill Header
                const Text(
                  "MILLFLOW CHAKKI",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2),
                ),
                const Text(
                  "Fresh Flour & Grinding Depot",
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const Text("Belagavi, Karnataka | Ph: +91 9731974669", style: TextStyle(fontSize: 10)),
                const SizedBox(height: 8),
                const Text("------------------------------------------", style: TextStyle(letterSpacing: -1)),

                // 2. Machine Routing Callout (Crucial for Grinder Operators)
                if (assignedMachine != null && assignedMachine!.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Text(
                      "QUEUE: ${assignedMachine!.toUpperCase()}",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Text("------------------------------------------", style: TextStyle(letterSpacing: -1)),
                ],

                // 3. Order Metadata
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Token: $orderId", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(
                      "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Cust: $customerName", style: const TextStyle(fontSize: 11)),
                    Text("Ph: $customerPhone", style: const TextStyle(fontSize: 11)),
                  ],
                ),
                const Text("------------------------------------------", style: TextStyle(letterSpacing: -1)),

                // 4. Line Items
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    orderDetails,
                    style: const TextStyle(fontSize: 12, height: 1.3, fontFamily: 'monospace'),
                  ),
                ),
                const Text("------------------------------------------", style: TextStyle(letterSpacing: -1)),

                // 5. Total & Payment Mode
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("MODE: $paymentMode", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(
                      "TOTAL: ₹${totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
                const Text("------------------------------------------", style: TextStyle(letterSpacing: -1)),

                // 6. Dynamic UPI QR Code (Scannable from counter slip)
                if (paymentMode == "UPI") ...[
                  const SizedBox(height: 6),
                  Image.network(
                    qrUrl,
                    width: 140,
                    height: 140,
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
                    errorBuilder: (_, __, ___) => const Icon(Icons.qr_code, size: 80),
                  ),
                  const SizedBox(height: 4),
                  const Text("Scan to Pay via UPI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text("------------------------------------------", style: TextStyle(letterSpacing: -1)),
                ],

                // 7. Footer
                const SizedBox(height: 4),
                const Text("Pure stone-ground goodness.", style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                const Text("*** THANK YOU! VISIT AGAIN ***", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),

                const SizedBox(height: 14),

                // Dialog Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text("Print"),
                      onPressed: () async {
                        if (kIsWeb) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Physical Bluetooth printing requires running on Android tablet/device.'),
                            ),
                          );
                          return;
                        }

                        // Check Bluetooth printer connection status
                        bool connected = await PrinterService.isConnected();
                        if (!connected) {
                          if (!context.mounted) return;
                          final res = await showDialog<bool>(
                            context: context,
                            builder: (_) => const PrinterSelectDialog(),
                          );
                          if (res != true) return;
                        }

                        // Send ESC/POS byte stream to Rugtek BP02
                        final printSuccess = await PrinterService.printReceipt(
                          orderId: orderId,
                          customerName: customerName,
                          customerPhone: customerPhone,
                          orderType: orderType,
                          orderDetails: orderDetails,
                          totalAmount: totalAmount,
                          paymentMode: paymentMode,
                          assignedMachine: assignedMachine,
                        );

                        if (!context.mounted) return;

                        if (printSuccess) {
                          Navigator.pop(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Print failed. Ensure BP02 has paper and is turned on.'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}