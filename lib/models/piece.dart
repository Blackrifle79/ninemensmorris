/// Represents a piece on the board
enum PieceType { white, black }

class Piece {
  final PieceType type;

  const Piece({required this.type});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Piece && runtimeType == other.runtimeType && type == other.type;

  @override
  int get hashCode => type.hashCode;

  @override
  String toString() => 'Piece(type: $type)';
}
