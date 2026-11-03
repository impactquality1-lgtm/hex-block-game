import 'dart:math' as math;
import 'dart:typed_data';

/// Build a short chime as a WAV file in memory: an ascending arpeggio of
/// sine notes, each with a quick attack and gentle fade. No asset file
/// is needed, so it works the same on macOS, iOS, Android and web.
Uint8List buildChimeWav(List<double> notes, {double noteSeconds = 0.14}) {
  const sampleRate = 22050;
  final samplesPerNote = (sampleRate * noteSeconds).round();
  final pcm = <int>[];
  for (var n = 0; n < notes.length; n++) {
    for (var i = 0; i < samplesPerNote; i++) {
      final t = i / sampleRate;
      final progress = i / samplesPerNote;
      final envelope = progress < 0.05 ? progress / 0.05 : 1.0 - 0.6 * ((progress - 0.05) / 0.95);
      final value = math.sin(2 * math.pi * notes[n] * t) * envelope * 0.5;
      final sample = (value * 32767).round().clamp(-32768, 32767);
      pcm.add(sample & 0xFF);
      pcm.add((sample >> 8) & 0xFF);
    }
  }
  final dataSize = pcm.length;
  final header = ByteData(44);
  void writeString(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
  writeString(0, 'RIFF');
  header.setUint32(4, 36 + dataSize, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  writeString(36, 'data');
  header.setUint32(40, dataSize, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
}
