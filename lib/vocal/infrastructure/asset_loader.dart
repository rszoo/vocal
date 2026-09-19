// ./lib/vocal/infrastructure/asset_loader.dart

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../shared/domain/models.dart';

final class AssetLoader {
  const AssetLoader();

  static const assetDir = 'assets/pitches/';

  Future<List<String>> loadVideoIds() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    // assets/pitches/(11桁のID).json にマッチする正規表現パターン
    final pattern = RegExp(
      '^${RegExp.escape(assetDir)}([A-Za-z0-9_-]{11})\\.json\$',
      caseSensitive: false,
    );

    final ids = manifest
        .listAssets()
        .map(pattern.firstMatch)
        .whereType<RegExpMatch>()
        .map((match) => match.group(1)!)
        .toList();
    ids.sort();

    return ids;
  }

  Future<List<PitchSegment>> loadPitchEvents(String videoId) async {
    final path = '$assetDir$videoId.json';
    final text = await rootBundle.loadString(path);
    final decoded = jsonDecode(text);

    if (decoded is! List) {
      throw const FormatException('Pitch JSON must be an array.');
    }

    final events = decoded
        .whereType<Map>()
        .map((item) => PitchSegment.fromJson(Map<String, dynamic>.from(item)))
        // 無効データ（0以下の周波数や継続時間）を除外
        .where((event) => event.freq > 0 && event.period > 0)
        .toList();
    events.sort((a, b) => a.time.compareTo(b.time));

    return events;
  }
}
