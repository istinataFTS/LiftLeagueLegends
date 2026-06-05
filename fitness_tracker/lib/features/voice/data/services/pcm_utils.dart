import 'dart:typed_data';

import '../../../../domain/entities/voice_settings.dart' show WakeWordPreset;

/// Converts a little-endian PCM-16 byte buffer to a normalized Float32List.
///
/// Each 2-byte sample is divided by 32768.0 so values sit in [-1.0, 1.0].
/// Used to convert `record` package PCM16 frames to the float32 format
/// expected by the sherpa-onnx keyword spotter.
Float32List pcm16ToFloat32(Uint8List pcm16) {
  final sampleCount = pcm16.lengthInBytes ~/ 2;
  final out = Float32List(sampleCount);
  final byteData = ByteData.sublistView(pcm16);
  for (var i = 0; i < sampleCount; i++) {
    out[i] = byteData.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

/// Given the multi-line contents of `assets/wake_words/kws/keywords.txt`,
/// returns the single BPE-tokenized line for [preset].
///
/// The file has exactly three non-empty lines in order:
///   0 → samoLevski
///   1 → trainer
///   2 → thomas
///
/// Throws [ArgumentError] if the file has fewer than 3 non-empty lines.
String tokenizedLineForPreset(
  String keywordsFileContents,
  WakeWordPreset preset,
) {
  final lines = keywordsFileContents
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length < 3) {
    throw ArgumentError(
      'keywords.txt must have at least 3 non-empty lines, got ${lines.length}',
    );
  }
  return switch (preset) {
    WakeWordPreset.samoLevski => lines[0],
    WakeWordPreset.trainer => lines[1],
    WakeWordPreset.thomas => lines[2],
  };
}
