import 'package:flutter/material.dart';

// ─── Server Config ────────────────────────────────────────────────────────────
class ServerConfig {
  final String baseUrl;
  final String? tmdbApiKey;
  final String? jellyfinApiKey;
  final String? jellyseerrApiKey;

  const ServerConfig({
    required this.baseUrl,
    this.tmdbApiKey,
    this.jellyfinApiKey,
    this.jellyseerrApiKey,
  });

  factory ServerConfig.empty() => const ServerConfig(baseUrl: '');

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'tmdbApiKey': tmdbApiKey,
    'jellyfinApiKey': jellyfinApiKey,
    'jellyseerrApiKey': jellyseerrApiKey,
  };

  factory ServerConfig.fromJson(Map<String, dynamic> j) => ServerConfig(
    baseUrl: j['baseUrl'] ?? '',
    tmdbApiKey: j['tmdbApiKey'],
    jellyfinApiKey: j['jellyfinApiKey'],
    jellyseerrApiKey: j['jellyseerrApiKey'],
  );
}

// ─── Stream Session ───────────────────────────────────────────────────────────
class StreamSession {
  final String title;
  final String userName;
  final double progressPct;
  final String? posterUrl;
  final Color accentColor;
  final bool isMovie;

  const StreamSession({
    required this.title,
    required this.userName,
    required this.progressPct,
    this.posterUrl,
    required this.accentColor,
    this.isMovie = true,
  });
}

// ─── Media Item ───────────────────────────────────────────────────────────────
class MediaItem {
  final int id;
  final String title;
  final String? posterPath;
  final double? rating;
  final int? runtime;
  final String? overview;
  final String? releaseDate;
  final bool isMovie;
  final Color accentColor;
  final String? jellyseerrRequestUrl;

  const MediaItem({
    required this.id,
    required this.title,
    this.posterPath,
    this.rating,
    this.runtime,
    this.overview,
    this.releaseDate,
    this.isMovie = true,
    this.accentColor = const Color(0xFF7C3AED),
    this.jellyseerrRequestUrl,
  });

  String get posterUrl =>
      posterPath != null
          ? 'https://image.tmdb.org/t/p/w342$posterPath'
          : '';

  String get year => releaseDate?.substring(0, 4) ?? '';
}

// ─── Newsletter ───────────────────────────────────────────────────────────────
class Newsletter {
  final String title;
  final String date;
  final int weekNumber;
  final int itemCount;
  final Color accentColor;
  final List<MediaItem> items;

  const Newsletter({
    required this.title,
    required this.date,
    required this.weekNumber,
    required this.itemCount,
    required this.accentColor,
    required this.items,
  });
}

// ─── Watchtime ────────────────────────────────────────────────────────────────
class UserWatchtime {
  final String name;
  final String avatarChar;
  final double hours;
  final Color color;

  const UserWatchtime({
    required this.name,
    required this.avatarChar,
    required this.hours,
    required this.color,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────
class ServiceItem {
  final String name;
  final String emoji;
  final Color color;
  final bool isOnline;
  final String category;
  final String? url;

  const ServiceItem({
    required this.name,
    required this.emoji,
    required this.color,
    required this.isOnline,
    required this.category,
    this.url,
  });
}

// ─── Widget Layout ────────────────────────────────────────────────────────────
enum WidgetSize { small, medium, large, tall }

class WidgetSlot {
  final String id;
  final WidgetSize size;

  const WidgetSlot({required this.id, required this.size});

  Map<String, dynamic> toJson() => {'id': id, 'size': size.name};

  factory WidgetSlot.fromJson(Map<String, dynamic> j) => WidgetSlot(
    id: j['id'],
    size: WidgetSize.values.firstWhere((s) => s.name == j['size']),
  );
}
