import 'package:web/web.dart' as web;

void clearSuccessfulAuthCallbackUrl() {
  final path = Uri.base.path;
  final authPathIndex = path.lastIndexOf('/auth/');
  if (authPathIndex < 0) return;

  final appPath = '${path.substring(0, authPathIndex)}/';
  web.window.history.replaceState(null, '', appPath);
}
