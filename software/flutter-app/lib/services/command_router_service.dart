import 'bluetooth/unified_bluetooth_service.dart';
import '../models/assistant_response.dart';
import '../utils/app_logger.dart';

/// Service to route commands from server to Bluetooth devices
class CommandRouterService {
  final UnifiedBluetoothService _bluetoothService = UnifiedBluetoothService.instance;

  /// Send command to target device based on assistant response
  Future<bool> routeCommand(AssistantResponse response) async {
    try {
      if (!response.isBtControl) {
        AppLogger.warning('Cannot route non-bt-control task: ${response.task}');
        return false;
      }

      if (response.hasError) {
        AppLogger.error('Assistant response has error: ${response.error!.message}');
        return false;
      }

      // Extract MAC address from target-device string
      final targetMac = _extractMacAddress(response.targetDevice);
      
      if (targetMac == null) {
        AppLogger.error('Could not extract MAC address from: ${response.targetDevice}');
        return false;
      }

      // Get command
      final command = response.output.generatedOutput;
      
      AppLogger.info('Routing command to device: $targetMac');
      AppLogger.info('Command: $command');

      // Check if command is an error
      if (command.startsWith('ERROR:')) {
        AppLogger.error('Command is an error: $command');
        return false;
      }

      // Send command to Bluetooth device
      return await sendToBluetoothDevice(targetMac, command);
    } catch (e) {
      AppLogger.error('Error routing command: $e');
      return false;
    }
  }

  /// Send command to Bluetooth device
  Future<bool> sendToBluetoothDevice(String mac, String command) async {
    try {
      // Get all devices to find the target
      final devices = await _bluetoothService.getSavedDevices();
      
      // Find device by MAC
      final targetDevice = devices.where((d) => d.id == mac).firstOrNull;
      
      if (targetDevice == null) {
        AppLogger.error('Device not found with MAC: $mac');
        return false;
      }

      // Check if device is connected
      if (!targetDevice.isConnected) {
        AppLogger.error('Device ${targetDevice.displayName} is not connected');
        return false;
      }

      AppLogger.info('Sending command to ${targetDevice.displayName}: $command');

      // Send data via Bluetooth
      // Add newline for Arduino Serial.readStringUntil('\n')
      final commandWithNewline = '$command\n';
      
      // Use unified sendData method (works for both Classic and BLE)
      final success = await _bluetoothService.sendData(mac, commandWithNewline);

      if (success) {
        AppLogger.success('Command sent successfully to ${targetDevice.displayName}');
      } else {
        AppLogger.error('Failed to send command to ${targetDevice.displayName}');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('Error sending to Bluetooth device: $e');
      return false;
    }
  }

  /// Extract MAC address from device string format: "device_name (MAC: XX:XX:XX:XX:XX:XX)"
  String? _extractMacAddress(String deviceString) {
    final regex = RegExp(r'MAC:\s*([A-F0-9:]{17})', caseSensitive: false);
    final match = regex.firstMatch(deviceString);
    return match?.group(1);
  }
}
