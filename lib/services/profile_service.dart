import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarUpdateResult {
  const AvatarUpdateResult({
    required this.imageUrl,
    required this.previousImageRemoved,
  });

  final String? imageUrl;
  final bool previousImageRemoved;
}

class ProfileService {
  static const _bucket = 'avatars';
  static const _maxImageBytes = 5 * 1024 * 1024;

  SupabaseClient get _client => Supabase.instance.client;

  Future<AvatarUpdateResult> uploadAvatar(
    Uint8List bytes,
    String fileName,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Inicia sesión para cambiar tu foto.');
    if (bytes.isEmpty || bytes.length > _maxImageBytes) {
      throw const FormatException('La imagen debe pesar menos de 5 MB.');
    }

    final extension = fileName.split('.').last.toLowerCase();
    final detectedType = _detectImageType(bytes);
    final allowedExtensions = switch (detectedType) {
      'image/jpeg' => {'jpg', 'jpeg'},
      'image/png' => {'png'},
      'image/webp' => {'webp'},
      _ => <String>{},
    };
    if (!allowedExtensions.contains(extension)) {
      throw const FormatException(
        'Elige una imagen JPG, JPEG, PNG o WEBP válida.',
      );
    }

    final oldImageUrl = await _getCurrentAvatarUrl(userId);
    final objectPath =
        '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: detectedType,
            cacheControl: '3600',
          ),
        );

    final imageUrl = _client.storage.from(_bucket).getPublicUrl(objectPath);
    try {
      await _client
          .from('users')
          .update({'avatar_url': imageUrl})
          .eq('id', userId)
          .select('avatar_url')
          .single();
    } catch (error) {
      await _client.storage.from(_bucket).remove([objectPath]);
      rethrow;
    }

    final previousPath = _ownedObjectPath(oldImageUrl, userId);
    var previousImageRemoved = true;
    if (previousPath != null && previousPath != objectPath) {
      try {
        await _client.storage.from(_bucket).remove([previousPath]);
      } catch (error) {
        previousImageRemoved = false;
        debugPrint('No se pudo eliminar la foto de perfil anterior: $error');
      }
    }

    return AvatarUpdateResult(
      imageUrl: imageUrl,
      previousImageRemoved: previousImageRemoved,
    );
  }

  Future<AvatarUpdateResult> deleteAvatar() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Inicia sesión para cambiar tu foto.');

    final oldImageUrl = await _getCurrentAvatarUrl(userId);
    await _client
        .from('users')
        .update({'avatar_url': null})
        .eq('id', userId)
        .select('id')
        .single();

    var previousImageRemoved = true;
    final previousPath = _ownedObjectPath(oldImageUrl, userId);
    if (previousPath != null) {
      try {
        await _client.storage.from(_bucket).remove([previousPath]);
      } catch (error) {
        previousImageRemoved = false;
        debugPrint('No se pudo eliminar la foto de perfil: $error');
      }
    }

    return AvatarUpdateResult(
      imageUrl: null,
      previousImageRemoved: previousImageRemoved,
    );
  }

  Future<String?> _getCurrentAvatarUrl(String userId) async {
    final response = await _client
        .from('users')
        .select('avatar_url')
        .eq('id', userId)
        .single();
    return response['avatar_url'] as String?;
  }

  String? _ownedObjectPath(String? imageUrl, String userId) {
    if (imageUrl == null) return null;
    final uri = Uri.tryParse(imageUrl);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(_bucket);
    if (bucketIndex < 1 ||
        segments[bucketIndex - 1] != 'public' ||
        bucketIndex + 2 >= segments.length ||
        segments[bucketIndex + 1] != userId) {
      return null;
    }
    final objectSegments = segments.skip(bucketIndex + 1).toList();
    if (objectSegments.any(
      (segment) =>
          segment.isEmpty ||
          segment == '.' ||
          segment == '..' ||
          segment.contains('/'),
    )) {
      return null;
    }
    return objectSegments.join('/');
  }

  String _detectImageType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        listEquals(bytes.sublist(0, 8), const [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ])) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return '';
  }
}
