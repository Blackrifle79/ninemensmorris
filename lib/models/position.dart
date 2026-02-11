/// Represents a position on the Nine Men's Morris board
class Position {
  final int ring; // 0 = outer, 1 = middle, 2 = inner
  final int point; // 0-7 for points around each ring

  const Position({required this.ring, required this.point});

  /// Create a Position from JSON data
  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(ring: json['ring'] as int, point: json['point'] as int);
  }

  /// Convert Position to JSON data
  Map<String, dynamic> toJson() {
    return {'ring': ring, 'point': point};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position &&
          runtimeType == other.runtimeType &&
          ring == other.ring &&
          point == other.point;

  @override
  int get hashCode => ring.hashCode ^ point.hashCode;

  @override
  String toString() => 'Position(ring: $ring, point: $point)';
}
