// lib/booking/repository/proof_repository.dart
//
// Proof upload & retrieval layer.
//
// ── Storage layout (bucket: pooja-proofs) ─────────────────────────────────────
//   {booking_id}/video.mp4
//   {booking_id}/images/{uuid}.jpg
//
// ── Database table: booking_proofs ────────────────────────────────────────────
//   id                   uuid         primary key
//   booking_id           uuid         references bookings(id) on delete cascade
//   pandit_id            uuid         references profiles(id)
//   video_storage_path   text         storage object path (no public URL stored)
//   video_duration_secs  int4         nullable
//   image_storage_paths  text[]       storage object paths
//   uploaded_at          timestamptz  not null default now()
//   is_verified          bool         not null default false
//   verifier_note        text         nullable
//
// Signed URLs are generated fresh on every read (TTL = 24 h).
// No public URLs are ever returned or stored.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/proof_model.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Supabase Storage bucket that holds all proof media.
const _kBucket = 'pooja-proofs';

/// Signed-URL expiry — 24 hours in seconds.
const _kSignedUrlExpiry = 86400;

// ── ProofUploadDraft ──────────────────────────────────────────────────────────

/// Input value-object passed to [IProofRepository.saveProof].
///
/// Provide **either** [videoLocalPath] (mobile) **or** [videoBytes] (web /
/// tests).  Same rule applies for images via [imageLocalPaths] /
/// [imageByteslist].
class ProofUploadDraft {
  const ProofUploadDraft({
    required this.bookingId,
    required this.panditId,
    this.videoLocalPath,
    this.videoBytes,
    this.videoDurationSeconds,
    this.imageLocalPaths = const [],
    this.imageByteslist = const [],
  });

  final String bookingId;
  final String panditId;

  /// Absolute local file path (mobile / desktop).
  final String? videoLocalPath;

  /// Raw bytes (web / unit tests — takes priority over [videoLocalPath]).
  final List<int>? videoBytes;

  final int? videoDurationSeconds;

  /// Local paths for optional image proofs.
  final List<String> imageLocalPaths;

  /// Raw bytes for optional image proofs (parallel index with [imageLocalPaths]).
  final List<List<int>> imageByteslist;
}

// ── Custom exception ──────────────────────────────────────────────────────────

/// Thrown by [SupabaseProofRepository] for any storage / database failure.
class ProofUploadException implements Exception {
  const ProofUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}

// ── Abstract interface ────────────────────────────────────────────────────────

abstract class IProofRepository {
  /// Returns the proof for [bookingId], with fresh 24-h signed URLs,
  /// or `null` if no proof has been uploaded yet.
  Future<ProofModel?> getProofForBooking(String bookingId);

  /// Uploads media to Storage and persists metadata to `booking_proofs`.
  ///
  /// [onProgress] fires with values in [0.0, 1.0] after each file finishes.
  Future<ProofModel> saveProof(
    ProofUploadDraft draft, {
    void Function(double progress)? onProgress,
  });

  /// Deletes all Storage objects and the `booking_proofs` row for [bookingId].
  Future<void> deleteProof(String bookingId);

  /// Re-generates signed URLs for an existing [ProofModel] whose URLs have
  /// expired (or are missing).  Safe to call at any time.
  Future<ProofModel> refreshSignedUrls(ProofModel proof);
}

// ── SupabaseProofRepository ───────────────────────────────────────────────────

/// Production implementation backed by Supabase Storage and PostgREST.
///
/// Required bucket policies on `pooja-proofs` (RLS):
///   INSERT — authenticated users where uid() = pandit_id
///   SELECT — authenticated users where uid() = pandit_id OR booking owner
///   DELETE — admin role or matching pandit
class SupabaseProofRepository implements IProofRepository {
  SupabaseProofRepository(this._client);

  final SupabaseClient _client;

  SupabaseStorageClient get _storage => _client.storage;

  static const _uuid = Uuid();

  // ── Public API ─────────────────────────────────────────────────────────────

  @override
  Future<ProofModel?> getProofForBooking(String bookingId) async {
    try {
      final row = await _client
          .from('booking_proofs')
          .select()
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (row == null) return null;

      // Build model from DB row — URLs are null (paths only in DB).
      final base = _rowToModel(row);

      // Hydrate with fresh 24-h signed URLs before returning.
      return refreshSignedUrls(base);
    } on PostgrestException catch (e) {
      throw ProofUploadException('Failed to load proof: ${e.message}');
    } on StorageException catch (e) {
      throw ProofUploadException('Failed to sign proof URLs: ${e.message}');
    }
  }

