import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../models/piece.dart';
import '../utils/app_styles.dart';
import 'mini_piece.dart';

class PieceCounter extends StatelessWidget {
  final GameModel gameModel;
  final String whiteName;
  final String blackName;
  final int? whiteRank;
  final int? blackRank;

  const PieceCounter({
    super.key,
    required this.gameModel,
    this.whiteName = 'White',
    this.blackName = 'Black',
    this.whiteRank,
    this.blackRank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppStyles.burgundy.withValues(alpha: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // White player
          Expanded(child: _buildPlayerSection(PieceType.white)),

          const SizedBox(width: 16),

          // Black player
          Expanded(child: _buildPlayerSection(PieceType.black)),
        ],
      ),
    );
  }

  Widget _buildPlayerSection(PieceType pieceType) {
    final bool isWhite = pieceType == PieceType.white;
    final String name = isWhite ? whiteName : blackName;
    final int? rank = isWhite ? whiteRank : blackRank;
    int piecesToPlace = isWhite
        ? gameModel.whitePiecesToPlace
        : gameModel.blackPiecesToPlace;
    int capturedPieces = _getCapturedPieces(pieceType);
    final statusText = _buildStatusText(piecesToPlace, capturedPieces);

    if (isWhite) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPieceIcon(isWhite: true),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  style: AppStyles.bodyText.copyWith(color: AppStyles.cream),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (rank != null) ...[
                const SizedBox(width: 6),
                _buildRankBadge(rank),
              ],
            ],
          ),
          if (statusText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                statusText,
                style: AppStyles.labelText.copyWith(
                  color: AppStyles.cream.withValues(alpha: 0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (rank != null) ...[
                _buildRankBadge(rank),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  name,
                  style: AppStyles.bodyText.copyWith(color: AppStyles.cream),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 6),
              const MiniPieceIcon(isWhite: false),
            ],
          ),
          if (statusText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 22, top: 2),
              child: Text(
                statusText,
                style: AppStyles.labelText.copyWith(
                  color: AppStyles.cream.withValues(alpha: 0.7),
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
        ],
      );
    }
  }

  String _buildStatusText(int piecesToPlace, int capturedPieces) {
    List<String> parts = [];
    if (gameModel.gamePhase == GamePhase.placing && piecesToPlace > 0) {
      parts.add('$piecesToPlace to place');
    }
    if (capturedPieces > 0) {
      parts.add('$capturedPieces lost');
    }
    return parts.isEmpty ? '' : parts.join(' · ');
  }

  int _getPiecesOnBoard(PieceType pieceType) {
    return gameModel.board.values
        .where((piece) => piece.type == pieceType)
        .length;
  }

  int _getCapturedPieces(PieceType pieceType) {
    int piecesToPlace = pieceType == PieceType.white
        ? gameModel.whitePiecesToPlace
        : gameModel.blackPiecesToPlace;
    int piecesOnBoard = _getPiecesOnBoard(pieceType);
    return 9 - piecesToPlace - piecesOnBoard;
  }

  Widget _buildRankBadge(int rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppStyles.cream.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppStyles.cream.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Text(
        '#$rank',
        style: TextStyle(
          fontFamily: AppStyles.fontBody,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppStyles.cream.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
