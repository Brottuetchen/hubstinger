import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/providers.dart';
import '../../../services/api_service.dart';
import '../../../widgets/glass/glass_card.dart';

const _typeColors = {
  'Movie':   AppColors.blue,
  'Episode': AppColors.rose,
};

const _typeEmoji = {
  'Movie':   '🎬',
  'Episode': '📺',
};

class RecentlyWidget extends ConsumerWidget {
  const RecentlyWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentlyAddedProvider);

    return GlassCard(
      weight: GlassWeight.mid,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NEU IN JELLYFIN',
            style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppColors.white35, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          recentAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan)),
            error: (e, _) => Text('Fehler: $e',
              style: const TextStyle(fontSize: 12, color: Colors.white38)),
            data: (data) {
              final items = (data['items'] as List?) ?? [];
              if (items.isEmpty) {
                return const Center(
                  child: Text('Keine neuen Medien',
                    style: TextStyle(fontSize: 13, color: Colors.white30)));
              }
              return Column(
                children: items.take(4).toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value as Map<String, dynamic>;
                  final type = item['type'] as String? ?? 'Movie';
                  final color = _typeColors[type] ?? AppColors.violet;
                  final emoji = _typeEmoji[type] ?? '🎬';
                  final added = item['added'] as String? ?? '';
                  final itemId = item['id'] as String?;
                  final hasImage = item['has_image'] as bool? ?? false;

                  return Column(children: [
                    if (i > 0) Divider(color: Colors.white.withOpacity(0.06), height: 18),
                    Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 38, height: 54,
                          child: (hasImage && itemId != null)
                            ? _JellyfinThumbnail(itemId: itemId, color: color)
                            : Container(
                                color: color.withOpacity(0.15),
                                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18)))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['title'] ?? '',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                        Text('$type${added.isNotEmpty ? ' · $added' : ''}',
                          style: TextStyle(fontSize: 11, color: AppColors.white35)),
                      ])),
                      GlassCard(borderRadius: 8, weight: GlassWeight.thin,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: const Text('›', style: TextStyle(fontSize: 16, color: Colors.white30))),
                    ]),
                  ]);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JellyfinThumbnail extends StatefulWidget {
  final String itemId;
  final Color color;
  const _JellyfinThumbnail({required this.itemId, required this.color});

  @override
  State<_JellyfinThumbnail> createState() => _JellyfinThumbnailState();
}

class _JellyfinThumbnailState extends State<_JellyfinThumbnail> {
  String? _url;
  Map<String, String>? _headers;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final url = await ApiService.instance.jellyfinImageUrl(widget.itemId, width: 100);
    final headers = await ApiService.instance.imageHeaders();
    if (mounted) setState(() { _url = url; _headers = headers; });
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null) {
      return Container(
        color: widget.color.withOpacity(0.15),
        child: const Center(child: SizedBox(width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38))));
    }
    return CachedNetworkImage(
      imageUrl: _url!,
      httpHeaders: _headers,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: widget.color.withOpacity(0.15)),
      errorWidget: (_, __, ___) => Container(
        color: widget.color.withOpacity(0.15),
        child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white24, size: 18))),
    );
  }
}
