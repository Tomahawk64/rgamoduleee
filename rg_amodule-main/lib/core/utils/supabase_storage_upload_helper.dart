import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseStorageUploadHelper {
  SupabaseStorageUploadHelper._();

  static const String adminImagesBucket = 'special-pooja-images';
  static const String profileImagesBucket = 'profile-images';

  static Future<String> uploadImageWithFallback({
    required SupabaseClient client,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String folder,
    String primaryBucket = adminImagesBucket,
    List<String> fallbackBuckets = const [profileImagesBucket],
  }) async {
    final buckets = <String>{
      primaryBucket,
      ...fallbackBuckets,
    }.where((bucket) => bucket.trim().isNotEmpty).toList();

    if (buckets.isEmpty) {
      throw Exception('No storage buckets configured for image upload.');
    }

    final uid = client.auth.currentUser?.id;
    final extension = _fileExtension(fileName);
    final uniqueName =
        '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.$extension';

    final failures = <String>[];

    for (final bucket in buckets) {
      final objectPath = _objectPathForBucket(
        bucket: bucket,
        uid: uid,
        folder: folder,
        uniqueName: uniqueName,
      );

      try {
        await client.storage.from(bucket).uploadBinary(
              objectPath,
              bytes,
              fileOptions: FileOptions(
                contentType: contentType,
                upsert: false,
              ),
            );

        return client.storage.from(bucket).getPublicUrl(objectPath);
      } on StorageException catch (e) {
        failures.add('$bucket: ${e.message}');
        continue;
      } catch (e) {
        failures.add('$bucket: $e');
        continue;
      }
    }

    throw Exception(
      'Image upload failed on all configured buckets. '
      'Tried: ${buckets.join(', ')}. '
      'Details: ${failures.join(' | ')}',
    );
  }

  static String _fileExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static String _objectPathForBucket({
    required String bucket,
    required String? uid,
    required String folder,
    required String uniqueName,
  }) {
    final cleanFolder = folder.trim().replaceAll('\\', '/');

    // The profile-images bucket policy expects the first path segment to be uid.
    if (bucket == profileImagesBucket && uid != null && uid.isNotEmpty) {
      return '$uid/$cleanFolder/$uniqueName';
    }

    return '$cleanFolder/$uniqueName';
  }
}
