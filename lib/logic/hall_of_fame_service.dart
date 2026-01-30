import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_story_snapshot.dart';
import '../models/hall_of_fame_profile.dart';
import 'shenanigans_tracker.dart';

class HallOfFameService extends ChangeNotifier {
  static final HallOfFameService instance = HallOfFameService._();

  HallOfFameService._() {
    _loadProfiles();
  }

  static const String _prefsKey = 'hallOfFame.v1';
  final Map<String, HallOfFameProfile> _profiles = {};

  List<HallOfFameProfile> get allProfiles {
    final list = _profiles.values.toList();
    // Sort by most recently played, then total games
    list.sort((a, b) {
      final dateCmp = b.lastPlayed.compareTo(a.lastPlayed);
      if (dateCmp != 0) return dateCmp;
      return b.totalGames.compareTo(a.totalGames);
    });
    return list;
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr != null) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        for (final item in list) {
          final profile = HallOfFameProfile.fromJson(item);
          _profiles[profile.id] = profile;
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading Hall of Fame: $e');
      }
    }
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _profiles.values.map((p) => p.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(list));
    notifyListeners();
  }

  String _normalizeId(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }

  /// Ensures a profile exists for a player name. Returns true if created for the first time.
  Future<bool> registerPlayer(String name) async {
    final trimmed = name.trim();
    final id = _normalizeId(trimmed);

    final existing = _profiles[id];
    if (existing != null) {
      // Keep a single stable profile per normalized name, but allow the
      // display name to update (e.g., casing/spacing tweaks).
      if (trimmed.isNotEmpty && existing.name != trimmed) {
        _profiles[id] = existing.copyWith(name: trimmed);
        await _saveProfiles();
      }
      return false;
    }

    _profiles[id] = HallOfFameProfile(id: id, name: trimmed);
    await _saveProfiles();
    return true;
  }

  /// Process a completed game snapshot to update stats.
  /// This should be called when `GamesNightService` finishes a game.
  Future<void> processGameStats(
      GameStorySnapshot game, List<ShenaniganAward> singleGameAwards) async {
    bool changed = false;

    // 1. Identify Winner Alliance
    // The Snapshot keeps `winner` as a string (e.g. "The Dealers").
    final winnerAlliance = game.winner;

    // 2. Loop through players
    for (final p in game.players) {
      final id = _normalizeId(p.name);

      // Get or Create profile
      var profile = _profiles[id] ?? HallOfFameProfile(id: id, name: p.name);
      final trimmedName = p.name.trim();
      if (trimmedName.isNotEmpty && profile.name != trimmedName) {
        profile = profile.copyWith(name: trimmedName);
      }

      // Update core stats
      final int newGames = profile.totalGames + 1;

      // Determine Win/Loss
      // Player wins if their alliance matches the winning alliance
      // Note: alliances in snapshot might be "The Dealers" or "Dealers" etc.
      // We do a loose contain check or exact match.
      bool didWin = false;
      if (winnerAlliance != null) {
        final pAlliance = p.alliance.toLowerCase();
        final wAlliance = winnerAlliance.toLowerCase();
        // Simple logic: if player alliance is substring of winner or vice versa
        if (pAlliance.contains(wAlliance) || wAlliance.contains(pAlliance)) {
          didWin = true;
        }
        // Specific case: "The Fool" usually wins alone, so alliance might vary.
        // Assuming snapshot handles "winner" string correctly from engine.
      }

      final int newWins = profile.totalWins + (didWin ? 1 : 0);

      // Update Roles
      final updatedRoles = Map<String, int>.from(profile.roleStats);
      updatedRoles[p.roleName] = (updatedRoles[p.roleName] ?? 0) + 1;

      // Update Awards (Single Game Awards)
      final updatedAwards = Map<String, int>.from(profile.awardStats);

      // Find awards won by this player in this game
      final awardsWon = singleGameAwards.where((a) {
        // ShenaniganAward stores playerId or playerName.
        // For single game awards, it usually stores playerId from Engine.
        // We need to match it to p.id (StoryPlayerSnapshot.id)
        return a.playerId == p.id;
      });

      for (final award in awardsWon) {
        updatedAwards[award.title] = (updatedAwards[award.title] ?? 0) + 1;
      }

      // Update Profile
      _profiles[id] = profile.copyWith(
        totalGames: newGames,
        totalWins: newWins,
        roleStats: updatedRoles,
        awardStats: updatedAwards,
        lastPlayed: DateTime.now(),
      );
      changed = true;
    }

    if (changed) {
      await _saveProfiles();
    }
  }

  /// Deletes a profile
  Future<void> deleteProfile(String id) async {
    _profiles.remove(id);
    await _saveProfiles();
  }

  /// Merges one profile into another and deletes the source.
  ///
  /// Use this to fix typos/variants (e.g. "John" vs "Jon") while keeping a
  /// single accumulating stats profile.
  Future<void> mergeProfiles(
      {required String fromId, required String intoId}) async {
    if (fromId == intoId) return;

    final from = _profiles[fromId];
    final into = _profiles[intoId];
    if (from == null || into == null) return;

    final mergedRoleStats = Map<String, int>.from(into.roleStats);
    for (final entry in from.roleStats.entries) {
      mergedRoleStats[entry.key] =
          (mergedRoleStats[entry.key] ?? 0) + entry.value;
    }

    final mergedAwardStats = Map<String, int>.from(into.awardStats);
    for (final entry in from.awardStats.entries) {
      mergedAwardStats[entry.key] =
          (mergedAwardStats[entry.key] ?? 0) + entry.value;
    }

    final mergedLastPlayed = from.lastPlayed.isAfter(into.lastPlayed)
        ? from.lastPlayed
        : into.lastPlayed;

    _profiles[intoId] = into.copyWith(
      totalGames: into.totalGames + from.totalGames,
      totalWins: into.totalWins + from.totalWins,
      roleStats: mergedRoleStats,
      awardStats: mergedAwardStats,
      lastPlayed: mergedLastPlayed,
      // Keep the destination display name (user intent: "merge into").
    );

    _profiles.remove(fromId);
    await _saveProfiles();
  }
}
