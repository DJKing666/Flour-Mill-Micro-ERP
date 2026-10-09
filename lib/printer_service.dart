import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'printer_dialog.dart';

class PrinterService {
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

    await requestPermissions();

    final prefs = await SharedPreferences.getInstance();
    String? savedMac = prefs.getString('saved_printer_mac');
    final int feedLines = prefs.getInt('printer_feed_lines') ?? 2;

    final manager = PrinterManager();
    PrinterDevice? targetDevice;

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

    if (targetDevice == null) {
      if (!context.mounted) return false;
      targetDevice = await CustomPrinterSelectorBottomSheet.show(context);
    }

    if (targetDevice == null) {
      manager.dispose();
      return false;
    }

    try {
      await manager.connect(targetDevice);
      
      // Allow connection to stabilize before sending bytes
      await Future.delayed(const Duration(milliseconds: 500));

      final profile = await CapabilityProfile.load();
      final ticket = Ticket(PaperSize.mm58, profile);

      ticket.text('================================');
      ticket.text('        MILLFLOW CHAKKI         ');
      ticket.text('  Fresh Flour & Grinding Depot  ');
      ticket.text('    Belagavi | Ph: 9731974669   ');
      ticket.text('================================');

      if (assignedMachine != null && assignedMachine.isNotEmpty) {
        ticket.text('--------------------------------');
        ticket.text('QUEUE: ${assignedMachine.toUpperCase()}');
        ticket.text('--------------------------------');
      }

      final timeStr =
          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
      ticket.text('Token: $orderId    $timeStr');
      ticket.text('Cust: $customerName');
      ticket.text('Ph:   $customerPhone');
      ticket.text('--------------------------------');

      for (final line in orderDetails.split('\n')) {
        if (line.trim().isNotEmpty) {
          ticket.text(line.trim());
        }
      }
      ticket.text('--------------------------------');

      ticket.text('MODE: $paymentMode');
      ticket.text('TOTAL: Rs ${totalAmount.toStringAsFixed(2)}');
      ticket.text('--------------------------------');

      // CRITICAL FIX: Removed ticket.qrcode(upiString).
      // Sending native hardware QR commands corrupts the BP02 buffer, causing a blank feed.
      if (paymentMode == 'UPI') {
        ticket.text('      Scan to Pay via UPI       ');
        ticket.text('     (Use QR on screen)         ');
        ticket.text('--------------------------------');
      }

      ticket.text(' *** THANK YOU! VISIT AGAIN *** ');
      ticket.emptyLines(feedLines);
      ticket.cut();

      // Send bytes to printer
      await manager.printTicket(ticket);
      
      // CRITICAL FIX: Allow RFCOMM buffer to fully flush to the printer before severing the connection.
      // Without this, the socket closes while bytes are still in transit.
      await Future.delayed(const Duration(seconds: 2));
      
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