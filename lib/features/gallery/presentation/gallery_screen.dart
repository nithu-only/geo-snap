import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/gallery_photo.dart';
import '../../../core/state/gallery_controller.dart';
import '../../../core/state/settings_controller.dart';
import '../../../core/utils/export_helper.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _selectedFolder = '';
  bool _showMapView = false;
  bool _isSelectionMode = false;
  final Set<GalleryPhoto> _selectedPhotos = {};

  void _toggleSelection(GalleryPhoto photo) {
    setState(() {
      if (_selectedPhotos.contains(photo)) {
        _selectedPhotos.remove(photo);
        if (_selectedPhotos.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPhotos.add(photo);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll(List<GalleryPhoto> photos) {
    setState(() {
      if (_selectedPhotos.length == photos.length) {
        _selectedPhotos.clear();
        _isSelectionMode = false;
      } else {
        _selectedPhotos.addAll(photos);
        _isSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPhotos.clear();
    });
  }

  Future<void> _deleteSelected(BuildContext context) async {
    if (_selectedPhotos.isEmpty) return;
    final controller = context.read<GalleryController>();
    final count = _selectedPhotos.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count photos?'),
        content: const Text(
          'This will permanently remove the selected photos from GeoSnap.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final toDelete = _selectedPhotos.toList();
      _exitSelectionMode();
      await controller.deleteMultiple(toDelete);
    }
  }

  Future<void> _shareSelected(BuildContext context) async {
    if (_selectedPhotos.isEmpty) return;
    final controller = context.read<GalleryController>();
    await controller.shareMultiple(_selectedPhotos.toList());
  }

  Future<void> _exportCsv() async {
    if (_selectedPhotos.isEmpty) return;
    await ExportHelper.exportToCsv(_selectedPhotos.toList());
  }

  Future<void> _exportKml() async {
    if (_selectedPhotos.isEmpty) return;
    await ExportHelper.exportToKml(_selectedPhotos.toList());
  }

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>().settings;
    _selectedFolder = settings.saveFolderUri.isNotEmpty
        ? settings.saveFolderUri
        : settings.saveFolder;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedFolder.startsWith('content://')) {
        context.read<GalleryController>().load(saveFolderUri: _selectedFolder);
      } else {
        context.read<GalleryController>().load(saveFolder: _selectedFolder);
      }
    });
  }

  void _showPhotoBottomSheet(BuildContext context, GalleryPhoto photo) {
    final controller = context.read<GalleryController>();
    final photos = controller.photos;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FutureBuilder(
                        future: controller.thumbnailFor(photo),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return Image.memory(snapshot.data!, fit: BoxFit.cover);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            photo.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lat: ${photo.latitude?.toStringAsFixed(6)}°, Lng: ${photo.longitude?.toStringAsFixed(6)}°',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(photo.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share'),
                        onPressed: () {
                          Navigator.pop(context);
                          controller.share(photo);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        onPressed: () async {
                          Navigator.pop(context);
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete photo?'),
                              content: const Text(
                                'This removes the saved image from GeoSnap.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            await controller.delete(photo);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.fullscreen),
                        label: const Text('View'),
                        onPressed: () {
                          Navigator.pop(context);
                          final index = photos.indexOf(photo);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PhotoDetailScreen(
                                photos: photos,
                                initialIndex: index >= 0 ? index : 0,
                                fromGallery: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GalleryController>();
    final photos = controller.photos;
    final settings = context.watch<SettingsController>().settings;
    final folders = context.watch<SettingsController>().folders;

    String displayTitle = 'Gallery';
    if (_selectedFolder.isNotEmpty) {
      if (_selectedFolder == settings.saveFolderUri) {
        displayTitle = settings.saveFolderLabel;
      } else {
        displayTitle = _selectedFolder;
      }
    }

    Widget body;
    if (controller.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (photos.isEmpty) {
      body = const _EmptyGallery();
    } else if (_showMapView) {
      final mapPhotos = photos.where((p) => p.latitude != null && p.longitude != null).toList();
      if (mapPhotos.isEmpty) {
        body = const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No photos with GPS locations found in this folder.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        );
      } else {
        final initialCenter = LatLng(mapPhotos.first.latitude!, mapPhotos.first.longitude!);
        body = FlutterMap(
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.nithu.geosnap',
            ),
            MarkerLayer(
              markers: mapPhotos.map((photo) {
                return Marker(
                  point: LatLng(photo.latitude!, photo.longitude!),
                  width: 50,
                  height: 50,
                  child: GestureDetector(
                    onTap: () => _showPhotoBottomSheet(context, photo),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: FutureBuilder(
                          future: controller.thumbnailFor(photo),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                width: 45,
                                height: 45,
                                fit: BoxFit.cover,
                              );
                            }
                            return const Icon(
                              Icons.image,
                              color: Colors.white,
                              size: 20,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      }
    } else {
      body = RefreshIndicator(
        onRefresh: () {
          if (_selectedFolder.startsWith('content://')) {
            return controller.load(saveFolderUri: _selectedFolder);
          } else {
            return controller.load(saveFolder: _selectedFolder);
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SearchBar(
                    hintText: 'Search by date',
                    leading: const Icon(Icons.search),
                    onChanged: controller.search,
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final photo = photos[index];
                    final isSelected = _selectedPhotos.contains(photo);
                    return _PhotoTile(
                      photo: photo,
                      isSelected: isSelected,
                      isSelectionMode: _isSelectionMode,
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(photo);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PhotoDetailScreen(
                                photos: photos,
                                initialIndex: index,
                                fromGallery: true,
                              ),
                            ),
                          );
                        }
                      },
                      onLongPress: () {
                        _toggleSelection(photo);
                      },
                    );
                  },
                  childCount: photos.length,
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Exit selection',
                onPressed: _exitSelectionMode,
              ),
              title: Text('${_selectedPhotos.length} selected'),
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedPhotos.length == photos.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  tooltip: _selectedPhotos.length == photos.length ? 'Deselect all' : 'Select all',
                  onPressed: () => _selectAll(photos),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Share selected',
                  onPressed: () => _shareSelected(context),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete selected',
                  onPressed: () => _deleteSelected(context),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Export options',
                  onSelected: (val) {
                    if (val == 'csv') _exportCsv();
                    if (val == 'kml') _exportKml();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'csv',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Export as CSV'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'kml',
                      child: Row(
                        children: [
                          Icon(Icons.public_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Export as KML (Google Earth)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : AppBar(
              title: Text(displayTitle),
              actions: [
                IconButton(
                  icon: Icon(_showMapView ? Icons.grid_view : Icons.map_outlined),
                  tooltip: _showMapView ? 'Switch to Grid View' : 'Switch to Map View',
                  onPressed: () {
                    setState(() {
                      _showMapView = !_showMapView;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Select photos',
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = true;
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.folder_open_outlined),
                  tooltip: 'Filter by folder',
                  initialValue: _selectedFolder,
                  onSelected: (folder) {
                    setState(() {
                      _selectedFolder = folder;
                    });
                    if (folder.startsWith('content://')) {
                      context.read<GalleryController>().load(saveFolderUri: folder);
                    } else {
                      context.read<GalleryController>().load(saveFolder: folder);
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      if (settings.saveFolderUri.isNotEmpty)
                        PopupMenuItem(
                          value: settings.saveFolderUri,
                          child: Text('Device: ${settings.saveFolderLabel}'),
                        ),
                      const PopupMenuItem(
                        value: '',
                        child: Text('Default (Root)'),
                      ),
                      ...folders.map(
                        (f) => PopupMenuItem(
                          value: f,
                          child: Text(f),
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
      body: body,
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  final GalleryPhoto photo;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<GalleryController>();
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: FutureBuilder(
                    future: controller.thumbnailFor(photo),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Image.memory(snapshot.data!, fit: BoxFit.cover);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy').format(photo.createdAt),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        DateFormat('hh:mm a').format(photo.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isSelected ? Icons.check : Icons.circle_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PhotoDetailScreen extends StatefulWidget {
  const PhotoDetailScreen({
    required this.photos,
    required this.initialIndex,
    this.fromGallery = false,
    super.key,
  });

  final List<GalleryPhoto> photos;
  final int initialIndex;
  final bool fromGallery;

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<GalleryPhoto> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List<GalleryPhoto>.from(widget.photos);
    _currentIndex = widget.initialIndex.clamp(0, _photos.isEmpty ? 0 : _photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<GalleryController>();
    if (_photos.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No photos')),
      );
    }

    final safeIndex = _currentIndex.clamp(0, _photos.length - 1);
    final photo = _photos[safeIndex];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              photo.name,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${safeIndex + 1} of ${_photos.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (!widget.fromGallery)
            IconButton(
              tooltip: 'Gallery',
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GalleryScreen()),
                );
              },
            ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => controller.share(photo),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete photo?'),
                  content: const Text(
                    'This removes the saved image from GeoSnap.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await controller.delete(photo);
                if (context.mounted) {
                  setState(() {
                    _photos.removeAt(safeIndex);
                    if (_photos.isEmpty) {
                      Navigator.of(context).pop();
                    } else {
                      if (_currentIndex >= _photos.length) {
                        _currentIndex = _photos.length - 1;
                      }
                      if (_pageController.hasClients) {
                        _pageController.jumpToPage(_currentIndex);
                      }
                    }
                  });
                }
              }
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _photos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return _PhotoPageItem(
            key: ValueKey(_photos[index].uri),
            photo: _photos[index],
            controller: controller,
          );
        },
      ),
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'No saved photos yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _PhotoPageItem extends StatefulWidget {
  const _PhotoPageItem({
    super.key,
    required this.photo,
    required this.controller,
  });

  final GalleryPhoto photo;
  final GalleryController controller;

  @override
  State<_PhotoPageItem> createState() => _PhotoPageItemState();
}

class _PhotoPageItemState extends State<_PhotoPageItem> {
  late Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = widget.controller.bytesFor(widget.photo);
  }

  @override
  void didUpdateWidget(covariant _PhotoPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.uri != widget.photo.uri) {
      _bytesFuture = widget.controller.bytesFor(widget.photo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return InteractiveViewer(
            minScale: 0.6,
            maxScale: 4,
            child: Center(child: Image.memory(snapshot.data!)),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
