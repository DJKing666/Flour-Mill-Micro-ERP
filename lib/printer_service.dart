import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class PrinterService {
  // Check if Bluetooth is turned on and permitted
  static Future<bool> isBluetoothReady() async {
    if (kIsWeb) return false;
    try {
      final bool enabled = await PrintBluetoothThermal.bluetoothEnabled;
      return enabled;
    } catch (_) {
      return false;
    }
  }

  // Check connection status
  static Future<bool> isConnected() async {
    if (kIsWeb) return false;
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  // Get paired Bluetooth devices with safety timeout
  static Future<List<BluetoothInfo>> getPairedDevices() async {
    if (kIsWeb) return [];
    try {
      return await PrintBluetoothThermal.pairedBluetooths
          .timeout(const Duration(seconds: 4), onTimeout: () => []);
    } catch (e) {
      print('Error getting devices: $e');
      return [];
    }
  }

  // Connect to Rugtek BP02 with stabilization delay
  static Future<bool> connectPrinter(String macAddress) async {
    if (kIsWeb) return false;
    try {
      final connected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress)
          .timeout(const Duration(seconds: 6), onTimeout: () => false);
      if (connected) {
        // Small delay to allow the RFCOMM serial socket to stabilize
        await Future.delayed(const Duration(milliseconds: 300));
      }
      return connected;
    } catch (e) {
      print('Error connecting: $e');
      return false;
    }
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
    if (kIsWeb) return false;

    try {
      final bool connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) return false;

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      // 1. Mill Header
      bytes += generator.text(
        'MILLFLOW CHAKKI',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ),
      );
      bytes += generator.text('Fresh Flour & Grinding Depot', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Belagavi | Ph: 9731974669', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();

      // 2. Machine Routing Callout (Clean border compatible with Rugtek BP02)
      if (assignedMachine != null && assignedMachine.isNotEmpty) {
        bytes += generator.text(
          '================================',
          styles: const PosStyles(align: PosAlign.center),
        );
        bytes += generator.text(
          'QUEUE: ${assignedMachine.toUpperCase()}',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
        bytes += generator.text(
          '================================',
          styles: const PosStyles(align: PosAlign.center),
        );
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
      for (final line in orderDetails.split('\n')) {
        if (line.trim().isNotEmpty) {
          bytes += generator.text(line.trim(), styles: const PosStyles(fontType: PosFontType.fontB));
        }
      }
      bytes += generator.hr();

      // 5. Total
      bytes += generator.row([
        PosColumn(text: 'MODE: $paymentMode', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'Rs ${totalAmount.toStringAsFixed(2)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true, width: PosTextSize.size2),
        ),
      ]);
      bytes += generator.hr();

      // 6. Dynamic UPI QR
      if (paymentMode == 'UPI') {
        final upiString =
            'upi://pay?pa=9731974669@upi&pn=MillFlowDirect&am=${totalAmount.toStringAsFixed(2)}&cu=INR&tn=$orderId';
        bytes += generator.text('Scan to Pay via UPI', styles: const PosStyles(align: PosAlign.center, bold: true));
        bytes += generator.qrcode(upiString, size: QRSize.size4);
        bytes += generator.hr();
      }

      // 7. Footer & Paper Feed (Feeds paper past the manual tear bar)
      bytes += generator.text('*** THANK YOU! VISIT AGAIN ***', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(3);

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      print('Print execution error: $e');
      return false;
    }
  }
}