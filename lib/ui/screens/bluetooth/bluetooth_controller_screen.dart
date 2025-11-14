import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/unified_bluetooth_device.dart';
import '../../../services/bluetooth/unified_bluetooth_service.dart';
import '../../../utils/app_logger.dart';

// Types for dynamic widget system
enum _WidgetType { slider, button, joystick }

class _DynamicWidget {
  _DynamicWidget({
    required this.id,
    required this.type,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.rotation = 0.0,
    this.label = '',
    this.joystickLabels,
    this.sliderMin = 0.0,
    this.sliderMax = 100.0,
    this.sliderDivisions = 10,
  }) : sliderValue = 0.0; // Initialize to 0

  final int id;
  final _WidgetType type;
  double left;
  double top;

  // NEW: size for each widget
  double width;
  double height;

  double rotation;
  String label; // Value/label to display on widget (for slider/button)
  Map<String, String>? joystickLabels; // Labels for joystick: up, down, left, right
  
  // Slider configuration
  double sliderMin;
  double sliderMax;
  int sliderDivisions;
  double sliderValue; // Current slider value

  void resetToZero() {
    if (type == _WidgetType.slider) {
      sliderValue = 0.0;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'left': left,
      'top': top,
      'width': width,
      'height': height,
      'rotation': rotation,
      'label': label,
      'joystickLabels': joystickLabels,
      'sliderMin': sliderMin,
      'sliderMax': sliderMax,
      'sliderDivisions': sliderDivisions,
      'sliderValue': sliderValue,
    };
  }

  static _DynamicWidget fromJson(Map<String, dynamic> json) {
    return _DynamicWidget(
      id: json['id'] as int,
      type: _WidgetType.values[json['type'] as int],
      left: json['left'] as double,
      top: json['top'] as double,
      width: json['width'] as double,
      height: json['height'] as double,
      rotation: json['rotation'] as double,
      label: json['label'] as String,
      joystickLabels: json['joystickLabels'] != null
          ? Map<String, String>.from(json['joystickLabels'] as Map)
          : null,
      sliderMin: json['sliderMin'] as double,
      sliderMax: json['sliderMax'] as double,
      sliderDivisions: json['sliderDivisions'] as int,
    )..sliderValue = json['sliderValue'] as double;
  }
}

class BluetoothControllerScreen extends StatefulWidget {
  const BluetoothControllerScreen({super.key});

  @override
  State<BluetoothControllerScreen> createState() =>
      _BluetoothControllerScreenState();
}

class _BluetoothControllerScreenState extends State<BluetoothControllerScreen> {
  final _unifiedService = UnifiedBluetoothService.instance;

  List<UnifiedBluetoothDevice> _savedDevices = [];
  Map<String, UnifiedConnectionInfo> _connectionStates = {};
  UnifiedBluetoothDevice? _selectedDevice;

  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _dataSubscription;

  // Edit mode toggle - when true widgets are movable/resizable
  bool _editMode = false;

  // Dynamic widgets placed on the canvas
  int _nextWidgetId = 1;
  final List<_DynamicWidget> _dynamicWidgets = [];
  _DynamicWidget? _selectedWidget;

  // Canvas size captured via LayoutBuilder
  Size? _canvasSize;

  // Track initial rotation & size for multi-touch gestures
  double _baseRotation = 0.0;
  double _initialWidth = 0.0;
  double _initialHeight = 0.0;

  static const double _minWidgetSize = 50.0;

