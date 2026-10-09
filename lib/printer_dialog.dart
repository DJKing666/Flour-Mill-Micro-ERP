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
    final list = await PrinterService.getPairedDevices();
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
    Navigator.pop(context); // close loader
    Navigator.pop(context, success); // close dialog
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connect Rugtek BP02'),
      content: SizedBox(
        width: 300,
        height: 250,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : devices.isEmpty
                ? const Center(child: Text('No paired devices found. Pair BP02 in Android Settings first.'))
                : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (_, idx) {
                      final d = devices[idx];
                      return ListTile(
                        leading: const Icon(Icons.print),
                        title: Text(d.name),
                        subtitle: Text(d.macAdress),
                        onTap: () => _connect(d.macAdress),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}