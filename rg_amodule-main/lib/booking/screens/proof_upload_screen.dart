import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/proof_controller.dart';
import '../models/proof_model.dart';
import '../providers/proof_provider.dart';

/// Screen for pandits to upload service-completion proof.
///
/// Route: `/booking/:id/upload-proof`
/// Query params: `panditId` (required), `title` (booking title for display).
class ProofUploadScreen extends ConsumerWidget {
  const ProofUploadScreen({
    super.key,
    required this.bookingId,
    required this.panditId,
    required this.bookingTitle,
  });

  final String bookingId;
  final String panditId;
  final String bookingTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(proofUploadProvider(bookingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Proof',
            style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      body: state.completed
          ? _SuccessView(proof: state.savedProof!, bookingId: bookingId)
          : _UploadBody(
              bookingId: bookingId,
              panditId: panditId,
              bookingTitle: bookingTitle),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _UploadBody extends ConsumerWidget {
  const _UploadBody({
    required this.bookingId,
    required this.panditId,
    required this.bookingTitle,
  });

  final String bookingId;
  final String panditId;
  final String bookingTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state  = ref.watch(proofUploadProvider(bookingId));
    final ctrl   = ref.read(proofUploadProvider(bookingId).notifier);
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;

    return Stack(
      children: [
        // ── Scrollable content ───────────────────────────────────────────────
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Booking badge
              _BookingBadge(bookingTitle: bookingTitle, bookingId: bookingId),
              const SizedBox(height: 24),

              // ── Video section ──────────────────────────────────────────────
              Text('Service Video *',
                  style: tt.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Record the full service (2–3 min recommended). '
                'Max file size: ${kMaxVideoBytes ~/ (1024 * 1024)} MB.',
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              state.hasVideo
                  ? _VideoPreviewTile(
                      file: state.videoFile!,
                      sizeMb: state.videoSizeMb ?? '—',
                      onRemove: ctrl.removeVideo,
                    )
                  : _PickerButton(
                      icon: Icons.video_library_rounded,
                      label: 'Select Video',
                      onTap: ctrl.pickVideo,
                    ),

              const SizedBox(height: 28),

              // ── Image section ──────────────────────────────────────────────
              Row(
                children: [
                  Text('Photo Proof',
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text('(optional · max $kMaxProofImages)',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Add photos of the setup, materials used, or any '
                'moment from the service. Max ${kMaxImageBytes ~/ (1024 * 1024)} MB each.',
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              _ImageGrid(
                files: state.imageFiles,
                onAdd: state.imageFiles.length < kMaxProofImages
                    ? ctrl.pickImages
                    : null,
                onRemove: ctrl.removeImage,
              ),

              // ── Guidelines card ────────────────────────────────────────────
              const SizedBox(height: 28),
              _GuidelinesCard(),

              // ── Error banner ───────────────────────────────────────────────
              if (state.error != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(
                    message: state.error!, onDismiss: ctrl.clearError),
              ],
            ],
          ),
        ),

        // ── Sticky upload bar ────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _UploadBar(
            state: state,
            onUpload: () => ctrl.upload(
              bookingId: bookingId,
              panditId: panditId,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Booking badge ─────────────────────────────────────────────────────────────

class _BookingBadge extends StatelessWidget {
  const _BookingBadge(
      {required this.bookingTitle, required this.bookingId});
  final String bookingTitle;
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.temple_hindu_rounded,
              color: cs.onPrimaryContainer, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bookingTitle,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer)),
                Text('ID: $bookingId',
                    style: TextStyle(
                        fontSize: 11, color: cs.onPrimaryContainer.withAlpha(170))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Picker button ─────────────────────────────────────────────────────────────

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          border: Border.all(
              color: cs.primary.withAlpha(100), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(14),
          color: cs.primary.withAlpha(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: cs.primary),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: cs.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Video preview tile ────────────────────────────────────────────────────────

class _VideoPreviewTile extends StatelessWidget {
  const _VideoPreviewTile({
    required this.file,
    required this.sizeMb,
    required this.onRemove,
  });
  final dynamic file; // XFile
  final String sizeMb;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final tt  = Theme.of(context).textTheme;
    final name = (file.name as String?) ?? _truncatePath(file.path as String);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.play_circle_rounded,
                size: 32, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.data_usage_rounded,
                        size: 12, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(sizeMb,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: cs.error),
            onPressed: onRemove,
            tooltip: 'Remove video',
          ),
        ],
      ),
    );
  }

  static String _truncatePath(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.last;
  }
}

// ── Image grid ────────────────────────────────────────────────────────────────

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.files,
    required this.onRemove,
    this.onAdd,
  });
  final List<dynamic> files; // List<XFile>
  final void Function(int) onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // Existing images
        for (int i = 0; i < files.length; i++)
          _ImageThumb(
            path: files[i].path as String,
            onRemove: () => onRemove(i),
          ),

        // Add button
        if (onAdd != null)
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                border: Border.all(
                    color: cs.primary.withAlpha(100),
                    style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
                color: cs.primary.withAlpha(12),
              ),
              child: Icon(Icons.add_photo_alternate_rounded,
                  size: 32, color: cs.primary),
            ),
          ),
      ],
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.path, required this.onRemove});
  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.broken_image_rounded,
                    color: cs.onSurfaceVariant),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: cs.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Guidelines card ───────────────────────────────────────────────────────────

class _GuidelinesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      'Video should clearly show the entire ceremony/service.',
      'Ensure good lighting and stable recording.',
      'Include beginning, main ritual, and completion.',
      'Avoid recording personal conversations.',
      'Proof is only visible to the customer after admin review.',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.secondary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_rounded,
                  size: 18, color: cs.secondary),
              const SizedBox(width: 8),
              Text('Recording Guidelines',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onSecondaryContainer)),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ',
                      style: TextStyle(
                          color: cs.secondary, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(t,
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSecondaryContainer)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 18, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: cs.onErrorContainer, fontSize: 13)),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 18, color: cs.onErrorContainer),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Upload bar ────────────────────────────────────────────────────────────────

class _UploadBar extends StatelessWidget {
  const _UploadBar({required this.state, required this.onUpload});
  final ProofUploadState state;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: state.uploading
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: state.uploadProgress,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  state.uploadProgress < 1.0
                      ? 'Uploading… ${(state.uploadProgress * 100).round()}%'
                      : 'Finalising…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            )
          : FilledButton.icon(
              onPressed: state.canUpload ? onUpload : null,
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Upload Proof',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
    );
  }
}

// ── Success view ──────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.proof, required this.bookingId});
  final ProofModel proof;
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded,
                size: 72, color: Colors.green.shade600),
          ),
          const SizedBox(height: 24),
          Text('Proof Uploaded!',
              style: tt.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            'Your service proof has been submitted successfully. '
            'It will be reviewed and made visible to the customer.',
            textAlign: TextAlign.center,
            style:
                tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text('Ref: ${proof.id}',
              style: tt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: () =>
                context.go('/booking/$bookingId'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to Booking'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}
