import 'dart:typed_data';

import 'package:fitness_tracker/features/voice/data/services/wav_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String tagAt(Uint8List b, int offset) =>
      String.fromCharCodes(b.sublist(offset, offset + 4));

  int u32(Uint8List b, int offset) =>
      ByteData.sublistView(b).getUint32(offset, Endian.little);

  Uint8List pcm(int n) =>
      Uint8List.fromList(List<int>.generate(n, (i) => i % 256));

  group('buildWav', () {
    test('emits a 44-byte header in front of the PCM body', () {
      final body = pcm(20);
      final wav = buildWav(body, sampleRate: 16000);
      expect(wav.length, 44 + 20);
      expect(tagAt(wav, 0), 'RIFF');
      expect(tagAt(wav, 8), 'WAVE');
      expect(tagAt(wav, 12), 'fmt ');
      expect(tagAt(wav, 36), 'data');
    });

    test('writes the correct sizes, sample rate, and PCM format fields', () {
      final body = pcm(100);
      final wav = buildWav(body, sampleRate: 16000);
      expect(u32(wav, 4), 36 + 100); // RIFF chunk size
      expect(u32(wav, 16), 16); // fmt chunk size (PCM)
      expect(u32(wav, 24), 16000); // sample rate
      expect(u32(wav, 40), 100); // data chunk size
      final view = ByteData.sublistView(wav);
      expect(view.getUint16(20, Endian.little), 1); // audioFormat = PCM
      expect(view.getUint16(22, Endian.little), 1); // numChannels
      expect(view.getUint16(34, Endian.little), 16); // bitsPerSample
      expect(u32(wav, 28), 16000 * 2); // byteRate = rate * channels * bytes
    });
  });

  group('wavPcmBody', () {
    test('round-trips the body written by buildWav', () {
      final body = pcm(64);
      expect(wavPcmBody(buildWav(body, sampleRate: 16000)), body);
    });

    test('skips an extra LIST chunk before data', () {
      // Hand-craft: RIFF/WAVE, a fmt chunk, a LIST chunk, then data.
      final body = pcm(8);
      final builder = BytesBuilder();
      void ascii(String s) => builder.add(s.codeUnits);
      void u32le(int v) {
        final d = ByteData(4)..setUint32(0, v, Endian.little);
        builder.add(d.buffer.asUint8List());
      }

      ascii('RIFF');
      u32le(0); // size — not validated by the reader
      ascii('WAVE');
      ascii('fmt ');
      u32le(16);
      builder.add(Uint8List(16));
      ascii('LIST');
      u32le(4);
      builder.add(Uint8List(4));
      ascii('data');
      u32le(body.length);
      builder.add(body);

      expect(wavPcmBody(builder.toBytes()), body);
    });

    test(
      'returns the input unchanged when it is not a RIFF/WAVE container',
      () {
        final raw = pcm(50);
        expect(wavPcmBody(raw), raw);
      },
    );
  });

  group('spliceWav', () {
    test('prepends raw pre-roll PCM in front of the live WAV body', () {
      final pre = pcm(30);
      final liveBody = pcm(40);
      final liveWav = buildWav(liveBody, sampleRate: 16000);

      final spliced = spliceWav(pre, liveWav, sampleRate: 16000);

      expect(spliced.length, 44 + 30 + 40);
      expect(u32(spliced, 40), 70); // data chunk size = pre + live body
      // The spliced body must be pre-roll followed by the live body.
      final out = wavPcmBody(spliced);
      expect(out.sublist(0, 30), pre);
      expect(out.sublist(30), liveBody);
    });
  });
}
