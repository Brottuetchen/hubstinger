import 'package:flutter/material.dart';

class AppIcons {
  AppIcons._();

  static const home = Icons.home_rounded;
  static const services = Icons.widgets_rounded;
  static const newsletter = Icons.mail_outline_rounded;
  static const settings = Icons.settings_rounded;
  static const notification = Icons.notifications_none_rounded;
  static const wavingHand = Icons.waving_hand_rounded;

  static const streaming = Icons.play_circle_fill_rounded;
  static const movie = Icons.local_movies_rounded;
  static const episode = Icons.tv_rounded;
  static const watchtime = Icons.bar_chart_rounded;
  static const containers = Icons.dns_rounded;
  static const activeStreams = Icons.play_arrow_rounded;
  static const uptime = Icons.check_circle_rounded;
  static const nas = Icons.storage_rounded;
  static const proxmox = Icons.memory_rounded;
  static const requests = Icons.movie_filter_rounded;
  static const immich = Icons.photo_library_rounded;
  static const navidrome = Icons.music_note_rounded;

  static const login = Icons.home_rounded;
  static const authentik = Icons.vpn_key_rounded;
  static const archive = Icons.mail_rounded;
  static const back = Icons.arrow_back_ios_new_rounded;
  static const forward = Icons.chevron_right_rounded;
  static const up = Icons.keyboard_arrow_up_rounded;
  static const down = Icons.keyboard_arrow_down_rounded;

  static IconData resolve(String? key) {
    switch (key) {
      case 'home':
        return home;
      case 'services':
        return services;
      case 'newsletter':
        return newsletter;
      case 'settings':
        return settings;
      case 'streaming':
        return streaming;
      case 'movie':
      case 'jellyfin':
      case 'radarr':
        return movie;
      case 'episode':
      case 'sonarr':
        return episode;
      case 'watchtime':
        return watchtime;
      case 'containers':
      case 'portainer':
        return containers;
      case 'active_streams':
        return activeStreams;
      case 'uptime':
      case 'uptime_kuma':
        return uptime;
      case 'nas':
      case 'nextcloud':
        return nas;
      case 'proxmox':
        return proxmox;
      case 'requests':
      case 'jellyseerr':
        return requests;
      case 'immich':
        return immich;
      case 'navidrome':
        return navidrome;
      case 'tmdb':
        return Icons.theaters_rounded;
      case 'ollama':
        return Icons.smart_toy_rounded;
      case 'authentik':
        return authentik;
      case 'audiobookshelf':
        return Icons.headphones_rounded;
      case 'gitea':
        return Icons.code_rounded;
      case 'n8n':
        return Icons.account_tree_rounded;
      case 'paperless':
        return Icons.description_rounded;
      default:
        return Icons.extension_rounded;
    }
  }
}
