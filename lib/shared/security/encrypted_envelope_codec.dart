import 'dart:typed_data';

class EncryptedEnvelopeCodec {
  static const int _version1 = 1;

  static Uint8List encode(List<int> encryptedPayload) {
    final out = Uint8List(encryptedPayload.length + 1);
    out[0] = _version1;
    out.setRange(1, out.length, encryptedPayload);
    return out;
  }

  static Uint8List decode(Uint8List value) {
    if (value.isEmpty) {
      throw const FormatException('Encrypted envelope is empty.');
    }

    final version = value[0];
    if (version != _version1) {
      throw FormatException('Unsupported encrypted envelope version: $version');
    }

    if (value.length == 1) {
      throw const FormatException('Encrypted envelope payload is empty.');
    }

    return Uint8List.sublistView(value, 1);
  }
}
