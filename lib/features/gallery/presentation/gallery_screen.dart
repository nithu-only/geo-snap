import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/gallery_photo.dart';
import '../../../core/state/gallery_controller.dart';
import '../../../core/state/settings_controller.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _selectedFolder = '';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(displayTitle),
        actions: [
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
      body: RefreshIndicator(
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
            if (controller.loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (photos.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyGallery(),
              )
            else
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
                    (context, index) => _PhotoTile(photo: photos[index]),
                    childCount: photos.length,
                  ),
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo});

  final GalleryPhoto photo;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<GalleryController>();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PhotoDetailScreen(photo: photo)),
        ),
        child: Column(
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
      ),
    );
  }
}

class PhotoDetailScreen extends StatelessWidget {
  const PhotoDetailScreen({required this.photo, super.key});

  final GalleryPhoto photo;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<GalleryController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(photo.name),
        actions: [
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
                  Navigator.of(context).pop();
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: controller.bytesFor(photo),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return InteractiveViewer(
            minScale: 0.6,
            maxScale: 4,
            child: Center(child: Image.memory(snapshot.data!)),
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