  @override
  Future<ProofModel> saveProof(
    ProofUploadDraft draft, {
    void Function(double progress)? onProgress,
  }) async {
    // One tick per file + one tick for DB insert.
    final totalSteps = 2 + draft.imageLocalPaths.length;
    var step = 0;
    void tick() => onProgress?.call(++step / totalSteps);

    // ── 1. Upload video ──────────────────────────────────────────────────────
    final videoStoragePath = '${draft.bookingId}/video.mp4';
    final videoBytes = await _resolveBytes(
      localPath: draft.videoLocalPath,
      rawBytes: draft.videoBytes,
      maxBytes: kMaxVideoBytes,
      label: 'Video',
    );

    try {
      await _storage.from(_kBucket).uploadBinary(
        videoStoragePath,
        videoBytes,
        fileOptions: const FileOptions(
          contentType: 'video/mp4',
          upsert: true,
        ),
      );
    } on StorageException catch (e) {
      throw ProofUploadException('Video upload failed: ${e.message}');
    }
    tick();

    // ── 2. Upload images ─────────────────────────────────────────────────────
    final imageStoragePaths = <String>[];
    for (int i = 0; i < draft.imageLocalPaths.length; i++) {
      final imgStoragePath =
          '${draft.bookingId}/images/${_uuid.v4()}.jpg';
      final imgBytes = await _resolveBytes(
        localPath: draft.imageLocalPaths[i],
        rawBytes:
            draft.imageByteslist.length > i ? draft.imageByteslist[i] : null,
        maxBytes: kMaxImageBytes,
        label: 'Image ${i + 1}',
      );

      try {
        await _storage.from(_kBucket).uploadBinary(
          imgStoragePath,
          imgBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
      } on StorageException catch (e) {
        throw ProofUploadException(
            'Image ${i + 1} upload failed: ${e.message}');
      }
      imageStoragePaths.add(imgStoragePath);
      tick();
    }

    // ── 3. Generate 24-h signed URLs — no public URLs ever returned ──────────
    final String videoUrl;
    try {
      videoUrl = await _createSignedUrl(videoStoragePath);
    } on StorageException catch (e) {
      throw ProofUploadException('Could not sign video URL: ${e.message}');
    }

    final imageUrls = <String>[];
    for (final path in imageStoragePaths) {
      try {
        imageUrls.add(await _createSignedUrl(path));
      } on StorageException catch (e) {
        throw ProofUploadException(
            'Could not sign image URL: ${e.message}');
      }
    }

    // ── 4. Persist metadata to booking_proofs (paths only, no URLs) ──────────
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final model = ProofModel(
      id: id,
      bookingId: draft.bookingId,
      panditId: draft.panditId,
      videoUrl: videoUrl,
      videoStoragePath: videoStoragePath,
      videoDurationSeconds: draft.videoDurationSeconds,
      imageUrls: imageUrls,
      imageStoragePaths: imageStoragePaths,
      uploadedAt: now,
    );

    try {
      await _client.from('booking_proofs').insert(_toDbRow(model));
    } on PostgrestException catch (e) {
      throw ProofUploadException(
          'Failed to save proof record: ${e.message}');
    }
    tick();

    return model;
  }

  @override
  Future<void> deleteProof(String bookingId) async {
    try {
      final row = await _client
          .from('booking_proofs')
          .select('video_storage_path, image_storage_paths')
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (row == null) return;

      final objectsToRemove = <String>[
        if (row['video_storage_path'] != null)
          row['video_storage_path'] as String,
        ...((row['image_storage_paths'] as List?)?.cast<String>() ?? []),
      ];

      if (objectsToRemove.isNotEmpty) {
        await _storage.from(_kBucket).remove(objectsToRemove);
      }

      await _client
          .from('booking_proofs')
          .delete()
          .eq('booking_id', bookingId);
    } on StorageException catch (e) {
      throw ProofUploadException('Storage delete failed: ${e.message}');
    } on PostgrestException catch (e) {
      throw ProofUploadException('Database delete failed: ${e.message}');
    }
  }

  @override
  Future<ProofModel> refreshSignedUrls(ProofModel proof) async {
    try {
      final videoUrl = proof.videoStoragePath != null
          ? await _createSignedUrl(proof.videoStoragePath!)
          : null;

      final imageUrls = <String>[];
      for (final path in proof.imageStoragePaths) {
        imageUrls.add(await _createSignedUrl(path));
      }

      return proof.copyWith(videoUrl: videoUrl, imageUrls: imageUrls);
    } on StorageException catch (e) {
      throw ProofUploadException(
          'Failed to refresh signed URLs: ${e.message}');
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Creates a signed URL valid for [_kSignedUrlExpiry] seconds.
  /// Only signed URLs are returned — public bucket access is never used.
  Future<String> _createSignedUrl(String storagePath) {
    return _storage
        .from(_kBucket)
        .createSignedUrl(storagePath, _kSignedUrlExpiry);
  }

  /// Reads bytes from [rawBytes] (priority) or [localPath], enforcing
  /// the [maxBytes] size ceiling.
  Future<Uint8List> _resolveBytes({
    required String? localPath,
    required List<int>? rawBytes,
    required int maxBytes,
    required String label,
  }) async {
    Uint8List data;

    if (rawBytes != null) {
      data = rawBytes is Uint8List
          ? rawBytes
          : Uint8List.fromList(rawBytes);
    } else if (localPath != null) {
      try {
        data = await File(localPath).readAsBytes();
      } catch (e) {
        throw ProofUploadException('Cannot read $label file: $e');
      }
    } else {
      throw const ProofUploadException('No file data provided.');
    }

    if (data.isEmpty) {
      throw ProofUploadException('$label file is empty.');
    }

    if (data.lengthInBytes > maxBytes) {
      final limitMb = maxBytes ~/ (1024 * 1024);
      final actualMb =
          (data.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
      throw ProofUploadException(
          '$label is too large ($actualMb MB). Maximum allowed is $limitMb MB.');
    }

    return data;
  }

  /// Builds a [ProofModel] from a raw DB row.
  /// `video_url` / `image_urls` are NOT stored in the DB;
  /// they are populated by [refreshSignedUrls].
  ProofModel _rowToModel(Map<String, dynamic> row) => ProofModel(
        id: row['id'] as String,
        bookingId: row['booking_id'] as String,
        panditId: row['pandit_id'] as String,
        videoUrl: null,
        videoStoragePath: row['video_storage_path'] as String?,
        videoDurationSeconds: row['video_duration_secs'] as int?,
        imageUrls: const [],
        imageStoragePaths: List<String>.from(
            (row['image_storage_paths'] as List?)?.cast<String>() ?? []),
        uploadedAt: DateTime.parse(row['uploaded_at'] as String),
        isVerified: row['is_verified'] as bool? ?? false,
        verifierNote: row['verifier_note'] as String?,
      );

  /// Produces the DB insert map.  Signed/public URLs are intentionally
  /// excluded — only storage paths are persisted.
  Map<String, dynamic> _toDbRow(ProofModel m) => {
        'id': m.id,
        'booking_id': m.bookingId,
        'pandit_id': m.panditId,
        'video_storage_path': m.videoStoragePath,
        'video_duration_secs': m.videoDurationSeconds,
        'image_storage_paths': m.imageStoragePaths,
        'uploaded_at': m.uploadedAt.toIso8601String(),
        'is_verified': m.isVerified,
        'verifier_note': m.verifierNote,
      };
}

// ── MockProofRepository ───────────────────────────────────────────────────────

/// In-memory mock for offline development and unit testing.
/// Pre-seeded with a demo proof for booking `b001`.
class MockProofRepository implements IProofRepository {
  MockProofRepository();

  MockProofRepository.seeded() {
    _store['b001'] = ProofModel(
      id: 'pr_demo',
      bookingId: 'b001',
      panditId: 'p004',
      videoUrl:
          'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4',
      videoStoragePath: 'b001/video.mp4',
      videoDurationSeconds: 167,
      imageUrls: const [
        'https://picsum.photos/seed/puja1/800/600',
        'https://picsum.photos/seed/puja2/800/600',
      ],
      imageStoragePaths: const [
        'b001/images/img-001.jpg',
        'b001/images/img-002.jpg',
      ],
      uploadedAt: DateTime.now().subtract(const Duration(hours: 2)),
      isVerified: true,
    );
  }

  final Map<String, ProofModel> _store = {};

  @override
  Future<ProofModel?> getProofForBooking(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 350));
    return _store[bookingId];
  }

  @override
  Future<ProofModel> saveProof(
    ProofUploadDraft draft, {
    void Function(double progress)? onProgress,
  }) async {
    // Match progress granularity of the real implementation.
    final totalSteps = 2 + draft.imageLocalPaths.length;
    for (int i = 1; i <= totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      onProgress?.call(i / totalSteps);
    }

    final id = 'pr_${draft.bookingId}';
    final videoPath = '${draft.bookingId}/video.mp4';
    final imagePaths = List.generate(
      draft.imageLocalPaths.length,
      (i) =>
          '${draft.bookingId}/images/img-${(i + 1).toString().padLeft(3, '0')}.jpg',
    );

    final proof = ProofModel(
      id: id,
      bookingId: draft.bookingId,
      panditId: draft.panditId,
      videoUrl: draft.videoLocalPath != null
          ? 'https://mock-storage.supabase.co/object/sign/$_kBucket/$videoPath?token=mock'
          : null,
      videoStoragePath: draft.videoLocalPath != null ? videoPath : null,
      videoDurationSeconds: draft.videoDurationSeconds,
      imageUrls: List.generate(
        imagePaths.length,
        (i) =>
            'https://mock-storage.supabase.co/object/sign/$_kBucket/${imagePaths[i]}?token=mock',
      ),
      imageStoragePaths: imagePaths,
      uploadedAt: DateTime.now(),
    );

    _store[draft.bookingId] = proof;
    return proof;
  }

  @override
  Future<void> deleteProof(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _store.remove(bookingId);
  }

  @override
  Future<ProofModel> refreshSignedUrls(ProofModel proof) async {
    // Mock: URLs don't expire in tests — return unchanged.
    return proof;
  }
}
