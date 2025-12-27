import 'package:flutter/material.dart';
import 'dart:async';
import '../../../constants/app_dimensions.dart';
import '../../../models/unified_bluetooth_device.dart';
import '../../../services/bluetooth/unified_bluetooth_service.dart';
import '../../../services/bluetooth/bluetooth_device_manager.dart';
import '../../../services/permissions/permission_manager.dart';
import '../../../utils/app_logger.dart';

class UnifiedScannerScreen extends StatefulWidget {
  const UnifiedScannerScreen({super.key});

  @override
  State<UnifiedScannerScreen> createState() => _UnifiedScannerScreenState();
}

class _UnifiedScannerScreenState extends State<UnifiedScannerScreen> with SingleTickerProviderStateMixin {
  final _unifiedService = UnifiedBluetoothService.instance;

  final Map<String, UnifiedBluetoothDevice> _discoveredDevices = {};
  List<UnifiedBluetoothDevice> _savedDevices = [];
  Map<String, UnifiedConnectionInfo> _connectionStates = {};

  bool _isScanning = false;
  
  late TabController _tabController;

  StreamSubscription? _discoverySubscription;
  StreamSubscription? _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initializeService();
    _listenToDiscovery();
    _listenToConnectionStates();
    _loadSavedDevices();
  }
  
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // Tab 0 = Scanner, Tab 1 = Paired Devices
      if (_tabController.index == 0) {
        // Scanner tab - only auto-scan if no devices are connected
        _autoScanIfNeeded();
      } else {
        // Paired devices tab - pause scanning
        if (_isScanning) {
          _stopScan();
        }
      }
    }
  }
  
  void _autoScanIfNeeded() {
    // Check if any device is connected
    final hasConnectedDevices = _connectionStates.values.any((info) => info.isConnected);
    
    if (!hasConnectedDevices && !_isScanning) {
      _startScan();
    }
  }

  Future<void> _initializeService() async {
    try {
      await _unifiedService.initialize();
    } catch (e) {
      AppLogger.error('Failed to initialize: $e');
    }
  }

  void _listenToDiscovery() {
    _discoverySubscription = _unifiedService.discoveredDevices.listen((device) {
      if (mounted) {
        setState(() {
          _discoveredDevices[device.id] = device;
        });
      }
    });
  }

  void _listenToConnectionStates() {
    _connectionStateSubscription = _unifiedService.connectionStates.listen((states) {
      if (mounted) {
        setState(() => _connectionStates = states);
      }
    });
  }

  Future<void> _loadSavedDevices() async {
    final devices = await _unifiedService.getSavedDevices();
    if (mounted) {
      setState(() => _savedDevices = devices);
    }
  }

  Future<void> _startScan() async {
    // STEP 1: Check and request permissions FIRST before doing anything
    // Use PermissionManager which shows proper explanation dialogs
    AppLogger.info('Checking Bluetooth permissions...');
    
    final hasPermissions = await PermissionManager.instance.requestBluetoothPermissions(context);
    
    if (!hasPermissions) {
      AppLogger.error('Bluetooth permissions denied by user');
      
      if (mounted) {
        AppLogger.showToast('Bluetooth permissions are required to scan', isError: true);
      }
      return;
    }
    
    AppLogger.success('Bluetooth permissions verified');
    
    // STEP 2: Check if Bluetooth is enabled (AFTER permissions are granted)
    final bluetoothManager = BluetoothDeviceManager.instance;
    final isEnabled = await bluetoothManager.isBluetoothEnabled();
    
    if (!isEnabled) {
      // Show dialog to enable Bluetooth
      if (!mounted) return;
      
      final userChoice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bluetooth_disabled, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Bluetooth is Off'),
            ],
          ),
          content: const Text(
            'Bluetooth is currently disabled.\n\n'
            'Would you like to enable it now to scan for devices?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.bluetooth),
              label: const Text('Enable Bluetooth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
      
      if (userChoice != true) {
        AppLogger.info('User cancelled Bluetooth enable request');
        return;
      }
      
      // Request to enable Bluetooth
      AppLogger.info('Requesting to enable Bluetooth...');
      final enabled = await bluetoothManager.requestEnableBluetooth();
      
      if (!enabled) {
        if (mounted) {
          AppLogger.showToast('Please enable Bluetooth to scan for devices', isError: true);
        }
        return;
      }
      
      // Small delay to let Bluetooth stabilize
      await Future.delayed(const Duration(milliseconds: 500));
      AppLogger.success('Bluetooth enabled, starting scan...');
    }
    
    // STEP 3: Start scanning (permissions granted + Bluetooth enabled)
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    try {
      await _unifiedService.startUnifiedScan(timeout: const Duration(seconds: 15));
      
      // Update scanning state after timeout
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted) {
          setState(() => _isScanning = false);
        }
      });
    } catch (e) {
      AppLogger.error('Scan failed: $e');
      if (mounted) {
        setState(() => _isScanning = false);
        AppLogger.showToast('Scan failed: $e', isError: true);
      }
    }
  }

  void _stopScan() {
    _unifiedService.stopUnifiedScan();
    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _showConnectionDialog(UnifiedBluetoothDevice device) async {
    final connectionInfo = _connectionStates[device.id];
    final isConnected = connectionInfo?.isConnected ?? false;
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(device.typeBadge, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                device.displayName,
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${device.typeLabel}'),
            const SizedBox(height: 4),
            Text('ID: ${device.id}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text('RSSI: ${device.rssi} dBm'),
            if (isConnected)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text('Connected', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              if (isConnected) {
                await _disconnectDevice(device);
              } else {
                await _connectDevice(device);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(isConnected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectDevice(UnifiedBluetoothDevice device) async {
    try {
      final success = await _unifiedService.connectToDevice(device);
      
      if (mounted) {
        if (success) {
          AppLogger.showToast('✓ Connected to ${device.displayName}');
          await _loadSavedDevices();
          
          // Switch to Paired Devices tab
          _tabController.animateTo(1);
        } else {
          AppLogger.showToast('✗ Connection failed', isError: true);
        }
      }
    } catch (e) {
      AppLogger.error('Connection error: $e');
      if (mounted) {
        AppLogger.showToast('Connection error: $e', isError: true);
      }
    }
  }

  Future<void> _disconnectDevice(UnifiedBluetoothDevice device) async {
    await _unifiedService.disconnectDevice(device.id);
    await _loadSavedDevices();
    if (mounted) {
      AppLogger.showToast('Disconnected from ${device.displayName}');
    }
  }

  Future<void> _deleteDevice(UnifiedBluetoothDevice device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Remove ${device.displayName} from saved devices?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _unifiedService.deleteSavedDevice(device.id);
      await _loadSavedDevices();
      if (mounted) {
        AppLogger.showToast('Device deleted');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: context.dimensions.appBarHeight,
        backgroundColor: Colors.blue,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: TabBar(
            controller: _tabController,
            labelPadding: const EdgeInsets.symmetric(vertical: 8),
            tabs: const [
              Tab(icon: Icon(Icons.search, size: 20), text: 'Scanner', height: 48),
              Tab(icon: Icon(Icons.devices, size: 20), text: 'Paired Devices', height: 48),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScannerTab(),
          _buildPairedDevicesTab(),
        ],
      ),
    );
  }

  Widget _buildScannerTab() {
    return Column(
      children: [
        // Scan controls
        Container(
          padding: const EdgeInsets.all(5),
          color: Colors.green.withValues(alpha: 0.1),
          child: Row(
            children: [
              const Icon(Icons.bluetooth_searching, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Scan for Devices',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isScanning ? _stopScan : _startScan,
                icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScanning ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // Device list
        Expanded(
          child: _isScanning && _discoveredDevices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Scanning for Bluetooth devices...',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '🔵 Classic + 🟢 BLE',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : _discoveredDevices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No devices found',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Start Scan" to discover devices',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      primary: false, // Don't use PrimaryScrollController
                      itemCount: _discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = _discoveredDevices.values.elementAt(index);
                        return _buildScannerDeviceTile(device);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPairedDevicesTab() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(5),
          color: Colors.blue.withValues(alpha: 0.1),
          child: Row(
            children: [
              const Icon(Icons.devices, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Paired Devices (${_savedDevices.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadSavedDevices,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        
        // Device list
        Expanded(
          child: _savedDevices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No paired devices',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connect to devices from Scanner tab',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  primary: false, // Don't use PrimaryScrollController
                  itemCount: _savedDevices.length,
                  itemBuilder: (context, index) {
                    final device = _savedDevices[index];
                    return _buildPairedDeviceTile(device);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScannerDeviceTile(UnifiedBluetoothDevice device) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Type badge
            Text(
              device.typeBadge,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.bluetooth_searching,
              color: device.isClassic ? Colors.blue : Colors.green,
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Type label chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: device.isClassic ? Colors.blue.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                device.typeLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: device.isClassic ? Colors.blue[800] : Colors.green[800],
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${device.id}\nRSSI: ${device.rssi} dBm',
          style: const TextStyle(fontSize: 12),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        onTap: () => _showConnectionDialog(device),
      ),
    );
  }

  Widget _buildPairedDeviceTile(UnifiedBluetoothDevice device) {
    final connectionInfo = _connectionStates[device.id];
    final isConnected = connectionInfo?.isConnected ?? false;
    
    // Determine dot color based on device type and connection status
    Color dotColor;
    if (isConnected) {
      // Connected: Green for BLE, Blue for Classic
      dotColor = device.isClassic ? Colors.blue : Colors.green;
    } else {
      // Disconnected: Red for both
      dotColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Type label chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: device.isClassic ? Colors.blue.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                device.typeLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: device.isClassic ? Colors.blue[800] : Colors.green[800],
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.id,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: dotColor,
                ),
                const SizedBox(width: 4),
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: dotColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_forever, color: Colors.red),
          onPressed: () => _deleteDevice(device),
          tooltip: 'Delete',
        ),
        onTap: () => _showConnectionDialog(device),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _discoverySubscription?.cancel();
    _connectionStateSubscription?.cancel();
    // Stop scan without setState since widget is being disposed
    _unifiedService.stopUnifiedScan();
    super.dispose();
  }
}
