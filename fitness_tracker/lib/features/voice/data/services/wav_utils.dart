import 'dart:typed_data';

/// Pure helpers for framing 16-bit PCM audio as canonical WAV (RIFF) buffers
/// and splicing a raw-PCM pre-roll in front of a recorded WAV clip.
///
/// The wake-word engine emits **raw PCM16** (no header); the Whisper recorder
/// emits a **WAV** file. To upload one continuous clip the pre-roll PCM is
/// concatenated ahead of the live recording's PCM body and re-framed with a
/// fresh header. All functions are pure (no I/O, no platform deps) so they are
/// unit-testable without the `record` plugin or a device.

const int _headerSize = 44;
const int _bitsPerSample = 16;
const int _pcmFormat = 1;

void _writeAscii(ByteData view, int offset, String tag) {
  for (var i = 0; i < tag.length; i++) {
    view.setUint8(offset + i, tag.codeUnitAt(i));
  }
}

/// Builds a canonical 44-byte-header 16-bit PCM WAV buffer wrapping [pcm] at
/// [sampleRate] / [numChannels].
Uint8List buildWav(
  Uint8List pcm, {
  required int sampleRate,
  int numChannels = 1,
}) {
  final dataLen = pcm.lengthInBytes;
  final byteRate = sampleRate * numChannels * (_bitsPerSample ~/ 8);
  final blockAlign = numChannels * (_bitsPerSample ~/ 8);

  final out = Uint8List(_headerSize + dataLen);
  final view = ByteData.sublistView(out);

  _writeAscii(view, 0, 'RIFF');
  view.setUint32(4, 36 + dataLen, Endian.little); // chunk size
  _writeAscii(view, 8, 'WAVE');

  _writeAscii(view, 12, 'fmt ');
  view.setUint32(16, 16, Endian.little); // fmt chunk size (PCM)
  view.setUint16(20, _pcmFormat, Endian.little);
  view.setUint16(22, numChannels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, byteRate, Endian.little);
  view.setUint16(32, blockAlign, Endian.little);
  view.setUint16(34, _bitsPerSample, Endian.little);

  _writeAscii(view, 36, 'data');
  view.setUint32(40, dataLen, Endian.little);

  out.setAll(_headerSize, pcm);
  return out;
}

/// Returns the PCM `data`-chunk bytes from a WAV buffer.
///
/// Walks the RIFF chunk table rather than assuming a fixed 44-byte header, so
/// it tolerates a `record`-emitted buffer that carries extra `LIST`/`fact`
/// chunks before `data`. Falls back to the canonical 44-byte offset when the
/// buffer is not a recognisable RIFF/WAVE container (e.g. already-raw PCM).
Uint8List wavPcmBody(Uint8List wav) {
  // Too short to even hold a header → treat the whole buffer as PCM.
  if (wav.lengthInBytes < _headerSize) return wav;

  final view = ByteData.sublistView(wav);
  bool tagAt(int offset, String tag) {
    if (offset + tag.length > wav.lengthInBytes) return false;
    for (var i = 0; i < tag.length; i++) {
      if (view.getUint8(offset + i) != tag.codeUnitAt(i)) return false;
    }
    return true;
  }

  if (!tagAt(0, 'RIFF') || !tagAt(8, 'WAVE')) {
    // Not a WAV container — assume the caller handed us raw PCM.
    return wav;
  }

  // Chunk table starts after "RIFF" + size(4) + "WAVE" = offset 12.
  var offset = 12;
  while (offset + 8 <= wav.lengthInBytes) {
    final isData = tagAt(offset, 'data');
    final chunkSize = view.getUint32(offset + 4, Endian.little);
    final bodyStart = offset + 8;
    if (isData) {
      final end = bodyStart + chunkSize;
      final clampedEnd = end <= wav.lengthInBytes ? end : wav.lengthInBytes;
      return Uint8List.sublistView(wav, bodyStart, clampedEnd);
    }
    // Advance past this chunk; RIFF chunks are word-aligned (pad odd sizes).
    offset = bodyStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
  }

  // No data chunk found — fall back to the canonical header length.
  return Uint8List.sublistView(wav, _headerSize);
}

/// Splices a raw-PCM [preRollPcm] in front of a recorded [liveWav] clip and
/// returns a single WAV buffer at [sampleRate]. Both inputs must share the
/// sample rate and channel count (16 kHz mono in this app).
Uint8List spliceWav(
  Uint8List preRollPcm,
  Uint8List liveWav, {
  required int sampleRate,
  int numChannels = 1,
}) {
  final liveBody = wavPcmBody(liveWav);
  final combined = Uint8List(preRollPcm.lengthInBytes + liveBody.lengthInBytes)
    ..setAll(0, preRollPcm)
    ..setAll(preRollPcm.lengthInBytes, liveBody);
  return buildWav(combined, sampleRate: sampleRate, numChannels: numChannels);
}
