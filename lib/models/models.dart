import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Neon stage palette available for pads.
const List<Color> kPadPalette = [
  Color(0xFF00E5FF), // cyan
  Color(0xFF1DE9B6), // teal
  Color(0xFF69F0AE), // green
  Color(0xFFFFD740), // amber
  Color(0xFFFF6E40), // orange
  Color(0xFFFF4081), // pink
  Color(0xFFB388FF), // violet
  Color(0xFF448AFF), // blue
];

Color colorFromHex(String hex) =>
    Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);

String hexFromColor(Color c) =>
    '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Configuration of a single performance pad.
class PadConfig {
  PadConfig({
    String? id,
    this.name = '',
    this.audioPath,
    this.volume = 1.0,
    this.loop = true,
    this.fadeInMs = 1500,
    this.fadeOutMs = 2500,
    String? colorHex,
  })  : id = id ?? _uuid.v4(),
        colorHex = colorHex ?? hexFromColor(kPadPalette[0]);

  final String id;
  String name;
  String? audioPath;
  double volume;
  bool loop;
  int fadeInMs;
  int fadeOutMs;
  String colorHex;

  bool get isAssigned => audioPath != null && audioPath!.isNotEmpty;
  Color get color => colorFromHex(colorHex);

  String get displayName {
    if (name.isNotEmpty) return name;
    if (isAssigned) {
      final segments = audioPath!.split(RegExp(r'[/\\]'));
      final file = segments.isEmpty ? audioPath! : segments.last;
      final dot = file.lastIndexOf('.');
      return dot > 0 ? file.substring(0, dot) : file;
    }
    return 'Empty';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'audioPath': audioPath,
        'volume': volume,
        'loop': loop,
        'fadeInMs': fadeInMs,
        'fadeOutMs': fadeOutMs,
        'colorHex': colorHex,
      };

  factory PadConfig.fromJson(Map<String, dynamic> j) => PadConfig(
        id: j['id'] as String?,
        name: (j['name'] as String?) ?? '',
        audioPath: j['audioPath'] as String?,
        volume: (j['volume'] as num?)?.toDouble() ?? 1.0,
        loop: (j['loop'] as bool?) ?? true,
        fadeInMs: (j['fadeInMs'] as num?)?.toInt() ?? 1500,
        fadeOutMs: (j['fadeOutMs'] as num?)?.toInt() ?? 2500,
        colorHex: j['colorHex'] as String?,
      );
}

/// A group: a named page of 8 pads.
class GroupConfig {
  GroupConfig({String? id, required this.name, List<PadConfig>? pads})
      : id = id ?? _uuid.v4(),
        pads = pads ??
            List.generate(8, (i) {
              final p = PadConfig();
              p.colorHex = hexFromColor(kPadPalette[i % kPadPalette.length]);
              return p;
            });

  final String id;
  String name;
  final List<PadConfig> pads;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pads': pads.map((p) => p.toJson()).toList(),
      };

  factory GroupConfig.fromJson(Map<String, dynamic> j) => GroupConfig(
        id: j['id'] as String?,
        name: (j['name'] as String?) ?? 'Group',
        pads: ((j['pads'] as List?) ?? [])
            .map((p) => PadConfig.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

/// A bank: 10 groups, labelled A–J.
class BankConfig {
  BankConfig({required this.letter, List<GroupConfig>? groups})
      : groups = groups ??
            List.generate(10, (i) => GroupConfig(name: '$letter${i + 1}'));

  final String letter;
  final List<GroupConfig> groups;

  Map<String, dynamic> toJson() => {
        'letter': letter,
        'groups': groups.map((g) => g.toJson()).toList(),
      };

  factory BankConfig.fromJson(Map<String, dynamic> j) => BankConfig(
        letter: (j['letter'] as String?) ?? 'A',
        groups: ((j['groups'] as List?) ?? [])
            .map((g) => GroupConfig.fromJson(g as Map<String, dynamic>))
            .toList(),
      );
}

/// A complete worship set: 10 banks (A–J) of 10 groups of 8 pads.
class WorshipSet {
  WorshipSet({String? id, required this.name, List<BankConfig>? banks, DateTime? createdAt, DateTime? updatedAt})
      : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        banks = banks ??
            List.generate(
                10, (i) => BankConfig(letter: String.fromCharCode(65 + i)));

  final String id;
  String name;
  final List<BankConfig> banks;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'banks': banks.map((b) => b.toJson()).toList(),
      };

  factory WorshipSet.fromJson(Map<String, dynamic> j) => WorshipSet(
        id: j['id'] as String?,
        name: (j['name'] as String?) ?? 'Untitled Set',
        createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? ''),
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? ''),
        banks: ((j['banks'] as List?) ?? [])
            .map((b) => BankConfig.fromJson(b as Map<String, dynamic>))
            .toList(),
      );

  String encode() => jsonEncode(toJson());
  factory WorshipSet.decode(String s) =>
      WorshipSet.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// Global app settings.
class AppSettings {
  AppSettings({
    this.bufferSize = 256,
    this.sampleRate = 48000,
    this.hapticsEnabled = true,
    this.keepScreenOn = true,
    this.accentHex = '#00E5FF',
    this.confirmPanic = false,
  });

  int bufferSize; // frames per audio callback — lower = lower latency
  int sampleRate;
  bool hapticsEnabled;
  bool keepScreenOn;
  String accentHex;
  bool confirmPanic;

  Color get accent => colorFromHex(accentHex);

  Map<String, dynamic> toJson() => {
        'bufferSize': bufferSize,
        'sampleRate': sampleRate,
        'hapticsEnabled': hapticsEnabled,
        'keepScreenOn': keepScreenOn,
        'accentHex': accentHex,
        'confirmPanic': confirmPanic,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        bufferSize: (j['bufferSize'] as num?)?.toInt() ?? 256,
        sampleRate: (j['sampleRate'] as num?)?.toInt() ?? 48000,
        hapticsEnabled: (j['hapticsEnabled'] as bool?) ?? true,
        keepScreenOn: (j['keepScreenOn'] as bool?) ?? true,
        accentHex: (j['accentHex'] as String?) ?? '#00E5FF',
        confirmPanic: (j['confirmPanic'] as bool?) ?? false,
      );
}
