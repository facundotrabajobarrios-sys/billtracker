import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void downloadBackup(Uint8List bytes, String fileName) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/zip'),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = objectUrl
    ..download = fileName;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  unawaited(
    Future<void>.delayed(
      const Duration(minutes: 1),
      () => web.URL.revokeObjectURL(objectUrl),
    ),
  );
}
