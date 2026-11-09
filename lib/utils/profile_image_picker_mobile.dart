import 'package:image_picker/image_picker.dart';

Future<XFile?> pickProfileImage() => ImagePicker().pickImage(
  source: ImageSource.gallery,
  maxWidth: 1600,
  maxHeight: 1600,
);
