import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../providers/chat_provider.dart';
import '../../domain/entities/chat_message.dart';

class SharedMediaView extends ConsumerStatefulWidget {
  final String channelName;
  final String? partnerId;

  const SharedMediaView({
    Key? key,
    required this.channelName,
    this.partnerId,
  }) : super(key: key);

  @override
  ConsumerState<SharedMediaView> createState() => _SharedMediaViewState();
}

class _SharedMediaViewState extends ConsumerState<SharedMediaView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Media'),
            Tab(text: 'Docs'),
            Tab(text: 'Links'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMediaTab(),
              _buildDocsTab(),
              _buildLinksTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaTab() {
    final mediaAsync = ref.watch(sharedMediaProvider((channelName: widget.channelName, partnerId: widget.partnerId)));
    return mediaAsync.when(skipLoadingOnReload: true, skipLoadingOnRefresh: true, 
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (messages) {
        final mediaMessages = messages.where((m) {
          final t = (m.fileType ?? '').toLowerCase();
          return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'avi', 'mkv'].contains(t);
        }).toList();

        if (mediaMessages.isEmpty) {
          return const Center(child: Text('No media shared yet.', style: TextStyle(color: Colors.grey)));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: mediaMessages.length,
          itemBuilder: (context, index) {
            final msg = mediaMessages[index];
            final url = msg.fileUrl!;
            final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains((msg.fileType ?? '').toLowerCase());
            final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains((msg.fileType ?? '').toLowerCase());

            return GestureDetector(
              onTap: () {
                url_launcher.launchUrl(Uri.parse(url));
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isImage)
                    Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                  else
                    Container(
                      color: Colors.grey.shade800,
                      child: Icon(LucideIcons.video, color: Colors.white),
                    ),
                  if (isVideo)
                    const Positioned(
                      bottom: 4,
                      right: 4,
                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDocsTab() {
    final mediaAsync = ref.watch(sharedMediaProvider((channelName: widget.channelName, partnerId: widget.partnerId)));
    return mediaAsync.when(skipLoadingOnReload: true, skipLoadingOnRefresh: true, 
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (messages) {
        final docMessages = messages.where((m) {
          final t = (m.fileType ?? '').toLowerCase();
          return !['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'avi', 'mkv'].contains(t);
        }).toList();

        if (docMessages.isEmpty) {
          return const Center(child: Text('No documents shared yet.', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docMessages.length,
          itemBuilder: (context, index) {
            final msg = docMessages[index];
            return ListTile(
              leading: Icon(LucideIcons.fileText, color: Colors.blue),
              title: Text(msg.fileName ?? 'Unknown file', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(DateFormat('MMM d, yyyy').format(msg.createdAt.toLocal())),
              onTap: () {
                if (msg.fileUrl != null) url_launcher.launchUrl(Uri.parse(msg.fileUrl!));
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLinksTab() {
    final linksAsync = ref.watch(sharedLinksProvider((channelName: widget.channelName, partnerId: widget.partnerId)));
    return linksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (messages) {
        if (messages.isEmpty) {
          return const Center(child: Text('No links shared yet.', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final urlRegex = RegExp(r'(https?:\/\/[^\s]+)');
            final matches = urlRegex.allMatches(msg.content);
            if (matches.isEmpty) return const SizedBox.shrink();

            final firstUrl = matches.first.group(0)!;

            return ListTile(
              leading: Icon(LucideIcons.link, color: Colors.blue),
              title: Text(firstUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.blue)),
              subtitle: Text(DateFormat('MMM d, yyyy').format(msg.createdAt.toLocal())),
              onTap: () {
                url_launcher.launchUrl(Uri.parse(firstUrl));
              },
            );
          },
        );
      },
    );
  }
}
