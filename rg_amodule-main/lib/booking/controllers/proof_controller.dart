import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/proof_model.dart';
import '../repository/proof_repository.dart';

// ── Upload State ──────────────────────────────────────────────────────────────

class ProofUploadState {
  const ProofUploadState({
    this.videoFile,
    this.videoSize,
    this.videoDurationSeconds,
    this.imageFiles = const [],
    this.uploading = false,
    this.uploadProgress = 0.0,
    this.error,
    this.completed = false,
    this.savedProof,
  });

  /// Selected video file from device.
  final XFile? videoFile;

  /// File size in bytes (validated before upload).
  final int? videoSize;

  /// Rough duration in seconds (optional, shown as hint).
  final int? videoDurationSeconds;

  /// Optional image files (max [kMaxProofImages]).
  final List<XFile> imageFiles;

  final bool uploading;

  /// 0.0 → 1.0 progress during upload.
  final double uploadProgress;

  final String? error;

  /// True once upload completes successfully.
  final bool completed;

  /// The saved [ProofModel] after a successful upload.
  final ProofModel? savedProof;

  bool get hasVideo => videoFile != null;
  bool get hasImages => imageFiles.isNotEmpty;
  bool get canUpload => hasVideo && !uploading && !completed;

  /// Video size in MB, rounded to 1 dp.
  String? get videoSizeMb {
    if (videoSize == null) return null;
    return '${(videoSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  ProofUploadState copyWith({
    XFile? videoFile,
    int? videoSize,
    int? videoDurationSeconds,
    List<XFile>? imageFiles,
    bool? uploading,
    double? uploadProgress,
    String? error,
    bool? completed,
    ProofModel? savedProof,
    bool clearVideo = false,
    bool clearError = false,
  }) =>
      ProofUploadState(
        videoFile:           clearVideo ? null : (videoFile ?? this.videoFile),
        videoSize:           clearVideo ? null : (videoSize ?? this.videoSize),
        videoDurationSeconds: clearVideo
            ? null
            : (videoDurationSeconds ?? this.videoDurationSeconds),
        imageFiles:          imageFiles ?? this.imageFiles,
        uploading:           uploading ?? this.uploading,
        uploadProgress:      uploadProgress ?? this.uploadProgress,
        error:               clearError ? null : (error ?? this.error),
        completed:           completed ?? this.completed,
        savedProof:          savedProof ?? this.savedProof,
      );
}

// ── Proof Load State (for viewing) ────────────────────────────────────────────

class ProofViewState {
  const ProofViewState({
    this.loading = true,
    this.proof,
    this.error,
  });

  final bool loading;
  final ProofModel? proof;
  final String? error;

  bool get hasProof => proof != null;
}

// ── Upload Controller ─────────────────────────────────────────────────────────

class ProofUploadController extends StateNotifier<ProofUploadState> {
  ProofUploadController(this._repo) : super(const ProofUploadState());

  final IProofRepository _repo;
  final _picker = ImagePicker();

  // ── Video selection ────────────────────────────────────────────────────────

  Future<void> pickVideo() async {
    state = state.copyWith(clearError: true);

    XFile? picked;
    try {
      picked = await _picker.pickVideo(source: ImageSource.gallery);
    } catch (e) {
      state = state.copyWith(error: 'Could not open video picker: $e');
      return;
    }

    if (picked == null) return; // user cancelled

    // Validate file size.
    int size = 0;
    try {
      size = await picked.length();
    } catch (_) {
      size = await File(picked.path).length().catchError((_) => 0);
    }

    if (size > kMaxVideoBytes) {
      final mb = (size / (1024 * 1024)).toStringAsFixed(0);
      state = state.copyWith(
        clearVideo: true,
        error:
            'Video is too large ($mb MB). Maximum allowed size is ${kMaxVideoBytes ~/ (1024 * 1024)} MB.',
      );
      return;
    }

    if (size == 0) {
      state = state.copyWith(
        clearVideo: true,
        error: 'Could not read video file. Please try again.',
      );
      return;
    }

    state = state.copyWith(
      videoFile: picked,
      videoSize: size,
    );
  }

  void removeVideo() => state = state.copyWith(clearVideo: true);

  // ── Image selection ────────────────────────────────────────────────────────

  Future<void> pickImages() async {
    state = state.copyWith(clearError: true);

    final remaining = kMaxProofImages - state.imageFiles.length;
    if (remaining <= 0) {
      state = state.copyWith(
          error: 'Maximum $kMaxProofImages images allowed.');
      return;
    }

    List<XFile> picked = [];
    try {
      picked = await _picker.pickMultiImage(imageQuality: 85);
    } catch (e) {
      state = state.copyWith(error: 'Could not open image picker: $e');
      return;
    }

    if (picked.isEmpty) return;

    // Limit to remaining slots.
    picked = picked.take(remaining).toList();

    // Validate each image size.
    final valid = <XFile>[];
    final oversized = <String>[];
    for (final img in picked) {
      int imgSize = 0;
      try {
        imgSize = await img.length();
      } catch (_) {
        imgSize = await File(img.path).length().catchError((_) => 0);
      }
      if (imgSize > kMaxImageBytes) {
        oversized.add(img.name);
      } else {
        valid.add(img);
      }
    }

    final newList = [...state.imageFiles, ...valid];
    String? err;
    if (oversized.isNotEmpty) {
      err =
          '${oversized.length} image(s) exceeded the ${kMaxImageBytes ~/ (1024 * 1024)} MB limit and were skipped.';
    }

    state = state.copyWith(imageFiles: newList, error: err);
  }

  void removeImage(int index) {
    final updated = [...state.imageFiles];
    updated.removeAt(index);
    state = state.copyWith(imageFiles: updated);
  }

  // ── Upload ─────────────────────────────────────────────────────────────────

  Future<void> upload({
    required String bookingId,
    required String panditId,
  }) async {
    if (!state.canUpload) return;

    state = state.copyWith(uploading: true, uploadProgress: 0, clearError: true);

    try {
      final draft = ProofUploadDraft(
        bookingId: bookingId,
        panditId: panditId,
        videoLocalPath: state.videoFile!.path,
        videoDurationSeconds: state.videoDurationSeconds,
        imageLocalPaths: state.imageFiles.map((f) => f.path).toList(),
      );

      final proof = await _repo.saveProof(
        draft,
        onProgress: (p) {
          if (mounted) state = state.copyWith(uploadProgress: p);
        },
      );

      if (mounted) {
        state = state.copyWith(
          uploading: false,
          completed: true,
          savedProof: proof,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          uploading: false,
          error: 'Upload failed: ${e.toString()}',
        );
      }
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── View Controller (load existing proof) ─────────────────────────────────────

class ProofViewController extends StateNotifier<ProofViewState> {
  ProofViewController(this._repo, this._bookingId)
      : super(const ProofViewState()) {
    load();
  }

  final IProofRepository _repo;
  final String _bookingId;

  Future<void> load() async {
    state = const ProofViewState(loading: true);
    try {
      final proof = await _repo.getProofForBooking(_bookingId);
      if (mounted) {
        state = ProofViewState(loading: false, proof: proof);
      }
    } catch (e) {
      if (mounted) {
        state = ProofViewState(loading: false, error: e.toString());
      }
    }
  }

  Future<void> refresh() => load();
}
