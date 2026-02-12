import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'leaderboard_service.dart';

/// Service for managing online game rooms
class GameRoomService {
  static final GameRoomService _instance = GameRoomService._internal();
  factory GameRoomService() => _instance;
  GameRoomService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  /// Track last opponent to avoid repeated matches
  String? _lastOpponentId;
  String? get lastOpponentId => _lastOpponentId;
  void setLastOpponent(String? opponentId) => _lastOpponentId = opponentId;

  /// Generate a random 6-character game code
  String _generateGameCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed confusing chars
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a new game room
  Future<GameRoom?> createRoom() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    // Clean up any old waiting/playing rooms for this user first
    try {
      await _client
          .from('game_rooms')
          .delete()
          .eq('host_id', user.id)
          .eq('status', 'waiting');

      // Also mark any stale "playing" games where this user is host as finished
      await _client
          .from('game_rooms')
          .update({
            'status': 'finished',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('host_id', user.id)
          .eq('status', 'playing');
    } catch (e) {
      // Ignore cleanup errors
    }

    // Get username from profile or email
    String username;
    try {
      final profile = await _client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
      username =
          profile?['username'] ?? user.email?.split('@').first ?? 'Player';
    } catch (e) {
      // Profile might not exist, use email
      username = user.email?.split('@').first ?? 'Player';
    }

    // Generate unique code
    String code = _generateGameCode();

    try {
      final response = await _client
          .from('game_rooms')
          .insert({
            'code': code,
            'host_id': user.id,
            'host_username': username,
            'status': 'waiting',
          })
          .select()
          .single();

      return GameRoom.fromJson(response);
    } catch (e) {
      // If code collision, try again with new code
      if (e.toString().contains('duplicate')) {
        code = _generateGameCode();
        final response = await _client
            .from('game_rooms')
            .insert({
              'code': code,
              'host_id': user.id,
              'host_username': username,
              'status': 'waiting',
            })
            .select()
            .single();
        return GameRoom.fromJson(response);
      }
      rethrow;
    }
  }

  /// Join a game room by code
  Future<GameRoomResult> joinRoom(String code) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return GameRoomResult.failure('You must be logged in');
    }

    // Find the room
    final roomData = await _client
        .from('game_rooms')
        .select()
        .eq('code', code.toUpperCase())
        .eq('status', 'waiting')
        .maybeSingle();

    if (roomData == null) {
      return GameRoomResult.failure('Game not found or already started');
    }

    final room = GameRoom.fromJson(roomData);

    // Can't join your own room
    if (room.hostId == user.id) {
      return GameRoomResult.failure('You cannot join your own game');
    }

    // Get username
    String username;
    try {
      final profile = await _client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
      username =
          profile?['username'] ?? user.email?.split('@').first ?? 'Player';
    } catch (e) {
      username = user.email?.split('@').first ?? 'Player';
    }

