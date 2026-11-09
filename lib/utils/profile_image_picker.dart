import 'package:image_picker/image_picker.dart';

import 'profile_image_picker_mobile.dart'
    if (dart.library.js_interop) 'profile_image_picker_web.dart'
    as platform;

Future<XFile?> pickProfileImage() => platform.pickProfileImage();
