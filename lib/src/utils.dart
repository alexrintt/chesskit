import 'package:fast_immutable_collections/fast_immutable_collections.dart'
    hide Tuple2;

import './constants.dart';
import './models.dart';
import './position.dart';
import 'square_set.dart';

/// Gets the rank of that square.
Square squareRank(Square square) => square >> 3;

/// Gets the file of that square.
Square squareFile(Square square) => square & 0x7;

/// Parses a string like 'a1', 'a2', etc. and returns a [Square] or `null` if the square
/// doesn't exist.
Square? parseSquare(String str) {
  if (str.length != 2) return null;
  final int file = str.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final int rank = str.codeUnitAt(1) - '1'.codeUnitAt(0);
  if (file < 0 || file >= 8 || rank < 0 || rank >= 8) return null;
  return file + 8 * rank;
}

/// Returns the algebraic coordinate notation of the [Square].
String toAlgebraic(Square square) =>
    kFileNames[squareFile(square)] + kRankNames[squareRank(square)];

/// Gets all the legal moves of this position in the algebraic coordinate notation.
///
/// Includes both possible representations of castling moves (unless `chess960` is true).
IMap<String, ISet<String>> algebraicLegalMoves(
  Position<Position<dynamic>> pos, {
  bool isChess960 = false,
}) {
  final Map<String, ISet<String>> result = <String, ISet<String>>{};
  for (final MapEntry<Square, SquareSet> entry in pos.legalMoves.entries) {
    final Iterable<Square> dests = entry.value.squares;
    if (dests.isNotEmpty) {
      final Square from = entry.key;
      final Set<String> destSet =
          dests.map((Square e) => toAlgebraic(e)).toSet();
      if (!isChess960 &&
          from == pos.board.kingOf(pos.turn) &&
          squareFile(entry.key) == 4) {
        if (dests.contains(0)) {
          destSet.add('c1');
        } else if (dests.contains(56)) {
          destSet.add('c8');
        }
        if (dests.contains(7)) {
          destSet.add('g1');
        } else if (dests.contains(63)) {
          destSet.add('g8');
        }
      }
      result[toAlgebraic(from)] = ISet<String>(destSet);
    }
  }
  return IMap<String, ISet<String>>(result);
}

/// Utility for nullable fields in copyWith methods
class Box<T> {
  const Box(this.value);
  final T value;
}