    // Join the room
    final updatedRoom = await _client
        .from('game_rooms')
        .update({
          'guest_id': user.id,
          'guest_username': username,
          'status': 'playing',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', room.id)
        .eq('status', 'waiting') // Ensure still waiting
        .select()
        .maybeSingle();

    if (updatedRoom == null) {
      return GameRoomResult.failure('Game is no longer available');
    }

    return GameRoomResult.success(GameRoom.fromJson(updatedRoom));
  }

  /// Get a room by ID
  Future<GameRoom?> getRoom(String roomId) async {
    final data = await _client
        .from('game_rooms')
        .select()
        .eq('id', roomId)
        .maybeSingle();

    return data != null ? GameRoom.fromJson(data) : null;
  }

  /// Subscribe to room changes
  /// Uses Supabase realtime with polling fallback for reliability
  Stream<GameRoom> subscribeToRoom(String roomId) {
    final controller = StreamController<GameRoom>.broadcast();

    // Track the last known status and game state to detect meaningful changes
    String? lastStatus;
    String? lastGameStateJson;

    void emitIfChanged(GameRoom room) {
      final gameStateJson = room.gameState?.toString();
      // Emit if status changed OR if game state changed
      if (lastStatus == null ||
          room.status != lastStatus ||
          gameStateJson != lastGameStateJson) {
        lastStatus = room.status;
        lastGameStateJson = gameStateJson;
        controller.add(room);
      }
    }

    // Realtime subscription
    final realtimeSubscription = _client
        .from('game_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .listen(
          (data) {
            if (data.isNotEmpty) {
              final room = GameRoom.fromJson(data.first);
              emitIfChanged(room);
            }
          },
          onError: (e) {
            // Realtime error - polling fallback will handle it
          },
        );

    // Do an immediate poll to get current state right away
    Future(() async {
      try {
        final data = await _client
            .from('game_rooms')
            .select()
            .eq('id', roomId)
            .maybeSingle();

        if (data != null) {
          final room = GameRoom.fromJson(data);
          emitIfChanged(room);
        }
      } catch (e) {
        // Initial poll error - polling timer will retry
      }
    });

    // Polling fallback - check every 1 second for faster updates
    final pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final data = await _client
            .from('game_rooms')
            .select()
            .eq('id', roomId)
            .maybeSingle();

        if (data != null) {
          final room = GameRoom.fromJson(data);
          emitIfChanged(room);
        }
      } catch (e) {
        // Polling error - will retry on next interval
      }
    });

    // Clean up when the stream is cancelled
    controller.onCancel = () {
      realtimeSubscription.cancel();
      pollingTimer.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Update game state
  Future<void> updateGameState(
    String roomId,
    Map<String, dynamic> gameState,
  ) async {
    await _client
        .from('game_rooms')
        .update({
          'game_state': gameState,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', roomId);
  }

  /// End the game and optionally record a game summary that can be used to
  /// update player leaderboard entries.
  Future<void> endGame(
    String roomId,
    String? winnerId, {
    Map<String, dynamic>? gameSummary,
  }) async {
    // Build the update payload — always include status, winner, timestamp
    final Map<String, dynamic> updatePayload = {
      'status': 'finished',
      'winner_id': winnerId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Try with game_summary column first; fall back without it
    try {
      updatePayload['game_summary'] = gameSummary;
      await _client.from('game_rooms').update(updatePayload).eq('id', roomId);
    } catch (e) {
      final err = e.toString();
      if (err.contains('game_summary')) {
        // Column doesn't exist yet — retry without it
        updatePayload.remove('game_summary');
        try {
          await _client
              .from('game_rooms')
              .update(updatePayload)
              .eq('id', roomId);
        } catch (e2) {
          if (e2.toString().contains('winner_id') ||
              e2.toString().contains('foreign key')) {
            // winner_id FK violation (e.g. bot ID) — finish without winner_id
            updatePayload.remove('winner_id');
            await _client
                .from('game_rooms')
                .update(updatePayload)
                .eq('id', roomId);
          } else {
            rethrow;
          }
        }
      } else if (err.contains('winner_id') || err.contains('foreign key')) {
        // winner_id FK violation (e.g. bot ID) — finish without winner_id
        updatePayload.remove('winner_id');
        updatePayload.remove('game_summary');
        await _client.from('game_rooms').update(updatePayload).eq('id', roomId);
      } else {
        rethrow;
      }
    }

    // Note: Leaderboard updates are now handled by ScoringService.recordScore()
    // called from the game screens, so we no longer apply them here to avoid
    // double-counting.
  }

  /// Leave/cancel a game room
  Future<void> leaveRoom(String roomId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final room = await getRoom(roomId);
    if (room == null) return;

    if (room.hostId == user.id && room.status == 'waiting') {
      // Host cancels waiting room - delete it
      await _client.from('game_rooms').delete().eq('id', roomId);
    } else if (room.status == 'playing') {
      // Player leaves during game - other player wins
      final winnerId = room.hostId == user.id ? room.guestId : room.hostId;
      await endGame(roomId, winnerId);
    }
  }

  /// Get list of waiting rooms (for browse feature)
  Future<List<GameRoom>> getWaitingRooms() async {
    final data = await _client
        .from('game_rooms')
        .select()
        .eq('status', 'waiting')
        .order('created_at', ascending: false)
        .limit(20);

    return (data as List).map((json) => GameRoom.fromJson(json)).toList();
  }

  /// Get number of players currently waiting for a match (excludes self)
  Future<int> getWaitingPlayerCount() async {
    final user = _client.auth.currentUser;
    final data = await _client
        .from('game_rooms')
        .select('id')
        .eq('status', 'waiting');

    final rooms = data as List;
    if (user == null) return rooms.length;
    // Exclude own waiting rooms
    return rooms.where((r) => r['id'] != null).length;
  }

  /// Quick-match: skill-based matchmaking that prefers opponents of similar ranking.
  /// Falls back to any available opponent if no similar-skill match is found.
  ///
  /// [avoidOpponentId] - Optional ID of a player to avoid matching with (e.g. last opponent)
  ///
  /// Returns a [QuickMatchResult] with the room and whether we are the host
  /// (i.e. we created a new room and need to wait).
  Future<QuickMatchResult> quickMatch({String? avoidOpponentId}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return QuickMatchResult.failure('You must be logged in');
    }

    // Clean up any stale rooms for this user first
    try {
      await _client
          .from('game_rooms')
          .delete()
          .eq('host_id', user.id)
          .eq('status', 'waiting');
    } catch (_) {}

    // Get my skill level for matchmaking
    final myRanking = await LeaderboardService().getPlayerRanking(user.id);
    final myScore = myRanking['score'] as double;
    final myGames = myRanking['games'] as int;

    // If I'm new (< 3 games), match with other new players or similar scores
    final isNewPlayer = myGames < 3;

    // ─── Look for human opponents FIRST ───────────────────────────────
    // Look for waiting rooms (no FK join — fetch leaderboard separately)
    final waitingData = await _client
        .from('game_rooms')
        .select('*')
        .eq('status', 'waiting')
        .neq('host_id', user.id)
        .order('created_at', ascending: true);

    final waitingRooms = waitingData as List;

    // Build a map of host_id → leaderboard stats
    final hostIds = waitingRooms
        .map((r) => r['host_id'] as String?)
        .where((id) => id != null)
        .toSet()
        .toList();
    final Map<String, Map<String, dynamic>> leaderboardMap = {};
    if (hostIds.isNotEmpty) {
      final lbData = await _client
          .from('leaderboard')
          .select('id, online_score, online_games')
          .inFilter('id', hostIds);
      for (final row in (lbData as List)) {
        leaderboardMap[row['id'] as String] = row;
      }
    }

    // Check which hosts are bots so we can prefer humans
    Set<String> botHostIds = {};
    if (hostIds.isNotEmpty) {
      try {
        final profiles = await _client
            .from('profiles')
            .select('id, is_bot')
            .inFilter('id', hostIds);
        for (final p in (profiles as List)) {
          if (p['is_bot'] == true) {
            botHostIds.add(p['id'] as String);
          }
        }
      } catch (_) {}
    }

    // Filter to human-hosted rooms only for first pass
    // Also exclude the opponent we want to avoid if specified
    final humanWaitingRooms = waitingRooms
        .where((r) => !botHostIds.contains(r['host_id']))
        .where(
          (r) => avoidOpponentId == null || r['host_id'] != avoidOpponentId,
        )
        .toList();

    if (humanWaitingRooms.isNotEmpty) {
      GameRoom? bestMatch;
      double bestScoreDiff = double.infinity;

      // Find the best skill match among humans
      for (final roomData in humanWaitingRooms) {
        final hostId = roomData['host_id'] as String?;
        final lb = hostId != null ? leaderboardMap[hostId] : null;
        final hostScore = (lb?['online_score'] as num?)?.toDouble() ?? 50.0;
        final hostGames = (lb?['online_games'] as int?) ?? 0;
        final hostIsNew = hostGames < 3;

        // Prefer matching new players with new players
        if (isNewPlayer && hostIsNew) {
          bestMatch = GameRoom.fromJson(roomData);
          break;
        }

        // For experienced players, prefer similar skill levels
        if (!isNewPlayer && !hostIsNew) {
          final scoreDiff = (hostScore - myScore).abs();

          // Excellent match: within 10 points
          if (scoreDiff <= 10) {
            bestMatch = GameRoom.fromJson(roomData);
            break;
          }

          // Good match: within 20 points
          if (scoreDiff <= 20 && scoreDiff < bestScoreDiff) {
            bestMatch = GameRoom.fromJson(roomData);
            bestScoreDiff = scoreDiff;
          }
        }
      }

      // If no good skill match found, take the oldest human room
      if (bestMatch == null && humanWaitingRooms.isNotEmpty) {
        bestMatch = GameRoom.fromJson(humanWaitingRooms.first);
      }

      if (bestMatch != null) {
        final joinResult = await joinRoom(bestMatch.code);
        if (joinResult.isSuccess && joinResult.room != null) {
          return QuickMatchResult.matched(joinResult.room!);
        }
      }
    }

    // ─── No humans available — create waiting room and wait briefly ───
    // Give other humans a chance to find us before falling back to bots
    final waitingRoom = await createRoom();
    if (waitingRoom != null) {
      // Wait up to 12 seconds for a human to join, polling every 2 seconds
      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(seconds: 2));

        // Check if someone joined our room
        try {
          final roomData = await _client
              .from('game_rooms')
              .select('*')
              .eq('id', waitingRoom.id)
              .maybeSingle();

          if (roomData != null) {
            final room = GameRoom.fromJson(roomData);
            if (room.guestId != null && room.status == 'playing') {
              // A human joined!
              return QuickMatchResult.matched(room);
            }
          } else {
            // Room was deleted (maybe by another process)
            break;
          }
        } catch (_) {
          break;
        }
      }

      // No human joined - clean up waiting room before bot fallback
      try {
        await _client.from('game_rooms').delete().eq('id', waitingRoom.id);
      } catch (_) {}
    }

    // ─── Fall back to bots ────────────────────────────────────────────
    // Bots run locally as AI opponents but still update the online leaderboard
    try {
      final botsData = await _client
          .from('profiles')
          .select('id, username')
          .eq('is_bot', true)
          .eq('is_online', true)
          .limit(50);

      final bots = botsData as List;
      if (bots.isNotEmpty) {
        // Get leaderboard data for these bots
        final botIds = bots.map((b) => b['id'] as String).toList();
        final botLbData = await _client
            .from('leaderboard')
            .select('id, online_score, online_games')
            .inFilter('id', botIds);

        final botLeaderboard = <String, Map<String, dynamic>>{};
        for (final row in (botLbData as List)) {
          botLeaderboard[row['id'] as String] = row;
        }

        // Find best skill-matched bot
        Map<String, dynamic>? bestBot;
        double bestScoreDiff = double.infinity;

        for (final bot in bots) {
          final botId = bot['id'] as String;

          // Skip the bot we want to avoid (e.g., last opponent)
          if (avoidOpponentId != null && botId == avoidOpponentId) {
            continue;
          }

          final lb = botLeaderboard[botId];
          final botScore = (lb?['online_score'] as num?)?.toDouble() ?? 50.0;
          final botGames = (lb?['online_games'] as int?) ?? 0;
          final botIsNew = botGames < 3;

          // Prefer matching new players with new bots
          if (isNewPlayer && botIsNew) {
            bestBot = bot;
            break;
          }

          // For experienced players, prefer similar skill levels
          final scoreDiff = (botScore - myScore).abs();
          if (scoreDiff < bestScoreDiff) {
            bestBot = bot;
            bestScoreDiff = scoreDiff;
          }
        }

        if (bestBot != null) {
          final botId = bestBot['id'] as String;
          final botUsername = bestBot['username'] as String? ?? 'Bot';
          final lb = botLeaderboard[botId];

          // Get bot's rank
          int? botRank;
          try {
            final rankData = await LeaderboardService().getPlayerRanking(botId);
            botRank = rankData['rank'] as int?;
          } catch (_) {}

          // Determine difficulty based on bot's score
          final botScore = (lb?['online_score'] as num?)?.toDouble() ?? 50.0;
          String difficulty;
          if (botScore >= 70) {
            difficulty = 'hard';
          } else if (botScore >= 55) {
            difficulty = 'medium';
          } else {
            difficulty = 'easy';
          }

          return QuickMatchResult.botMatch(
            botId: botId,
            botUsername: botUsername,
            botRank: botRank,
            botDifficulty: difficulty,
          );
        }
      }
    } catch (_) {
      // Bot matching failed
    }

    // No opponent found (no humans joined, no bots available)
    return QuickMatchResult.failure(
      'No opponents available. Please try again.',
    );
  }
}

