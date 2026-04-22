// lib/screens/home_screen.dart
    import 'package:flutter/material.dart';
    import 'package:video_player/video_player.dart';
    import '../services/media_service.dart';
    import '../models/media_item.dart';

    class HomeScreen extends StatefulWidget {
      @override
      State<HomeScreen> createState() => _HomeScreenState();
    }

    class _HomeScreenState extends State<HomeScreen> {
      final MediaService _mediaService = MediaService();
      List<MediaItem> _allMediaItems = [];
      bool _isLoading = true;

      @override
      void initState() {
        super.initState();
        _loadAllMedia();
      }

      Future<void> _loadAllMedia() async {
        setState(() {
          _isLoading = true;
        });
        try {
          final items = await _mediaService.getAllMediaItems();
          setState(() {
            _allMediaItems = items;
            _isLoading = false;
          });
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Laden der Medien: $e')),
          );
        }
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Medien Explorer'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),                onPressed: _loadAllMedia,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadAllMedia,
                  child: GridView.builder(
                    padding: EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                      childAspectRatio: 1, // Quadratisch
                    ),
                    itemCount: _allMediaItems.length,
                    itemBuilder: (context, index) {
                      final item = _allMediaItems[index];
                      return MediaItemCard(mediaItem: item, mediaService: _mediaService);
                    },
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              // Wähle eine Datei aus (z.B. über image_picker)
              // Hier simulieren wir das Hochladen einer festen Datei
              // In der Praxis müsstest du einen Dateiauswähler integrieren
              // String selectedPath = await FilePicker.platform.pickFiles().then((result) => result?.files.single.path);
              String? selectedPath = "/path/to/local/file.jpg"; // Placeholder
              if (selectedPath != null) {
                 try {
                   await _mediaService.uploadFile(selectedPath);
                   _loadAllMedia(); // Nach Upload Seite neu laden
                 } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Upload fehlgeschlagen: $e')),
                   );
                 }
              }
            },
            child: Icon(Icons.upload),
          ),
        );
      }
    }

    class MediaItemCard extends StatefulWidget {
      final MediaItem mediaItem;
      final MediaService mediaService;
      const MediaItemCard({Key? key, required this.mediaItem, required this.mediaService}) : super(key: key);

      @override
      State<MediaItemCard> createState() => _MediaItemCardState();
    }

    class _MediaItemCardState extends State<MediaItemCard> {
      VideoPlayerController? _videoController;
      bool _isVideoInitialized = false;

      @override
      void initState() {
        super.initState();
        if (widget.mediaItem.type == 'video') {
          _initializeVideoPlayer();
        }
      }

      @override
      void dispose() {
        _videoController?.dispose();
        super.dispose();
      }

      Future<void> _initializeVideoPlayer() async {
        _videoController = VideoPlayerController.network(widget.mediaItem.path);
        await _videoController!.initialize();
        await _videoController!.setLooping(true);
        setState(() {
          _isVideoInitialized = true;
        });
      }

      @override
      Widget build(BuildContext context) {
        Widget content;
        if (widget.mediaItem.type == 'image') {
          content = Image.network(
            widget.mediaItem.path,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: Colors.grey), // Platzhalter bei Fehler
          );
        } else { // video
          if (_isVideoInitialized && _videoController != null) {
            content = VideoPlayer(_videoController!);
          } else {
            content = Container(color: Colors.black); // Platzhalter während Laden
          }
        }
        return GestureDetector(
          onTap: () {
            // Navigiere zur Detailansicht (später hinzuzufügen)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaDetailScreen(
                  mediaItem: widget.mediaItem,
                  videoController: _videoController, // Falls Video
                ),
              ),
            );
          },
          onLongPress: () {
            // Optionales Menü für Aktionen (Löschen, etc.)
            if (!widget.mediaItem.isLocal) { // Nur für Remote-Dateien
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: Icon(Icons.delete),
                          title: Text('Löschen'),
                          onTap: () async {
                            Navigator.pop(context); // Schließe BottomSheet
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Löschen bestätigen'),
                                  content: Text('Möchtest du "${widget.mediaItem.displayName}" wirklich löschen?'),
                                  actions: [
                                    TextButton(
                                      child: Text('Abbrechen'),
                                      onPressed: () => Navigator.pop(context, false),
                                    ),
                                    TextButton(
                                      child: Text('Löschen'),
                                      onPressed: () => Navigator.pop(context, true),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (confirm == true) {
                               try {
                                 await widget.mediaService.deleteRemoteFile(widget.mediaItem.path);                                 // Aktualisiere die Liste im Parent (kann über Callback oder Provider erfolgen)
                                 // Am einfachsten hier direkt neu laden
                                 if (mounted) { // Sicherstellen, dass Widget noch eingebaut ist
                                   Navigator.pop(context); // Zurück zur HomeScreen
                                   Navigator.of(context, rootNavigator: true).pop(); // Schließe DetailScreen, falls offen
                                   WidgetsBinding.instance.addPostFrameCallback((_) {
                                     // Führe nach dem nächsten Render-Zyklus aus
                                     final parentState = context.findAncestorStateOfType<_HomeScreenState>();
                                     parentState?._loadAllMedia();
                                   });
                                 }
                               } catch (e) {
                                 if (mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
                                   );
                                 }
                               }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            }
          },
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                content,
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                    child: Text(
                      widget.mediaItem.displayName ?? widget.mediaItem.id,                      style: TextStyle(color: Colors.white, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      }
    }

    // Bildschirm für die Detailansicht eines einzelnen Mediums
    class MediaDetailScreen extends StatefulWidget {
      final MediaItem mediaItem;
      final VideoPlayerController? videoController; // Falls es ein Video war

      const MediaDetailScreen({Key? key, required this.mediaItem, this.videoController}) : super(key: key);

      @override
      State<MediaDetailScreen> createState() => _MediaDetailScreenState();
    }

    class _MediaDetailScreenState extends State<MediaDetailScreen> {
      late VideoPlayerController? _controller = widget.videoController;

      @override
      Widget build(BuildContext context) {
        Widget content;
        if (widget.mediaItem.type == 'image') {
          content = InteractiveViewer(
            child: Image.network(
              widget.mediaItem.path,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: Colors.grey),
            ),
          );
        } else { // video
          if (_controller != null && _controller!.value.isInitialized) {
            content = AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            );
          } else {
            content = const Center(child: CircularProgressIndicator()); // Während Initialisierung
          }
        }

        return Scaffold(
          appBar: AppBar(            title: Text(widget.mediaItem.displayName ?? widget.mediaItem.id),
            // Optional: Weitere Aktionen wie Teilen, Download
          ),
          body: Center(
            child: content,
          ),
        );
      }
    }
