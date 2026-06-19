import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentFilePath;

  /// Requests microphone permission.
  /// Returns true if granted, false otherwise.
  Future<bool> checkAndRequestPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// Starts recording audio to a temporary file.
  Future<void> startRecording() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      final directory = await getTemporaryDirectory();
      _currentFilePath = '${directory.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // good balance of size/quality for speech
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentFilePath!,
      );
    } catch (e) {
      print('Error starting recording: $e');
      rethrow;
    }
  }

  /// Stops recording and returns the file path.
  Future<String?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      return path;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  /// Cancels the recording and deletes the temporary file.
  Future<void> cancelRecording() async {
    try {
      await _audioRecorder.stop();
      if (_currentFilePath != null) {
        final file = File(_currentFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _currentFilePath = null;
    } catch (e) {
      print('Error canceling recording: $e');
    }
  }

  /// Disposes the recorder.
  void dispose() {
    _audioRecorder.dispose();
  }
}
