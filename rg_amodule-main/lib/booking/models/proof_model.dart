// ── Proof Model ───────────────────────────────────────────────────────────────
//
// Represents the service-completion proof uploaded by a pandit.
// Backed by Supabase Storage:
//   bucket  : 'pooja-proofs'
//   video   : {bookingId}/video.mp4
//   images  : {bookingId}/images/{uuid}.jpg
//
// Signed URLs (TTL = 24 h) are generated on read and never stored in the DB.
//

/// Maximum allowed video file size (300 MB).
const kMaxVideoBytes = 300 * 1024 * 1024; // 300 MB

/// Maximum allowed image file size (3 MB each).
const kMaxImageBytes = 3 * 1024 * 1024; // 3 MB

/// Maximum number of image proofs per booking.
const kMaxProofImages = 6;

class ProofModel {
  const ProofModel({
    required this.id,
    required this.bookingId,
    required this.panditId,
    required this.uploadedAt,
    this.videoUrl,
    this.videoStoragePath,
    this.videoDurationSeconds,
    this.imageUrls = const [],
    this.imageStoragePaths = const [],
    this.isVerified = false,
    this.verifierNote,
  });

  /// Unique proof record ID.
  final String id;

  /// The booking this proof belongs to.
  final String bookingId;

  /// The pandit who uploaded this proof.
  final String panditId;

  /// Supabase Storage signed/public URL for the video.
  /// `null` until uploaded.
  final String? videoUrl;

  /// Storage object path inside the `proofs` bucket (used to stream / delete).
  final String? videoStoragePath;

  /// Optional duration in seconds (extracted from metadata or provided by upload).
  final int? videoDurationSeconds;

  /// Public URLs for optional image proofs (max [kMaxProofImages]).
  final List<String> imageUrls;

  /// Storage paths for image objects.
  final List<String> imageStoragePaths;

  /// When the proof was uploaded.
  final DateTime uploadedAt;

  /// Whether an admin has verified this proof.
  final bool isVerified;

  /// Admin note attached during verification.
  final String? verifierNote;

  bool get hasVideo => videoUrl != null;
  bool get hasImages => imageUrls.isNotEmpty;

  // ── Serialisation ──────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'id':                   id,
        'booking_id':           bookingId,
        'pandit_id':            panditId,
        'video_url':            videoUrl,
        'video_storage_path':   videoStoragePath,
        'video_duration_secs':  videoDurationSeconds,
        'image_urls':           imageUrls,
        'image_storage_paths':  imageStoragePaths,
        'uploaded_at':          uploadedAt.toIso8601String(),
        'is_verified':          isVerified,
        'verifier_note':        verifierNote,
      };

  factory ProofModel.fromJson(Map<String, dynamic> j) => ProofModel(
        id:                  j['id'] as String,
        bookingId:           j['booking_id'] as String,
        panditId:            j['pandit_id'] as String,
        videoUrl:            j['video_url'] as String?,
        videoStoragePath:    j['video_storage_path'] as String?,
        videoDurationSeconds: j['video_duration_secs'] as int?,
        imageUrls:           List<String>.from(
            (j['image_urls'] as List?)?.cast<String>() ?? []),
        imageStoragePaths:   List<String>.from(
            (j['image_storage_paths'] as List?)?.cast<String>() ?? []),
        uploadedAt:          DateTime.parse(j['uploaded_at'] as String),
        isVerified:          j['is_verified'] as bool? ?? false,
        verifierNote:        j['verifier_note'] as String?,
      );

  ProofModel copyWith({
    String? videoUrl,
    String? videoStoragePath,
    int? videoDurationSeconds,
    List<String>? imageUrls,
    List<String>? imageStoragePaths,
    bool? isVerified,
    String? verifierNote,
  }) =>
      ProofModel(
        id:                  id,
        bookingId:           bookingId,
        panditId:            panditId,
        uploadedAt:          uploadedAt,
        videoUrl:            videoUrl ?? this.videoUrl,
        videoStoragePath:    videoStoragePath ?? this.videoStoragePath,
        videoDurationSeconds: videoDurationSeconds ?? this.videoDurationSeconds,
        imageUrls:           imageUrls ?? this.imageUrls,
        imageStoragePaths:   imageStoragePaths ?? this.imageStoragePaths,
        isVerified:          isVerified ?? this.isVerified,
        verifierNote:        verifierNote ?? this.verifierNote,
      );
}
