import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'printer_service.dart';

class PrinterSelectDialog extends StatefulWidget {
  const PrinterSelectDialog({super.key});

  @override
  State<PrinterSelectDialog> createState() => _PrinterSelectDialogState();
}

class _PrinterSelectDialogState extends State<PrinterSelectDialog> {
  List<BluetoothInfo> devices = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() async {
    setState(() => isLoading = true);
    final list = await PrinterService.getPairedDevices();
    if (!mounted) return;
    setState(() {
      devices = list;
      isLoading = false;
    });
  }

  void _connect(String mac) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await PrinterService.connectPrinter(mac);
    if (!mounted) return;
    Navigator.pop(context); // Close loading spinner

    if (success) {
      Navigator.pop(context, true); // Return success to initiate print
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to Rugtek BP02. Ensure printer is ON and in range.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Select Rugtek BP02', style: TextStyle(fontSize: 18)),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rescan Paired Devices',
            onPressed: _loadDevices,
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        height: 260,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : devices.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'No paired printers found.\n\n1. Turn on Rugtek BP02\n2. Open Phone Settings > Bluetooth\n3. Pair BP02 (PIN 1234 or 0000)\n4. Tap the refresh icon above',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (_, idx) {
                      final d = devices[idx];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.print, color: Colors.brown),
                          title: Text(d.name.isEmpty ? 'Unknown Device' : d.name,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(d.macAdress, style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _connect(d.macAdress),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}