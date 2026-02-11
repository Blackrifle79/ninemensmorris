import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';
import '../services/auth_service.dart';
import '../models/leaderboard_entry.dart';
import '../utils/app_styles.dart';
import '../widgets/app_footer.dart';
import 'profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _service = LeaderboardService();
  bool _isLoading = true;
  String? _error;
  List<LeaderboardEntry> _entries = [];
  bool _showAroundMe = false; // Toggle between leaders and around me
  int _aroundMeStartRank = 1; // Starting rank for around me view

  // Current user's data
  LeaderboardEntry? _myEntry;
  int? _myRank;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = AuthService().currentUser;
      LeaderboardEntry? myEntry;
      int? myRank;
      List<LeaderboardEntry> entries;

      if (user != null) {
        final ranking = await _service.getPlayerRanking(user.id);
        myRank = ranking['rank'] as int?;

        if (_showAroundMe && myRank != null) {
          // Fetch players around me
          entries = await _service.fetchAroundPlayer(user.id, range: 10);
          
          // Find my entry in the list
          final idx = entries.indexWhere((e) => e.id == user.id);
          if (idx >= 0) {
            // Calculate the starting rank for the around-me view
            _aroundMeStartRank = (myRank - idx).clamp(1, 99999);
            myEntry = entries[idx];
          } else {
            // Player not found in results - fall back to showing their entry at the top
            _aroundMeStartRank = 1;
          }
        } else {
          // Fetch top leaders
          entries = await _service.fetchTop(limit: 50);

          // Check if user is in the top 50
          final idx = entries.indexWhere((e) => e.id == user.id);
          if (idx >= 0) {
            myEntry = entries[idx];
          } else {
            // Fetch user's entry separately
            final myData = await _service.fetchPlayerEntry(user.id);
            if (myData != null) {
              myEntry = myData;
            }
          }
        }
      } else {
        entries = await _service.fetchTop(limit: 50);
      }

      setState(() {
        _entries = entries;
        _myEntry = myEntry;
        _myRank = myRank;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load leaderboard';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppStyles.burgundy.withValues(alpha: 0.8),
        elevation: 0,
        foregroundColor: AppStyles.cream,
        iconTheme: const IconThemeData(color: AppStyles.cream),
        title: const Text('Leaderboard', style: AppStyles.headingMediumLight),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Tavern background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/tavern.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Parchment overlay
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage(
                  'assets/DD Grunge Texture 90878_DD-Grunge-Texture-90878-Preview.jpg',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.7),
                  BlendMode.dstIn,
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppStyles.cream,
                            ),
                          )
                        : _error != null
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    _error!,
                                    style: AppStyles.bodyTextLight,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _entries.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'No leaderboard entries yet',
                                    style: AppStyles.bodyTextLight,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _showAroundMe
                                ? _entries.length + 1  // +1 for toggle button
                                : _entries.length + (_myEntry != null ? 1 : 0),
                            itemBuilder: (context, index) {
                              // In around-me mode, show toggle button first
                              if (_showAroundMe) {
                                if (index == 0) {
                                  return _buildToggleButton();
                                }
                                final entryIndex = index - 1;
                                final e = _entries[entryIndex];
                                final rank = _aroundMeStartRank + entryIndex;
                                final isMe = e.id == AuthService().currentUser?.id;
                                return _buildLeaderboardTile(e, rank, highlight: isMe);
                              }
                              
                              // In leaders mode, show player's tile at the top
                              if (_myEntry != null && index == 0) {
                                return _buildMyTile();
                              }
                              final entryIndex = _myEntry != null
                                  ? index - 1
                                  : index;
                              final e = _entries[entryIndex];
                              final rank = entryIndex + 1;
                              return _buildLeaderboardTile(e, rank);
                            },
                          ),
                  ),
                ),
                const AppFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the current player's tile with cream background and toggle button
  Widget _buildMyTile() {
    final e = _myEntry!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: AppStyles.cream.withValues(alpha: 0.85)),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 50,
                child: Text(
                  _myRank != null ? '#$_myRank' : '—',
                  style: const TextStyle(
                    fontFamily: AppStyles.fontBody,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.darkBrown,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppStyles.burgundy,
                child: Text(
                  e.username.isNotEmpty ? e.username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppStyles.cream,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name & stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.username.isNotEmpty ? e.username : 'Player',
                      style: AppStyles.bodyTextBold,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${e.onlineGames} online game${e.onlineGames == 1 ? '' : 's'}',
                      style: AppStyles.labelText,
                    ),
                  ],
                ),
              ),
              // Online Average Score
              Text(
                e.onlineScore > 0 ? e.onlineScore.toStringAsFixed(1) : 'N/A',
                style: const TextStyle(
                  fontFamily: AppStyles.fontBody,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.darkBrown,
                ),
              ),
            ],
          ),
        ),
        // Toggle button
        GestureDetector(
          onTap: () {
            setState(() {
              _showAroundMe = !_showAroundMe;
            });
            _load();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppStyles.burgundy.withValues(alpha: 0.85),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showAroundMe ? Icons.emoji_events : Icons.people,
                  color: AppStyles.cream,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _showAroundMe ? 'Show Leaders' : 'Show Around Me',
                  style: const TextStyle(
                    fontFamily: AppStyles.fontBody,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.cream,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Build just the toggle button for around-me mode header
  Widget _buildToggleButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _showAroundMe = !_showAroundMe;
            });
            _load();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppStyles.burgundy.withValues(alpha: 0.85),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showAroundMe ? Icons.emoji_events : Icons.people,
                  color: AppStyles.cream,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _showAroundMe ? 'Show Leaders' : 'Show Around Me',
                  style: const TextStyle(
                    fontFamily: AppStyles.fontBody,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.cream,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Build a standard leaderboard tile
  Widget _buildLeaderboardTile(LeaderboardEntry e, int rank, {bool highlight = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: highlight 
            ? AppStyles.cream.withValues(alpha: 0.85)
            : AppStyles.surface.withValues(alpha: 0.85),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 50,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: highlight ? AppStyles.darkBrown : AppStyles.cream,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: highlight ? AppStyles.burgundy : AppStyles.green,
            child: Text(
              e.username.isNotEmpty ? e.username[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppStyles.cream,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name & stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.username.isNotEmpty ? e.username : 'Player',
                  style: highlight ? AppStyles.bodyTextBold : AppStyles.bodyTextBoldLight,
                ),
                const SizedBox(height: 2),
                Text(
                  '${e.onlineGames} online game${e.onlineGames == 1 ? '' : 's'}',
                  style: highlight ? AppStyles.labelText : AppStyles.labelTextLight,
                ),
              ],
            ),
          ),
          // Online Average Score
          Text(
            e.onlineScore > 0 ? e.onlineScore.toStringAsFixed(1) : 'N/A',
            style: TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: highlight ? AppStyles.darkBrown : AppStyles.cream,
            ),
          ),
        ],
      ),
    );
  }
}
