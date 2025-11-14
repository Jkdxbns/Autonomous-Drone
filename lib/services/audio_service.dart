import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_logger.dart';

/// Service for audio recording and management
class AudioService {
  static AudioService? _instance;
  final AudioRecorder _recorder = AudioRecorder();
  
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  AudioService._();

  static AudioService get instance {
    _instance ??= AudioService._();
    return _instance!;
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Get recordings directory path
  Future<String> getRecordingsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(path.join(appDir.path, 'data_audio'));
    
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
      AppLogger.info('Created data_audio directory: ${recordingsDir.path}');
    }
    
    return recordingsDir.path;
  }

  /// Start audio recording
  /// Returns true if recording started successfully
  Future<bool> startRecording() async {
    try {
      // Check permission
      final hasPermission = await this.hasPermission();
      if (!hasPermission) {
        final granted = await requestPermission();
        if (!granted) {
          AppLogger.error('Microphone permission denied');
          return false;
        }
      }

      // Generate file path
      final recordingsDir = await getRecordingsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'recording_$timestamp.wav';
      final filePath = path.join(recordingsDir, fileName);

      // Start recording with WAV format, 16kHz (Whisper standard), mono
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000, // Whisper standard sample rate
          numChannels: 1,
          bitRate: 128000,
        ),
        path: filePath,
      );

      _currentRecordingPath = filePath;
      _recordingStartTime = DateTime.now();
      
      AppLogger.info('Recording started: $fileName (16kHz, WAV, mono)');
      AppLogger.debug('Save path: $filePath');
      return true;
    } catch (e) {
      AppLogger.error('Error starting recording: $e');
      return false;
    }
  }

  /// Stop audio recording
  /// Returns the file path of the recorded audio, or null if failed
  Future<String?> stopRecording() async {
    try {
      final recordingPath = await _recorder.stop();
      
      if (recordingPath == null || _currentRecordingPath == null) {
        AppLogger.error('No recording to stop');
        return null;
      }

      final file = File(_currentRecordingPath!);
      if (!await file.exists()) {
        AppLogger.error('Recording file not found: $_currentRecordingPath');
        return null;
      }

      final fileSize = await file.length();
      final duration = _recordingStartTime != null 
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds 
          : null;
      
      AppLogger.success('Recording stopped');
      AppLogger.debug('Path: $_currentRecordingPath');
      AppLogger.debug('Size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      if (duration != null) {
        AppLogger.debug('Duration: ${(duration / 1000).toStringAsFixed(2)}s');
      }

      final savedPath = _currentRecordingPath;
      _currentRecordingPath = null;
      _recordingStartTime = null;

      return savedPath;
    } catch (e) {
      AppLogger.error('Error stopping recording: $e');
      _currentRecordingPath = null;
      _recordingStartTime = null;
      return null;
    }
  }

  /// Cancel current recording without saving
  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          AppLogger.info('Recording cancelled and deleted');
        }
      }
      
      _currentRecordingPath = null;
      _recordingStartTime = null;
    } catch (e) {
      AppLogger.error('Error cancelling recording: $e');
    }
  }

  /// Check if currently recording
  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  /// Get all saved recordings from the data_audio directory
  Future<List<Map<String, dynamic>>> getAllRecordings() async {
    try {
      final recordingsDir = await getRecordingsDirectory();
      final dir = Directory(recordingsDir);
      
      if (!await dir.exists()) {
        return [];
      }
      
      final files = await dir.list().where((entity) => entity is File && entity.path.endsWith('.wav')).toList();
      
      final recordings = <Map<String, dynamic>>[];
      for (final file in files) {
        final fileStat = await (file as File).stat();
        recordings.add({
          'filePath': file.path,
          'fileName': path.basename(file.path),
          'fileSize': fileStat.size,
          'timestamp': fileStat.modified.toIso8601String(),
        });
      }
      
      return recordings;
    } catch (e) {
      AppLogger.error('Error getting recordings: $e');
      return [];
    }
  }

  /// Delete a recording file
  Future<bool> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        AppLogger.info('Recording deleted: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Error deleting recording: $e');
      return false;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
