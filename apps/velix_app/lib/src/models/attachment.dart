enum AttachmentType { image, video, audio, file, location, contact }

class Attachment {
  final String id;
  final AttachmentType type;
  final String url;
  final String? thumbnail;
  final int sizeBytes;
  final String? mimeType;
  final String? fileName;
  const Attachment({required this.id, required this.type, required this.url, this.thumbnail, required this.sizeBytes, this.mimeType, this.fileName});
  String get sizeLabel {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1048576) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(sizeBytes / 1048576).toStringAsFixed(1)}MB';
  }
}
