// lib/services/media_service.dart
    import 'package:dio/dio.dart';
    import 'package:photo_manager/photo_manager.dart';
    import 'package:video_player/video_player.dart';
    import '../models/media_item.dart';
    import 'server_config.dart';
    import 'dart:convert'; // Für base64Encode

    class MediaService {
      late Dio _dio;

      MediaService() {
        _dio = Dio(
          BaseOptions(
            baseUrl: ServerConfig.baseUrl,
            headers: {
              'Authorization': 'Basic ' +
                  base64Encode(utf8.encode('${ServerConfig.username}:${ServerConfig.password}')),
            },
          ),
        );
      }

      Future<List<MediaItem>> getAllMediaItems() async {
        final List<MediaItem> items = [];

        // 1. Lade lokale Medien
        final localItems = await _getLocalMedia();
        items.addAll(localItems);

        // 2. Lade Server-Medien
        try {
          final remoteItems = await _getRemoteMedia();
          items.addAll(remoteItems);
        } catch (e) {
          print("Fehler beim Abrufen der Server-Medien: $e");
          // Optional: Fehlermeldung anzeigen
        }

        // Sortieren nach Datum (neueste zuerst)
        items.sort((a, b) => b.dateModified.compareTo(a.dateModified));

        return items;
      }

      Future<List<MediaItem>> _getLocalMedia() async {
        final List<MediaItem> localItems = [];
        final permissionResult = await PhotoManager.requestPermissionSet(
          PermissionState(requestWrite: true),
        );
        if (permissionResult != PermissionState.authorized) {
          print('Zugriff auf Medien verweigert');
          return localItems; // Leere Liste zurückgeben
        }

        final albums = await PhotoManager.getAssetPathList(type: RequestType.common);
        for (final album in albums) {
          final assets = await album.getAssetListPaged(page: 0, size: 9999); // Große Zahl, besser seitenweise laden
          for (final asset in assets) {
            final file = await asset.file;
            if (file != null) {
              final type = asset.type == AssetType.video ? 'video' : 'image';
              localItems.add(MediaItem(
                id: asset.id,
                path: file.path,
                type: type,
                dateModified: DateTime.fromMillisecondsSinceEpoch(asset.modifiedDateTime),
                isLocal: true,
                displayName: asset.title ?? asset.id,
              ));
            }
          }
        }
        return localItems;
      }

      Future<List<MediaItem>> _getRemoteMedia() async {
        final List<MediaItem> remoteItems = [];
        try {
          final response = await _dio.get<String>(
            '/',
            options: Options(
              responseType: ResponseType.plain,
              headers: {'Depth': 'infinity'}, // Für WebDAV, um rekursiv zu suchen
            ),
          );

          // Parsen der WebDAV Antwort (PROPFIND XML)
          // Dies ist stark vereinfacht - ein echtes Parsen erfordert das xml Package
          // Beispiel für eine sehr grobe Annahme:
          // <D:href>/webdav/image.jpg</D:href><D:getcontenttype>image/jpeg</D:getcontenttype>
          // <D:href>/webdav/video.mp4</D:href><D:getcontenttype>video/mp4</D:getcontenttype>

          // --- VORSICHTIGES PARSING ---
          // In der Praxis solltest du ein XML-Parsing-Tool verwenden!
          // final document = XmlDocument.parse(response.data);
          // ...

          // Simuliere das Parsen:          // Angenommen, response.data enthält eine Liste von Dateipfaden und Typen
          // Du musst hier die tatsächliche WebDAV PROPFIND Antwort parsen
          // Dies ist nur ein Platzhalter. Ein echter Parser ist notwendig.
          // Beispiel-Regex für einen einfachen Fall (NICHT robust!):
          final RegExp regExp = RegExp(r'<D:href>(.*?)</D:href>.*?<D:getcontenttype>(.*?)</D:getcontenttype>', multiLine: true);
          for (Match match in regExp.allMatches(response.data)) {
            final path = match.group(1)!;
            final contentType = match.group(2)!;
            if (contentType.startsWith('image/')) {
              remoteItems.add(MediaItem(
                id: path, // ID kann Pfad sein
                path: ServerConfig.baseUrl + path,
                type: 'image',
                dateModified: DateTime.now(), // WebDAV kann Datum liefern, hier vereinfacht
                isLocal: false,
                displayName: path.split('/').last,
              ));
            } else if (contentType.startsWith('video/')) {
              remoteItems.add(MediaItem(
                id: path,
                path: ServerConfig.baseUrl + path,
                type: 'video',
                dateModified: DateTime.now(),
                isLocal: false,
                displayName: path.split('/').last,
              ));
            }
          }
          // --- ENDE VORSICHTIGES PARSING ---

        } catch (e) {
          print("Fehler beim Abrufen der Remote-Medien: $e");
          rethrow; // Weiterwerfen, damit der Aufrufer weiß, dass es fehlgeschlagen ist
        }
        return remoteItems;
      }

      Future<void> uploadFile(String localFilePath) async {
        try {
          final fileName = localFilePath.split('/').last;
          await _dio.put(
            '/$fileName',
            await MultipartFile.fromFile(localFilePath, filename: fileName),
            options: Options(
              headers: {'Content-Type': 'application/octet-stream'},
            ),
          );
        } catch (e) {
          print("Fehler beim Hochladen: $e");
          rethrow;        }
      }

      Future<void> deleteRemoteFile(String remotePath) async {
        try {
          await _dio.delete(remotePath);
        } catch (e) {
          print("Fehler beim Löschen: $e");
          rethrow;
        }
      }

      // Weitere Funktionen wie Verschieben können hier hinzugefügt werden
    }