/// Model for a game room
class GameRoom {
  final String id;
  final String code;
  final String hostId;
  final String? guestId;
  final String hostUsername;
  final String? guestUsername;
  final String status;
  final String? winnerId;
  final Map<String, dynamic>? gameState;
  final DateTime createdAt;
  final DateTime updatedAt;

  GameRoom({
    required this.id,
    required this.code,
    required this.hostId,
    this.guestId,
    required this.hostUsername,
    this.guestUsername,
    required this.status,
    this.winnerId,
    this.gameState,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      id: json['id'],
      code: json['code'],
      hostId: json['host_id'],
      guestId: json['guest_id'],
      hostUsername: json['host_username'] ?? 'Player 1',
      guestUsername: json['guest_username'],
      status: json['status'],
      winnerId: json['winner_id'],
      gameState: json['game_state'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  bool get isWaiting => status == 'waiting';
  bool get isPlaying => status == 'playing';
  bool get isFinished => status == 'finished';
}

/// Result class for room operations
class GameRoomResult {
  final bool isSuccess;
  final String? message;
  final GameRoom? room;

  GameRoomResult._({required this.isSuccess, this.message, this.room});

  factory GameRoomResult.success(GameRoom room) {
    return GameRoomResult._(isSuccess: true, room: room);
  }

  factory GameRoomResult.failure(String message) {
    return GameRoomResult._(isSuccess: false, message: message);
  }
}

/// Result of a quick-match attempt
class QuickMatchResult {
  /// 'matched' = joined an existing room, 'waiting' = created room & waiting,
  /// 'bot_match' = matched with a bot (run locally), 'error' = something went wrong
  final String status;
  final GameRoom? room;
  final String? message;

  /// Bot info when status is 'bot_match'
  final String? botId;
  final String? botUsername;
  final int? botRank;
  final String? botDifficulty;

  QuickMatchResult._({
    required this.status,
    this.room,
    this.message,
    this.botId,
    this.botUsername,
    this.botRank,
    this.botDifficulty,
  });

  /// We joined an existing room — game is ready to start
  factory QuickMatchResult.matched(GameRoom room) {
    return QuickMatchResult._(status: 'matched', room: room);
  }

  /// We created a room — waiting for someone to join
  factory QuickMatchResult.waiting(GameRoom room) {
    return QuickMatchResult._(status: 'waiting', room: room);
  }

  /// Matched with a bot — run game locally with AI
  factory QuickMatchResult.botMatch({
    required String botId,
    required String botUsername,
    int? botRank,
    String? botDifficulty,
  }) {
    return QuickMatchResult._(
      status: 'bot_match',
      botId: botId,
      botUsername: botUsername,
      botRank: botRank,
      botDifficulty: botDifficulty,
    );
  }

  factory QuickMatchResult.failure(String message) {
    return QuickMatchResult._(status: 'error', message: message);
  }

  bool get isMatched => status == 'matched';
  bool get isWaiting => status == 'waiting';
  bool get isBotMatch => status == 'bot_match';
  bool get isError => status == 'error';
}
