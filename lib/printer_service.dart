import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class PrinterService {
  // Check Bluetooth connection status
  static Future<bool> isConnected() async {
    if (kIsWeb) return false;
    return await PrintBluetoothThermal.connectionStatus;
  }

  // Get paired Bluetooth devices
  static Future<List<BluetoothInfo>> getPairedDevices() async {
    if (kIsWeb) return [];
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  // Connect to the Rugtek BP02 by MAC address
  static Future<bool> connectPrinter(String macAddress) async {
    if (kIsWeb) return false;
    return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  // Generate 58mm ESC/POS byte buffer and print
  static Future<bool> printReceipt({
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String orderType,
    required String orderDetails,
    required double totalAmount,
    required String paymentMode,
    String? assignedMachine,
  }) async {
    if (kIsWeb) {
      print("Bluetooth ESC/POS printing is supported on native Android/iOS devices.");
      return false;
    }

    final bool connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) return false;

    // Load standard 58mm thermal profile
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // 1. Header
    bytes += generator.text(
      'MILLFLOW CHAKKI',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    bytes += generator.text(
      'Fresh Flour & Grinding Depot',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Belagavi | Ph: 9731974669',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();

    // 2. Machine Routing Callout (Inverted background for grinder operator)
    if (assignedMachine != null && assignedMachine.isNotEmpty) {
      bytes += generator.text(
        'QUEUE: ${assignedMachine.toUpperCase()}',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          reverse: true, // Inverted black banner
        ),
      );
      bytes += generator.hr();
    }

    // 3. Metadata
    bytes += generator.row([
      PosColumn(text: 'Token: $orderId', width: 7, styles: const PosStyles(bold: true)),
      PosColumn(
        text: '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.text('Cust: $customerName ($customerPhone)');
    bytes += generator.hr();

    // 4. Line Items
    final lines = orderDetails.split('\n');
    for (final line in lines) {
      bytes += generator.text(line, styles: const PosStyles(fontType: PosFontType.fontB));
    }
    bytes += generator.hr();

    // 5. Total & Payment
    bytes += generator.row([
      PosColumn(text: 'MODE: $paymentMode', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: 'Rs ${totalAmount.toStringAsFixed(2)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, width: PosTextSize.size2),
      ),
    ]);
    bytes += generator.hr();

    // 6. Native Dynamic UPI QR Code
    if (paymentMode == "UPI") {
      final upiString =
          'upi://pay?pa=9731974669@upi&pn=MillFlowDirect&am=${totalAmount.toStringAsFixed(2)}&cu=INR&tn=$orderId';
      bytes += generator.text('Scan to Pay via UPI', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.qrcode(upiString, size: QRSize.size4);
      bytes += generator.hr();
    }

    // 7. Footer & Paper Feed
    bytes += generator.text(
      '*** THANK YOU! VISIT AGAIN ***',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.feed(2);
    bytes += generator.cut();

    // Send raw byte stream to Rugtek BP02
    return await PrintBluetoothThermal.writeBytes(bytes);
  }
}