import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';
import 'clay.dart';

/// An image that lives behind `/api/files` and needs the session to be read.
///
/// Receipts and payment QRs are deliberately not served statically - a file
/// behind a guessable URL is a file anyone can take - so they cannot be dropped
/// into a plain Image widget. Without the token the request comes back 403 and
/// the picture is simply blank, which is how a seller's QR and a buyer's own
/// receipt both showed as empty grey boxes.
class PrivateImage extends StatelessWidget {
  const PrivateImage({
    super.key,
    required this.path,
    this.height,
    this.width,
    this.radius = AppRadius.sm,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.receipt_long_rounded,
  });

  final String path;
  final double? height;
  final double? width;
  final double radius;
  final BoxFit fit;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return _placeholder('Nothing attached');

    return FutureBuilder<Map<String, String>>(
      future: ApiClient.instance.imageHeaders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ClaySkeleton(height: height ?? 120, width: width, radius: radius);
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CachedNetworkImage(
            imageUrl: ApiConfig.mediaUrl(path),
            httpHeaders: snapshot.data,
            height: height,
            width: width,
            fit: fit,
            // Says what went wrong rather than leaving a blank rectangle for
            // somebody to wonder about.
            errorWidget: (_, _, _) => _placeholder('Could not load this image'),
            placeholder: (_, _) =>
                ClaySkeleton(height: height ?? 120, width: width, radius: radius),
          ),
        );
      },
    );
  }

  Widget _placeholder(String message) {
    return Container(
      height: height ?? 120,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(fallbackIcon, size: 24, color: AppColors.textMuted),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens one of those images full size, pinchable.
///
/// A receipt is read, not glanced at - the reference number on it is the whole
/// point - so it has to be enlargeable.
Future<void> showPrivateImage(
  BuildContext context, {
  required String path,
  required String title,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(14),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close_rounded,
                        size: 20, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: PrivateImage(
                  path: path,
                  radius: AppRadius.md,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
