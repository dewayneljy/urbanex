import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A single required-document row, styled like a text field (matching
/// the name/email fields around it) but tapping it opens a photo/file
/// picker instead of the keyboard. Shows the attached filename in place
/// of the label once something's picked. UrbanEx doesn't require an
/// actual upload to submit - this is entirely optional either way.
class DocumentUploadTile extends StatelessWidget {
  final String label;
  final String? attachmentName;
  final VoidCallback onTakePhoto;
  final VoidCallback onChooseGalleryPhoto;
  final VoidCallback onChooseFile;
  final VoidCallback onRemoveAttachment;

  const DocumentUploadTile({
    super.key,
    required this.label,
    required this.attachmentName,
    required this.onTakePhoto,
    required this.onChooseGalleryPhoto,
    required this.onChooseFile,
    required this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context) {
    final hasAttachment = attachmentName != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showAttachSheet(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(
              hasAttachment ? Icons.check_circle_outline : Icons.upload_file_outlined,
              color: hasAttachment ? AppColors.good : null,
            ),
            suffixIcon: hasAttachment
                ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemoveAttachment,
            )
                : const Icon(Icons.chevron_right),
          ),
          child: Text(
            attachmentName ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }

  void _showAttachSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  onTakePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose photo from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  onChooseGalleryPhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('Choose file'),
                onTap: () {
                  Navigator.pop(ctx);
                  onChooseFile();
                },
              ),
              if (attachmentName != null)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.bad),
                  title: Text('Remove attachment', style: TextStyle(color: AppColors.bad)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onRemoveAttachment();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}


