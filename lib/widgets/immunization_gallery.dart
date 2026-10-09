import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import 'app_feedback.dart';

/// One page in the immunization gallery. [id] is the id of an already-saved
/// document, or null for a page that was just captured. Registration only
/// deals in freshly captured paths (null ids); the child profile passes the
/// ids of saved documents so removals can be reconciled.
class ImmunizationPage {
  final String? id;
  final String path;
  final String? sha256;

  const ImmunizationPage({this.id, required this.path, this.sha256});
}

/// Shared immunization page picker: capture/attach one photo per page,
/// review thumbnails, remove unwanted pages. Returns the resulting list, or
/// null if the user cancelled.
Future<List<ImmunizationPage>?> showImmunizationGallery(
  BuildContext context, {
  required List<ImmunizationPage> initialPages,
}) {
  return showDialog<List<ImmunizationPage>>(
    context: context,
    builder: (_) => _ImmunizationGalleryDialog(initialPages: initialPages),
  );
}

class _ImmunizationGalleryDialog extends StatefulWidget {
  final List<ImmunizationPage> initialPages;

  const _ImmunizationGalleryDialog({required this.initialPages});

  @override
  State<_ImmunizationGalleryDialog> createState() =>
      _ImmunizationGalleryDialogState();
}

class _ImmunizationGalleryDialogState extends State<_ImmunizationGalleryDialog> {
  late final List<ImmunizationPage> _pages;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _pages = List.of(widget.initialPages);
  }

  Future<void> _addPage() async {
    setState(() => _isAdding = true);
    try {
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        final files = await FilePicker.pickFiles(type: FileType.image);
        if (files.isNotEmpty && files.single.path != null && mounted) {
          setState(() => _pages.add(ImmunizationPage(path: files.single.path!)));
        }
        return;
      }
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file != null && mounted) {
        setState(() => _pages.add(ImmunizationPage(path: file.path)));
      }
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Could not open the camera. Check permission and try again.',
        kind: AppFeedbackKind.error,
        actionLabel: 'Retry',
        onAction: _addPage,
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Immunization pages'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pages.isEmpty
                  ? 'Take a photo of each immunization page.'
                  : '${_pages.length} page(s) ready to save.',
              style: AppText.caption,
            ),
            const SizedBox(height: 12),
            if (_pages.isEmpty)
              Container(
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('No pages added yet', style: AppText.caption),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: _pages.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(page.path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: AppColors.muted,
                              alignment: Alignment.center,
                              child: Text('Image unavailable',
                                  style: AppText.caption),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            onPressed: () =>
                                setState(() => _pages.removeAt(index)),
                            icon: const Icon(Icons.close),
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                            tooltip: 'Remove page ${index + 1}',
                          ),
                        ),
                        Positioned(
                          left: 8,
                          bottom: 6,
                          child: Text(
                            'Page ${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(blurRadius: 3, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isAdding ? null : _addPage,
                icon: _isAdding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo_outlined),
                label: Text(_isAdding ? 'Opening camera...' : 'Add page'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_pages),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
