import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed_plus/webfeed_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  RssFeed? _feed;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    try {
      final response = await http.get(Uri.parse('https://fitnessvolt.com/category/powerlifting/feed/'));
      if (response.statusCode == 200) {
        final feed = RssFeed.parse(response.body);
        if (mounted) {
          setState(() {
            _feed = feed;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando noticias: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openArticle(String? url) async {
    if (url == null || url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Busca la imagen en los distintos formatos que puede usar el RSS
  String? _extractImageUrl(RssItem item) {
    if (item.enclosure?.url != null) return item.enclosure!.url;
    if (item.media?.contents != null && item.media!.contents!.isNotEmpty) {
      return item.media!.contents!.first.url;
    }
    if (item.media?.thumbnails != null && item.media!.thumbnails!.isNotEmpty) {
      return item.media!.thumbnails!.first.url;
    }
    if (item.content?.images.isNotEmpty == true) return item.content!.images.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
    }
    
    if (_feed == null || _feed!.items == null || _feed!.items!.isEmpty) {
      return const Center(child: Text('No se pudieron cargar las noticias.', style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _feed!.items!.length,
      itemBuilder: (context, index) {
        final item = _feed!.items![index];
        final imageUrl = _extractImageUrl(item);

        return Card(
          color: const Color(0xFF2C2C2C),
          margin: const EdgeInsets.only(bottom: 16),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _openArticle(item.link),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null)
                  Image.network(
                    imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      color: const Color(0xFF1E1E1E),
                      child: const Icon(Icons.broken_image, color: Colors.white24, size: 50),
                    ),
                  )
                else
                  Container(
                    height: 120,
                    color: const Color(0xFF1E1E1E),
                    width: double.infinity,
                    child: const Icon(Icons.article, color: Colors.orangeAccent, size: 40),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title ?? 'Sin título',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.dc?.creator ?? 'Redacción',
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const Icon(Icons.open_in_new, color: Colors.white54, size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}