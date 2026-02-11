class LeaderboardEntry {
  final String id;
  final String username;
  final int score; // legacy cumulative score
  final double avgScore; // 0-100 rolling average (primary ranking metric)
  final int gamesPlayed;
  final double onlineScore;
  final int onlineGames;
  final double offlineScore;
  final int offlineGames;
  final int wins;
  final int losses;
  final int draws;

  LeaderboardEntry({
    required this.id,
    required this.username,
    required this.score,
    this.avgScore = 0,
    this.gamesPlayed = 0,
    this.onlineScore = 0,
    this.onlineGames = 0,
    this.offlineScore = 0,
    this.offlineGames = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> m) {
    return LeaderboardEntry(
      id: m['id']?.toString() ?? '',
      username: (m['username'] ?? m['name'] ?? '')?.toString() ?? '',
      score: _parseInt(m['score']),
      avgScore: _parseDouble(m['avg_score'], 0),
      gamesPlayed: _parseInt(m['games_played']),
      onlineScore: _parseDouble(m['online_score'], 0),
      onlineGames: _parseInt(m['online_games']),
      offlineScore: _parseDouble(m['offline_score'], 0),
      offlineGames: _parseInt(m['offline_games']),
      wins: _parseInt(m['wins']),
      losses: _parseInt(m['losses']),
      draws: _parseInt(m['draws']),
    );
  }

  /// Win-rate percentage (0-100). Returns 0 if no games played.
  double get winRate {
    final total = wins + losses + draws;
    if (total == 0) return 0;
    return (wins / total) * 100;
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic v, double fallback) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }
}