  // Mini terminal for incoming data
  final List<String> _receivedData = [];
  final ScrollController _terminalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadSavedDevices();
    _loadSavedWidgets();
    _listenToConnectionStates();
    _listenToIncomingData();
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _dataSubscription?.cancel();
    _terminalScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      await _unifiedService.initialize();
    } catch (e) {
      AppLogger.error('Failed to initialize: $e');
    }
  }

  Future<void> _loadSavedDevices() async {
    final devices = await _unifiedService.getSavedDevices();
    if (mounted) {
      setState(() {
        _savedDevices = devices;

        // Auto-select first connected device if none selected
        if (_selectedDevice == null) {
          final connectedDevices = devices
              .where((d) => _connectionStates[d.id]?.isConnected ?? false)
              .toList();
          if (connectedDevices.isNotEmpty) {
            _selectedDevice = connectedDevices.first;
          }
        }
      });
    }
  }

  Future<void> _saveWidgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final widgetsJson = _dynamicWidgets.map((w) => w.toJson()).toList();
      final jsonString = jsonEncode(widgetsJson);
      await prefs.setString('controller_widgets', jsonString);
      
      // Update next widget ID to avoid conflicts
      if (_dynamicWidgets.isNotEmpty) {
        final maxId = _dynamicWidgets.map((w) => w.id).reduce((a, b) => a > b ? a : b);
        _nextWidgetId = maxId + 1;
        await prefs.setInt('controller_next_widget_id', _nextWidgetId);
      }
      
      AppLogger.success('Widgets saved successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Layout saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to save widgets: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save layout: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadSavedWidgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('controller_widgets');
      
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> widgetsJson = jsonDecode(jsonString) as List<dynamic>;
        final widgets = widgetsJson
            .map((json) => _DynamicWidget.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // Restore next widget ID
        final savedNextId = prefs.getInt('controller_next_widget_id');
        if (savedNextId != null) {
          _nextWidgetId = savedNextId;
        }
        
        if (mounted) {
          setState(() {
            _dynamicWidgets.clear();
            _dynamicWidgets.addAll(widgets);
          });
          AppLogger.info('Loaded ${widgets.length} saved widgets');
        }
      }
    } catch (e) {
      AppLogger.error('Failed to load widgets: $e');
    }
  }

  void _listenToConnectionStates() {
    _connectionStateSubscription = _unifiedService.connectionStates.listen((
      states,
    ) {
      if (mounted) {
        setState(() {
          _connectionStates = states;

          // Auto-select first connected device if none selected
          if (_selectedDevice == null ||
              !states.containsKey(_selectedDevice!.id) ||
              !_connectionStates[_selectedDevice!.id]!.isConnected) {
            final connectedDevices = _savedDevices
                .where((d) => states[d.id]?.isConnected ?? false)
                .toList();
            if (connectedDevices.isNotEmpty) {
              _selectedDevice = connectedDevices.first;
            } else {
              _selectedDevice = null;
            }
          }
        });
      }
    });
  }

  void _listenToIncomingData() {
    _dataSubscription = _unifiedService.dataReceivedStream.listen((event) {
      if (mounted && _selectedDevice != null && event.deviceId == _selectedDevice!.id) {
        setState(() {
          final message = '${_selectedDevice!.displayName}: ${event.data}';
          _receivedData.add(message);
          // Keep only last 50 messages
          if (_receivedData.length > 50) {
            _receivedData.removeAt(0);
          }
        });
        // Auto-scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_terminalScrollController.hasClients) {
            _terminalScrollController.animateTo(
              _terminalScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectedDevices = _savedDevices
        .where((d) => _connectionStates[d.id]?.isConnected ?? false)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Device selector dropdown
        _buildDeviceSelector(connectedDevices),

        // Edit UI link and Delete button
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _editMode = !_editMode;
                    if (!_editMode) {
                      _selectedWidget = null; // Deselect when exiting edit mode
                    }
                  });
                },
                style: ButtonStyle(
                  padding: MaterialStateProperty.all(EdgeInsets.zero),
                  minimumSize: MaterialStateProperty.all(const Size(0, 0)),
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                  splashFactory: NoSplash.splashFactory,
                ),
                child: Text(
                  _editMode ? 'Edit UI (On)' : 'Edit UI (Off)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () async {
                  await _loadSavedDevices();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Device list refreshed'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
                style: ButtonStyle(
                  padding: MaterialStateProperty.all(EdgeInsets.zero),
                  minimumSize: MaterialStateProperty.all(const Size(0, 0)),
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                  splashFactory: NoSplash.splashFactory,
                ),
                icon: const Icon(Icons.refresh, size: 16, color: Colors.blue),
                label: const Text(
                  'Refresh',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: _saveWidgets,
                style: ButtonStyle(
                  padding: MaterialStateProperty.all(EdgeInsets.zero),
                  minimumSize: MaterialStateProperty.all(const Size(0, 0)),
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                  splashFactory: NoSplash.splashFactory,
                ),
                icon: const Icon(Icons.save, size: 16, color: Colors.green),
                label: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const Spacer(),
              if (_editMode && _selectedWidget != null) ...[
                TextButton(
                  onPressed: () => _showSetValueDialog(_selectedWidget!),
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(EdgeInsets.zero),
                    minimumSize: MaterialStateProperty.all(const Size(0, 0)),
                    overlayColor: MaterialStateProperty.all(Colors.transparent),
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: Text(
                    'Set Value',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _dynamicWidgets.removeWhere(
                        (el) => el.id == _selectedWidget!.id,
                      );
                      _selectedWidget = null;
                    });
                  },
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(EdgeInsets.zero),
                    minimumSize: MaterialStateProperty.all(const Size(0, 0)),
                    overlayColor: MaterialStateProperty.all(Colors.transparent),
                    splashFactory: NoSplash.splashFactory,
                  ),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  label: const Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Main content area (canvas for dynamic widgets)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Global gesture detector for manipulating selected widget
                onTapUp: (details) {
                  if (!_editMode) return;
                  // Simple tap cycles through widgets or deselects
                  setState(() {
                    if (_dynamicWidgets.isEmpty) {
                      _selectedWidget = null;
                    } else if (_selectedWidget == null) {
                      _selectedWidget = _dynamicWidgets.first;
                    } else {
                      final currentIndex = _dynamicWidgets.indexOf(
                        _selectedWidget!,
                      );
                      if (currentIndex == _dynamicWidgets.length - 1) {
                        _selectedWidget = null; // Deselect after last widget
                      } else {
                        _selectedWidget = _dynamicWidgets[currentIndex + 1];
                      }
                    }
                  });
                },
                onScaleStart: (details) {
                  if (!_editMode || _selectedWidget == null) return;
                  _baseRotation = _selectedWidget!.rotation;
                  _initialWidth = _selectedWidget!.width;
                  _initialHeight = _selectedWidget!.height;
                },
                onScaleUpdate: (details) {
                  if (!_editMode || _selectedWidget == null) return;

                  setState(() {
                    final w = _selectedWidget!;

                    // Multi-touch: scale + rotate
                    if (details.pointerCount > 1) {
                      // Resize
                      final maxWidth = _canvasSize?.width ?? double.infinity;
                      final maxHeight = _canvasSize?.height ?? double.infinity;

                      double newWidth = _initialWidth * details.scale;
                      double newHeight = _initialHeight * details.scale;

                      newWidth =
                          newWidth.clamp(_minWidgetSize, maxWidth) as double;
                      newHeight =
                          newHeight.clamp(_minWidgetSize, maxHeight) as double;

                      w.width = newWidth;
                      w.height = newHeight;

                      // Rotate
                      w.rotation = _baseRotation + details.rotation;

                      // Keep inside canvas after resize
                      if (_canvasSize != null) {
                        w.left =
                            w.left.clamp(0.0, _canvasSize!.width - w.width)
                                as double;
                        w.top =
                            w.top.clamp(0.0, _canvasSize!.height - w.height)
                                as double;
                      }
                    } else {
                      // Single finger: move widget
                      w.left += details.focalPointDelta.dx;
                      w.top += details.focalPointDelta.dy;

                      if (_canvasSize != null) {
                        w.left =
                            w.left.clamp(0.0, _canvasSize!.width - w.width)
                                as double;
                        w.top =
                            w.top.clamp(0.0, _canvasSize!.height - w.height)
                                as double;
                      }
                    }
                  });
                },
                child: ClipRect(
                  child: Stack(
                    children: [
                      // E-Stop button - always on top left
                      Positioned(
                        left: 10,
                        top: 10,
                        child: ElevatedButton(
                          onPressed: () {
                            // Reset all sliders to 0
                            setState(() {
                              for (var widget in _dynamicWidgets) {
                                widget.resetToZero();
                              }
                            });
                            // Send e-stop command
                            _sendToDevice('e-stop');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'E-STOP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Dynamic widgets
                      ..._dynamicWidgets.map((w) {
                        return Positioned(
                          left: w.left,
                          top: w.top,
                          // NEW: use width & height from model
                          width: w.width,
                          height: w.height,
                          child: _buildDynamicWidget(w),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Mini terminal at the bottom
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black87,
            border: Border(
              top: BorderSide(color: Colors.grey[700]!, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Terminal header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.grey[900],
                child: Row(
                  children: [
                    Icon(Icons.terminal, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      'Incoming Data',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (_receivedData.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _receivedData.clear();
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Terminal content
              Expanded(
                child: _receivedData.isEmpty
                    ? Center(
                        child: Text(
                          'No data received yet...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _terminalScrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        itemCount: _receivedData.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              _receivedData[index],
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.greenAccent,
                                fontFamily: 'Courier',
                                fontFamilyFallback: ['monospace'],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Default sizes per widget type
  Size _defaultSizeForType(_WidgetType type) {
    switch (type) {
      case _WidgetType.slider:
        return const Size(250, 60);
      case _WidgetType.button:
        return const Size(100, 100);
      case _WidgetType.joystick:
        return const Size(120, 120);
    }
  }

  void _addWidget(_WidgetType type) {
    final canvas = _canvasSize;
    final defaultSize = _defaultSizeForType(type);

    double left = 20;
    double top = 20;
    if (canvas != null) {
      left = (canvas.width - defaultSize.width) / 2;
      top = (canvas.height - defaultSize.height) / 2;
    }

    final widget = _DynamicWidget(
      id: _nextWidgetId++,
      type: type,
      left: left,
      top: top,
      width: defaultSize.width,
      height: defaultSize.height,
      rotation: 0.0,
    );

    setState(() {
      _dynamicWidgets.add(widget);
      _selectedWidget = widget;
    });
  }

  /// Send data to the selected Bluetooth device
  Future<void> _sendToDevice(String data) async {
    if (_selectedDevice == null) {
      AppLogger.debug('No device selected for sending data');
      return;
    }

    // Check actual connection state from _connectionStates map
    final connectionInfo = _connectionStates[_selectedDevice!.id];
    if (connectionInfo == null || !connectionInfo.isConnected) {
      AppLogger.debug('Device ${_selectedDevice!.displayName} is not connected');
      return;
    }

    try {
      // Add newline character based on device type/config if needed
      final dataToSend = data.endsWith('\n') ? data : '$data\n';
      
      final success = await _unifiedService.sendData(_selectedDevice!.id, dataToSend);
      
      if (success) {
        AppLogger.debug('Sent to ${_selectedDevice!.displayName}: $data');
      } else {
        AppLogger.debug('Failed to send to ${_selectedDevice!.displayName}: $data');
      }
    } catch (e) {
      AppLogger.debug('Error sending data: $e');
    }
  }

  void _showSetValueDialog(_DynamicWidget widget) {
    if (widget.type == _WidgetType.joystick) {
      // Joystick needs 4 separate text fields
      final upController = TextEditingController(text: widget.joystickLabels?['up'] ?? '');
      final downController = TextEditingController(text: widget.joystickLabels?['down'] ?? '');
      final leftController = TextEditingController(text: widget.joystickLabels?['left'] ?? '');
      final rightController = TextEditingController(text: widget.joystickLabels?['right'] ?? '');
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Set Joystick Values'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: upController,
                decoration: const InputDecoration(labelText: 'Up'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: downController,
                decoration: const InputDecoration(labelText: 'Down'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: leftController,
                decoration: const InputDecoration(labelText: 'Left'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rightController,
                decoration: const InputDecoration(labelText: 'Right'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.joystickLabels = {
                    'up': upController.text,
                    'down': downController.text,
                    'left': leftController.text,
                    'right': rightController.text,
                  };
                });
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else if (widget.type == _WidgetType.slider) {
      // Slider needs label, min, max, and divisions
      final labelController = TextEditingController(text: widget.label);
      final minController = TextEditingController(text: widget.sliderMin.toString());
      final maxController = TextEditingController(text: widget.sliderMax.toString());
      final divisionsController = TextEditingController(text: widget.sliderDivisions.toString());
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Set Slider Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'e.g., Speed, Volume',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: minController,
                decoration: const InputDecoration(labelText: 'Lower Limit'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: maxController,
                decoration: const InputDecoration(labelText: 'Upper Limit'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: divisionsController,
                decoration: const InputDecoration(labelText: 'Divisions'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.label = labelController.text;
                  widget.sliderMin = double.tryParse(minController.text) ?? 0.0;
                  widget.sliderMax = double.tryParse(maxController.text) ?? 100.0;
                  widget.sliderDivisions = int.tryParse(divisionsController.text) ?? 10;
                });
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      // Button uses single text field
      final TextEditingController controller = TextEditingController(text: widget.label);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Set Value for ${widget.type.toString().split('.').last}'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Enter value',
              hintText: 'e.g., LED, Motor, Speed',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.label = controller.text;
                });
                Navigator.pop(context);
              },
              child: const Text('Set'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDynamicWidget(_DynamicWidget w) {
    final bool isSelected =
        _editMode && _selectedWidget != null && _selectedWidget!.id == w.id;

    Widget content = _innerForType(w);

    // Visual selection feedback: yellow border + icon when selected in edit mode
    Widget decorated = Stack(
      children: [
        // Border layer
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: isSelected
                ? BoxDecoration(
                    border: Border.all(color: Colors.yellow, width: 3),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
          ),
        ),
        // Actual content with small padding so border is visible
        Positioned.fill(
          child: Padding(
            padding: isSelected ? const EdgeInsets.all(3.0) : EdgeInsets.zero,
            child: content,
          ),
        ),
        if (isSelected)
          const Positioned(
            top: 4,
            right: 4,
            child: Icon(Icons.open_with, size: 16, color: Colors.yellow),
          ),
      ],
    );

    return Transform.rotate(
      angle: w.rotation,
      alignment: Alignment.center,
      child: decorated,
    );
  }

  // Now takes the dynamic widget (so we can use width/height)
  Widget _innerForType(_DynamicWidget w) {
    switch (w.type) {
      case _WidgetType.slider:
        return SizedBox(
          width: w.width,
          height: w.height,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (w.label.isNotEmpty)
                Text(
                  w.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 4.0,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.0),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 0.0),
                  ),
                  child: Slider(
                    value: w.sliderValue,
                    min: w.sliderMin,
                    max: w.sliderMax,
                    divisions: w.sliderDivisions,
                    label: w.sliderValue.toStringAsFixed(0),
                    onChanged: _editMode ? null : (newV) {
                      setState(() {
                        w.sliderValue = newV;
                      });
                      // Send slider value to device
                      final label = w.label.isNotEmpty ? w.label : 'slider';
                      _sendToDevice('$label:${newV.toStringAsFixed(0)}');
                    },
                  ),
                ),
              ),
              // Show current value below slider
              Text(
                '${w.sliderValue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        );

      case _WidgetType.button:
        return SizedBox(
          width: w.width,
          height: w.height,
          child: ElevatedButton(
            onPressed: _editMode ? null : () {
              // Send button label to device
              final label = w.label.isNotEmpty ? w.label : 'button';
              _sendToDevice(label);
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.zero,
              backgroundColor: Theme.of(context).colorScheme.primary,
              shadowColor: Colors.black26,
            ),
            child: w.label.isNotEmpty
                ? Text(
                    w.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  )
                : const SizedBox.expand(),
          ),
        );

      case _WidgetType.joystick:
        // Get labels from joystickLabels map
        final upLabel = w.joystickLabels?['up'] ?? '';
        final downLabel = w.joystickLabels?['down'] ?? '';
        final leftLabel = w.joystickLabels?['left'] ?? '';
        final rightLabel = w.joystickLabels?['right'] ?? '';
        
        // Outer box respects dynamic width/height; inner joystick scales
        final double buttonSize = 32.0;
        return Center(
          child: SizedBox(
            width: w.width,
            height: w.height,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 120,
                height: 120,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Up button with label
                    SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      child: ElevatedButton(
                        onPressed: _editMode ? null : () {
                          _sendToDevice(upLabel.isNotEmpty ? upLabel : 'up');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size(buttonSize, buttonSize),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                        child: upLabel.isNotEmpty
                            ? Text(
                                upLabel,
                                style: const TextStyle(fontSize: 8, color: Colors.white),
                                textAlign: TextAlign.center,
                              )
                            : const Icon(Icons.arrow_drop_up, size: 20),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Middle row: left, spacer, right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Left button
                        SizedBox(
                          width: buttonSize,
                          height: buttonSize,
                          child: ElevatedButton(
                            onPressed: _editMode ? null : () {
                              _sendToDevice(leftLabel.isNotEmpty ? leftLabel : 'left');
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(buttonSize, buttonSize),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                            child: leftLabel.isNotEmpty
                                ? Text(
                                    leftLabel,
                                    style: const TextStyle(fontSize: 8, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  )
                                : const Icon(Icons.arrow_left, size: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(width: buttonSize, height: buttonSize),
                        const SizedBox(width: 8),
                        // Right button
                        SizedBox(
                          width: buttonSize,
                          height: buttonSize,
                          child: ElevatedButton(
                            onPressed: _editMode ? null : () {
                              _sendToDevice(rightLabel.isNotEmpty ? rightLabel : 'right');
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(buttonSize, buttonSize),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                            child: rightLabel.isNotEmpty
                                ? Text(
                                    rightLabel,
                                    style: const TextStyle(fontSize: 8, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  )
                                : const Icon(Icons.arrow_right, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Down button with label
                    SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      child: ElevatedButton(
                        onPressed: _editMode ? null : () {
                          _sendToDevice(downLabel.isNotEmpty ? downLabel : 'down');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size(buttonSize, buttonSize),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                        child: downLabel.isNotEmpty
                            ? Text(
                                downLabel,
                                style: const TextStyle(fontSize: 8, color: Colors.white),
                                textAlign: TextAlign.center,
                              )
                            : const Icon(Icons.arrow_drop_down, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }

  Widget _buildDeviceSelector(List<UnifiedBluetoothDevice> connectedDevices) {
    // Validate selected device is still in the connected list
    if (_selectedDevice != null &&
        !connectedDevices.any((d) => d.id == _selectedDevice!.id)) {
      _selectedDevice = null; // Clear invalid selection
    }

    return Container(
      padding: const EdgeInsets.all(0.1),
      color: connectedDevices.isEmpty
          ? Colors.red.withOpacity(0.1)
          : Colors.blue.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                connectedDevices.isEmpty
                    ? Icons.bluetooth_disabled
                    : Icons.bluetooth_connected,
                color: connectedDevices.isEmpty ? Colors.red : Colors.blue,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Device:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedDevice?.id,
                  hint: Text(
                    connectedDevices.isEmpty ? 'No devices' : 'Select',
                    style: const TextStyle(fontSize: 13),
                  ),
                  items: connectedDevices.map((device) {
                    return DropdownMenuItem(
                      value: device.id,
                      child: Row(
                        children: [
                          Text(
                            device.typeBadge,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              device.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: connectedDevices.isEmpty
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _selectedDevice = connectedDevices.firstWhere(
                                (d) => d.id == value,
                              );
                            });
                          }
                        },
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_WidgetType>(
                tooltip: 'Add Widgets',
                onSelected: (value) => _addWidget(value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _WidgetType.slider,
                    child: Row(
                      children: [
                        Icon(Icons.tune),
                        SizedBox(width: 8),
                        Text('Slider'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: _WidgetType.button,
                    child: Row(
                      children: [
                        Icon(Icons.smart_button),
                        SizedBox(width: 8),
                        Text('Button'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: _WidgetType.joystick,
                    child: Row(
                      children: [
                        Icon(Icons.gamepad),
                        SizedBox(width: 8),
                        Text('Joystick'),
                      ],
                    ),
                  ),
                ],
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Widgets'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
