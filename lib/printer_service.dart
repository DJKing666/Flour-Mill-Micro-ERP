import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'printer_dialog.dart';

class PrinterService {
  // Explicit runtime permissions matching Utsav OS
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    await Future.delayed(const Duration(milliseconds: 300));
    return statuses[Permission.bluetoothConnect]?.isGranted ?? true;
  }

  // Print MillFlow receipt directly using unified_esc_pos_printer
  static Future<bool> printReceipt(
    BuildContext context, {
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

    // 1. Enforce Bluetooth runtime permissions
    await requestPermissions();

    final prefs = await SharedPreferences.getInstance();
    String? savedMac = prefs.getString('saved_printer_mac');
    final int feedLines = prefs.getInt('printer_feed_lines') ?? 2;

    final manager = PrinterManager();
    PrinterDevice? targetDevice;

    // 2. Locate saved Rugtek BP02 printer
    if (savedMac != null && savedMac.isNotEmpty) {
      try {
        final printers = await manager.scanPrinters(timeout: const Duration(seconds: 3));
        targetDevice = printers.firstWhere(
          (p) => (p as dynamic).address?.toString() == savedMac,
        );
      } catch (_) {
        targetDevice = null;
      }
    }

    // 3. Fallback to bottom sheet selector if not yet linked
    if (targetDevice == null) {
      if (!context.mounted) return false;
      targetDevice = await CustomPrinterSelectorBottomSheet.show(context);
    }

    if (targetDevice == null) {
      manager.dispose();
      return false; // User cancelled selector
    }

    // 4. Connect, format 58mm ticket, and print
    try {
      await manager.connect(targetDevice);
      final profile = await CapabilityProfile.load();
      final ticket = Ticket(PaperSize.mm58, profile);

      // Mill Header (32 columns width)
      ticket.text('================================');
      ticket.text('        MILLFLOW CHAKKI         ');
      ticket.text('  Fresh Flour & Grinding Depot  ');
      ticket.text('    Belagavi | Ph: 9731974669   ');
      ticket.text('================================');

      // Grinder Routing Callout
      if (assignedMachine != null && assignedMachine.isNotEmpty) {
        ticket.text('--------------------------------');
        ticket.text('QUEUE: ${assignedMachine.toUpperCase()}');
        ticket.text('--------------------------------');
      }

      // Metadata
      final timeStr =
          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
      ticket.text('Token: $orderId    $timeStr');
      ticket.text('Cust: $customerName');
      ticket.text('Ph:   $customerPhone');
      ticket.text('--------------------------------');

      // Line Items
      for (final line in orderDetails.split('\n')) {
        if (line.trim().isNotEmpty) {
          ticket.text(line.trim());
        }
      }
      ticket.text('--------------------------------');

      // Mode & Total
      ticket.text('MODE: $paymentMode');
      ticket.text('TOTAL: Rs ${totalAmount.toStringAsFixed(2)}');
      ticket.text('--------------------------------');

      // Native Dynamic UPI QR Code
      if (paymentMode == 'UPI') {
        final upiString =
            'upi://pay?pa=9731974669@upi&pn=MillFlowDirect&am=${totalAmount.toStringAsFixed(2)}&cu=INR&tn=$orderId';
        ticket.text('      Scan to Pay via UPI       ');
        ticket.qrcode(upiString);
        ticket.text('--------------------------------');
      }

      // Footer & Tear Feed
      ticket.text(' *** THANK YOU! VISIT AGAIN *** ');
      ticket.emptyLines(feedLines);
      ticket.cut();

      // Send to Rugtek BP02
      await manager.printTicket(ticket);
      await manager.disconnect();
      manager.dispose();
      return true;
    } catch (e) {
      print('Print error: $e');
      try {
        await manager.disconnect();
        manager.dispose();
      } catch (_) {}
      return false;
    }
  }
}