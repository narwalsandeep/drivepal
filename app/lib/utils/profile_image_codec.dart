import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Resize + JPEG-compress for storing in user JSON (keeps payload small).
String? compressProfilePhotoToJpegBase64(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return null;

  const maxSide = 512;
  img.Image resized = decoded;
  if (decoded.width > maxSide || decoded.height > maxSide) {
    if (decoded.width >= decoded.height) {
      resized = img.copyResize(decoded, width: maxSide);
    } else {
      resized = img.copyResize(decoded, height: maxSide);
    }
  }

  var quality = 82;
  List<int> jpg = img.encodeJpg(resized, quality: quality);
  while (jpg.length > 95000 && quality > 45) {
    quality -= 12;
    jpg = img.encodeJpg(resized, quality: quality);
  }

  return base64Encode(jpg);
}

/// Generic base64 encoder for original image bytes (keeps original format).
String encodeRawImageToBase64(Uint8List raw) {
  return base64Encode(raw);
}
