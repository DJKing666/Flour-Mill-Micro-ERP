import 'package:flutter/material.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomPrinterSelectorBottomSheet extends StatefulWidget {
  const CustomPrinterSelectorBottomSheet({super.key});

  static Future<PrinterDevice?> show(BuildContext context) {
    return showModalBottomSheet<PrinterDevice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const CustomPrinterSelectorBottomSheet(),
    );
  }

  @override
  State<CustomPrinterSelectorBottomSheet> createState() =>
      _CustomPrinterSelectorBottomSheetState();
}

class _CustomPrinterSelectorBottomSheetState
    extends State<CustomPrinterSelectorBottomSheet> {
  final PrinterManager _manager = PrinterManager();
  List<PrinterDevice> _devices = [];
  bool _isScanning = false;
  String? _savedPrinterMac;
  String? _savedPrinterName;

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
    _startDiscovery();
  }

  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPrinterMac = prefs.getString('saved_printer_mac');
      _savedPrinterName = prefs.getString('saved_printer_name');
    });
  }

  Future<void> _disconnectPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_printer_mac');
    await prefs.remove('saved_printer_name');
    setState(() {
      _savedPrinterMac = null;
      _savedPrinterName = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer unlinked'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _startDiscovery() {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    _manager.scanAll(timeout: const Duration(seconds: 5)).listen(
      (devices) {
        if (mounted) {
          setState(() => _devices = devices);
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _isScanning = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  String _getDeviceAddress(PrinterDevice device) {
    if (device is BluetoothPrinterDevice) {
      return device.address;
    }
    try {
      return (device as dynamic).address.toString();
    } catch (_) {
      return device.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: _startDiscovery,
            borderRadius: BorderRadius.circular(60),
            child: Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF65D59A),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF65D59A).withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isScanning
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Icon(Icons.autorenew, color: Colors.black, size: 32),
                  const SizedBox(height: 4),
                  Text(
                    _isScanning ? 'Scanning' : 'Search',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_savedPrinterMac != null && _savedPrinterMac!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Currently Linked Rugtek BP02',
                style: TextStyle(
                  color: Color(0xFF65D59A),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF65D59A), width: 1.5),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.print_rounded,
                      color: Color(0xFF65D59A), size: 28),
                ),
                title: Text(
                  _savedPrinterName ?? 'Rugtek BP02',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'MAC: $_savedPrinterMac',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white70),
                      tooltip: 'Feed Margin Settings',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const PrinterConfigDialog(),
                        );
                      },
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.red.shade900.withValues(alpha: 0.3),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _disconnectPrinter,
                      child: const Text('Unlink',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Discovered & Paired Devices',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _isScanning && _devices.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF65D59A)),
                  )
                : _devices.isEmpty
                    ? const Center(
                        child: Text(
                          'No devices found.\nEnsure Rugtek BP02 is powered ON and paired in Android Bluetooth settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _devices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final String devAddress = _getDeviceAddress(device);
                          final bool isCurrentActive =
                              devAddress == _savedPrinterMac;

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade800),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C2C2C),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.print_rounded,
                                    color: Colors.grey, size: 28),
                              ),
                              title: Text(
                                device.name.isNotEmpty
                                    ? device.name
                                    : 'Thermal Printer',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                devAddress,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isCurrentActive
                                      ? const Color(0xFF1B3B2B)
                                      : const Color(0xFF252525),
                                  foregroundColor: const Color(0xFF65D59A),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setString(
                                      'saved_printer_mac', devAddress);
                                  await prefs.setString(
                                    'saved_printer_name',
                                    device.name.isNotEmpty
                                        ? device.name
                                        : 'Rugtek BP02',
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context, device);
                                  }
                                },
                                child: Text(
                                  isCurrentActive ? 'Linked' : 'Link',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class PrinterConfigDialog extends StatefulWidget {
  const PrinterConfigDialog({super.key});

  @override
  State<PrinterConfigDialog> createState() => _PrinterConfigDialogState();
}

class _PrinterConfigDialogState extends State<PrinterConfigDialog> {
  int _feedLines = 2;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _feedLines = prefs.getInt('printer_feed_lines') ?? 2;
    });
  }

  Future<void> _saveConfig(int lines) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('printer_feed_lines', lines);
    setState(() => _feedLines = lines);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Printer Margin Setting',
          style: TextStyle(color: Colors.white)),
      content: ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Tear-off Margin',
            style: TextStyle(color: Colors.white70)),
        subtitle: Text('$_feedLines blank feed lines after ticket',
            style: const TextStyle(color: Colors.grey)),
        trailing: DropdownButton<int>(
          dropdownColor: const Color(0xFF2C2C2C),
          style: const TextStyle(color: Colors.white),
          value: _feedLines,
          items: [1, 2, 3, 4, 5]
              .map((n) => DropdownMenuItem(value: n, child: Text('$n lines')))
              .toList(),
          onChanged: (val) {
            if (val != null) _saveConfig(val);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done', style: TextStyle(color: Color(0xFF65D59A))),
        ),
      ],
    );
  }
}