// lib/models/media_item.dart
    class MediaItem {
      final String id;
      final String path;
      final String type; // 'image' oder 'video'
      final DateTime dateModified;
      final bool isLocal; // True für lokal, False für remote
      final String? displayName; // Optionaler Anzeigename

      MediaItem({
        required this.id,
        required this.path,
        required this.type,
        required this.dateModified,
        required this.isLocal,
        this.displayName,
      });
    }
