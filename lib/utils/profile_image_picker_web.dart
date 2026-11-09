import 'package:image_picker/image_picker.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';

Future<XFile?> pickProfileImage() => ImagePickerPlugin().getImageFromSource(
  source: ImageSource.gallery,
);
