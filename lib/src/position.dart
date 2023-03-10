import 'dart:math' as math;

import 'package:fast_immutable_collections/fast_immutable_collections.dart'
    hide Tuple2;
import 'package:meta/meta.dart';

import './attacks.dart';
import './board.dart';
import './constants.dart';
import './models.dart';
import './setup.dart';
import './square_set.dart';
import './utils.dart';

/// A base class for playable chess or chess variant positions.
///
/// See [Chess] for a concrete implementation of standard rules.
@immutable
abstract class Position<T extends Position<T>> {
  const Position({
    required this.board,
    this.pockets,
    required this.turn,
    required this.castles,
    this.epSquare,
    required this.halfmoves,
    required this.fullmoves,
  });

  /// Piece positions on the board.
  final Board board;

  /// Pockets in chess variants like [Crazyhouse].
  final Pockets? pockets;

  /// Side to move.
  final Side turn;

  /// Castling paths and unmoved rooks.
  final Castles castles;

  /// En passant target square.
  final Square? epSquare;

  /// Number of half-moves since the last capture or pawn move.
  final int halfmoves;

  /// Current move number.
  final int fullmoves;

  /// Abstract const constructor to be used by subclasses.
  const Position._initial()
      : board = Board.standard,
        pockets = null,
        turn = Side.white,
        castles = Castles.standard,
        epSquare = null,
        halfmoves = 0,
        fullmoves = 1;

  Position._fromSetupUnchecked(Setup setup)
      : board = setup.board,
        pockets = setup.pockets,
        turn = setup.turn,
        castles = Castles.fromSetup(setup),
        epSquare = _validEpSquare(setup),
        halfmoves = setup.halfmoves,
        fullmoves = setup.fullmoves;

  Position<T> _copyWith({
    Board? board,
    Box<Pockets?>? pockets,
    Side? turn,
    Castles? castles,
    Box<Square?>? epSquare,
    int? halfmoves,
    int? fullmoves,
  });

  /// Create a [Position] from a [Setup] and [Rules].
  static Position<Position<dynamic>> setupPosition(
    Rules rules,
    Setup setup, {
    bool? ignoreImpossibleCheck,
  }) {
    switch (rules) {
      case Rules.chess:
        return Chess.fromSetup(
          setup,
          ignoreImpossibleCheck: ignoreImpossibleCheck,
        );
      case Rules.antichess:
        return Antichess.fromSetup(
          setup,
          ignoreImpossibleCheck: ignoreImpossibleCheck,
        );
      case Rules.atomic:
        return Atomic.fromSetup(
          setup,
          ignoreImpossibleCheck: ignoreImpossibleCheck,
        );
      case Rules.kingofthehill:
        return KingOfTheHill.fromSetup(
          setup,
          ignoreImpossibleCheck: ignoreImpossibleCheck,
        );
      case Rules.crazyhouse:
        return Crazyhouse.fromSetup(
          setup,
          ignoreImpossibleCheck: ignoreImpossibleCheck,
        );
      case Rules.threecheck:
        return ThreeCheck.fromSetup(
          setup,
          ignoreImpossibleCheck: ignoreImpossibleCheck,
        );
      case Rules.horde:
        throw UnimplementedError('Missing Rules Horde');
      case Rules.racingKings:
        throw UnimplementedError('Missing Rules Racing Kings');
    }
  }

  /// Returns the initial [Position] for the corresponding [Rules].
  static Position<Position<dynamic>> initialPosition(Rules rules) {
    switch (rules) {
      case Rules.chess:
        return Chess.initial;
      case Rules.antichess:
        return Antichess.initial;
      case Rules.atomic:
        return Atomic.initial;
      case Rules.kingofthehill:
        return KingOfTheHill.initial;
      case Rules.threecheck:
        return ThreeCheck.initial;
      case Rules.crazyhouse:
        return Crazyhouse.initial;
      case Rules.horde:
        throw UnimplementedError('Missing Rules Horde');
      case Rules.racingKings:
        throw UnimplementedError('Missing Rules Racing Kinds');
    }
  }

  /// Checks if the game is over due to a special variant end condition.
  bool get isVariantEnd;

  /// Tests special variant winning, losing and drawing conditions.
  Outcome? get variantOutcome;

  /// Gets the FEN string of this position.
  ///
  /// Contrary to the FEN given by [Setup], this should always be a legal
  /// position.
  String get fen {
    return Setup(
      board: board,
      pockets: pockets,
      turn: turn,
      unmovedRooks: castles.unmovedRooks,
      epSquare: _legalEpSquare(),
      halfmoves: halfmoves,
      fullmoves: fullmoves,
    ).fen;
  }

  /// Tests if the king is in check.
  bool get isCheck {
    final Square? king = board.kingOf(turn);
    return king != null && checkers.isNotEmpty;
  }

  /// Tests if the game is over.
  bool get isGameOver =>
      isVariantEnd || isInsufficientMaterial || !hasSomeLegalMoves;

  /// Tests for checkmate.
  bool get isCheckmate =>
      !isVariantEnd && checkers.isNotEmpty && !hasSomeLegalMoves;

  /// Tests for stalemate.
  bool get isStalemate =>
      !isVariantEnd && checkers.isEmpty && !hasSomeLegalMoves;

  /// The outcome of the game, or `null` if the game is not over.
  Outcome? get outcome {
    if (variantOutcome != null) {
      return variantOutcome;
    } else if (isCheckmate) {
      return Outcome(winner: turn.opposite);
    } else if (isInsufficientMaterial || isStalemate) {
      return Outcome.draw;
    } else {
      return null;
    }
  }

  /// Tests if both [Side] have insufficient winning material.
  bool get isInsufficientMaterial =>
      Side.values.every((Side side) => hasInsufficientMaterial(side));

  /// Tests if the position has at least one legal move.
  bool get hasSomeLegalMoves {
    final _Context context = _makeContext();
    for (final Square square in board.bySide(turn).squares) {
      if (_legalMovesOf(square, context: context).isNotEmpty) return true;
    }
    return false;
  }

  /// Gets all the legal moves of this position.
  IMap<Square, SquareSet> get legalMoves {
    final _Context context = _makeContext();
    if (context.isVariantEnd) {
      return IMap<int, SquareSet>(
        const <int, SquareSet>{},
      );
    }
    return IMap<int, SquareSet>(
      <int, SquareSet>{
        for (final Square s in board.bySide(turn).squares)
          s: _legalMovesOf(s, context: context)
      },
    );
  }

  /// Gets all the legal drops of this position.
  SquareSet get legalDrops => SquareSet.empty;

  /// SquareSet of pieces giving check.
  SquareSet get checkers {
    final Square? king = board.kingOf(turn);
    return king != null ? kingAttackers(king, turn.opposite) : SquareSet.empty;
  }

  /// Attacks that a king on `square` would have to deal with.
  SquareSet kingAttackers(Square square, Side attacker, {SquareSet? occupied}) {
    return board.attacksTo(square, attacker, occupied: occupied);
  }

  /// Tests if a [Side] has insufficient winning material.
  bool hasInsufficientMaterial(Side side) {
    if (board.bySide(side).isIntersected(board.pawns | board.rooksAndQueens)) {
      return false;
    }
    if (board.bySide(side).isIntersected(board.knights)) {
      return board.bySide(side).size <= 2 &&
          board
              .bySide(side.opposite)
              .diff(board.kings)
              .diff(board.queens)
              .isEmpty;
    }
    if (board.bySide(side).isIntersected(board.bishops)) {
      final bool sameColor =
          !board.bishops.isIntersected(SquareSet.darkSquares) ||
              !board.bishops.isIntersected(SquareSet.lightSquares);
      return sameColor && board.pawns.isEmpty && board.knights.isEmpty;
    }
    return true;
  }

  /// Tests a move for legality.
  bool isLegal(Move move) {
    assert(move is NormalMove || move is DropMove);
    if (move is NormalMove) {
      if (move.promotion == Role.pawn) return false;
      if (move.promotion == Role.king && this is! Antichess) return false;
      if (move.promotion != null &&
          (!board.pawns.has(move.from) || !SquareSet.backranks.has(move.to))) {
        return false;
      }
      final SquareSet legalMoves = _legalMovesOf(move.from);
      return legalMoves.has(move.to) || legalMoves.has(normalizeMove(move).to);
    } else if (move is DropMove) {
      if (pockets == null || pockets!.of(turn, move.role) <= 0) {
        return false;
      }
      if (move.role == Role.pawn && SquareSet.backranks.has(move.to)) {
        return false;
      }
      return legalDrops.has(move.to);
    }
    return false;
  }

  /// Gets the legal moves for that [Square].
  SquareSet legalMovesOf(Square square) {
    return _legalMovesOf(square);
  }

  /// Parses a move in Standard Algebraic Notation.
  ///
  /// Returns a legal [Move] of the [Position] or `null`.
  Move? parseSan(String sanString) {
    final int aIndex = 'a'.codeUnits[0];
    final int hIndex = 'h'.codeUnits[0];
    final int oneIndex = '1'.codeUnits[0];
    final int eightIndex = '8'.codeUnits[0];
    String san = sanString;

    final int firstAnnotationIndex = san.indexOf(RegExp('[!?#+]'));
    if (firstAnnotationIndex != -1) {
      san = san.substring(0, firstAnnotationIndex);
    }

    // Crazyhouse
    if (san.contains('@')) {
      if (san.length == 3 && san[0] != '@') {
        return null;
      }
      if (san.length == 4 && san[1] != '@') {
        return null;
      }
      final Role role;
      if (san.length == 3) {
        role = Role.pawn;
      } else if (san.length == 4) {
        final Role? parsedRole = Role.fromChar(san[0]);
        if (parsedRole == null) {
          return null;
        }
        role = parsedRole;
      } else {
        return null;
      }
      final Square? destination = parseSquare(san.substring(san.length - 2));
      if (destination == null) {
        return null;
      }
      final DropMove move = DropMove(to: destination, role: role);
      if (!isLegal(move)) {
        return null;
      }
      return move;
    }

    if (san == 'O-O') {
      Move? move;
      if (turn == Side.white) {
        // Castle the king from e1 to g1
        move = const NormalMove(from: Squares.e1, to: Squares.g1);
      }
      if (turn == Side.black) {
        // Castle the king from e8 to g8
        move = const NormalMove(from: Squares.e8, to: Squares.g8);
      }
      if (!isLegal(move!)) {
        return null;
      }
      return move;
    }
    if (san == 'O-O-O') {
      Move? move;
      if (turn == Side.white) {
        // Castle the king from e1 to c1
        move = const NormalMove(from: Squares.e1, to: Squares.c1);
      }
      if (turn == Side.black) {
        // Castle the king from e8 to c8
        move = const NormalMove(from: Squares.e8, to: Squares.c8);
      }
      if (!isLegal(move!)) {
        return null;
      }
      return move;
    }

    final bool isPromotion = san.contains('=');
    final bool isCapturing = san.contains('x');
    int? pawnRank;
    if (oneIndex <= san.codeUnits[0] && san.codeUnits[0] <= eightIndex) {
      pawnRank = san.codeUnits[0] - oneIndex;
      san = san.substring(1);
    }
    final bool isPawnMove =
        aIndex <= san.codeUnits[0] && san.codeUnits[0] <= hIndex;

    if (isPawnMove) {
      // Every pawn move has a destination (e.g. d4)
      // Optionally, pawn moves have a promotion
      // If the move is a capture then it will include the source file

      final SquareSet colorFilter = board.bySide(turn);
      final SquareSet pawnFilter = board.byRole(Role.pawn);
      SquareSet filter = colorFilter.intersect(pawnFilter);
      Role? promotionRole;

      // We can look at the first character of any pawn move
      // in order to determine which file the pawn will be moving
      // from
      final int sourceFileCharacter = san.codeUnits[0];
      if (sourceFileCharacter < aIndex || sourceFileCharacter > hIndex) {
        return null;
      }

      final int sourceFile = sourceFileCharacter - aIndex;
      final SquareSet sourceFileFilter = SquareSet.fromFile(sourceFile);
      filter = filter.intersect(sourceFileFilter);

      if (isCapturing) {
        // Invalid SAN
        if (san[1] != 'x') {
          return null;
        }

        // Remove the source file character and the capture marker
        san = san.substring(2);
      }

      if (isPromotion) {
        // Invalid SAN
        if (san[san.length - 2] != '=') {
          return null;
        }

        final String promotionCharacter = san[san.length - 1];
        promotionRole = Role.fromChar(promotionCharacter);

        // Remove the promotion string
        san = san.substring(0, san.length - 2);
      }

      // After handling captures and promotions, the
      // remaining destination square should contain
      // two characters.
      if (san.length != 2) {
        return null;
      }

      final Square? destination = parseSquare(san);
      if (destination == null) {
        return null;
      }

      // There may be many pawns in the corresponding file
      // The corect choice will always be the pawn behind the destination square that is furthest down the board
      for (int rank = 0; rank < 8; rank++) {
        final SquareSet rankFilter = SquareSet.fromRank(rank).complement();
        // If the square is behind or on this rank, the rank it will not contain the source pawn
        if (turn == Side.white && rank >= squareRank(destination) ||
            turn == Side.black && rank <= squareRank(destination)) {
          filter = filter.intersect(rankFilter);
        }
      }

      // If the pawn rank has been overspecified, then verify the rank
      if (pawnRank != null) {
        filter = filter.intersect(SquareSet.fromRank(pawnRank));
      }

      final int? source = (turn == Side.white) ? filter.last : filter.first;

      // There are no valid candidates for the move
      if (source == null) {
        return null;
      }

      final NormalMove move =
          NormalMove(from: source, to: destination, promotion: promotionRole);
      if (!isLegal(move)) {
        return null;
      }
      return move;
    }

    // The final two moves define the destination
    final Square? destination = parseSquare(san.substring(san.length - 2));
    if (destination == null) {
      return null;
    }

    san = san.substring(0, san.length - 2);
    if (isCapturing) {
      // Invalid SAN
      if (san[san.length - 1] != 'x') {
        return null;
      }
      san = san.substring(0, san.length - 1);
    }

    // For non-pawn moves, the first character describes a role
    final Role? role = Role.fromChar(san[0]);
    if (role == null) {
      return null;
    }
    if (role == Role.pawn) {
      return null;
    }
    san = san.substring(1);

    final SquareSet colorFilter = board.bySide(turn);
    final SquareSet roleFilter = board.byRole(role);
    SquareSet filter = colorFilter.intersect(roleFilter);

    // The remaining characters disambiguate the moves
    if (san.length > 2) {
      return null;
    }
    if (san.length == 2) {
      final Square? sourceSquare = parseSquare(san);
      if (sourceSquare == null) {
        return null;
      }
      final SquareSet squareFilter = SquareSet.fromSquare(sourceSquare);
      filter = filter.intersect(squareFilter);
    }
    if (san.length == 1) {
      final int sourceCharacter = san.codeUnits[0];
      if (oneIndex <= sourceCharacter && sourceCharacter <= eightIndex) {
        final int rank = sourceCharacter - oneIndex;
        final SquareSet rankFilter = SquareSet.fromRank(rank);
        filter = filter.intersect(rankFilter);
      } else if (aIndex <= sourceCharacter && sourceCharacter <= hIndex) {
        final int file = sourceCharacter - aIndex;
        final SquareSet fileFilter = SquareSet.fromFile(file);
        filter = filter.intersect(fileFilter);
      } else {
        return null;
      }
    }

    Move? move;
    for (final Square square in filter.squares) {
      final NormalMove candidateMove =
          NormalMove(from: square, to: destination);
      if (!isLegal(candidateMove)) {
        continue;
      }
      if (move == null) {
        move = candidateMove;
      } else {
        // Ambiguous notation
        return null;
      }
    }

    if (move == null) {
      return null;
    }

    return move;
  }

  /// Returns the Standard Algebraic Notation of this [Move] from the current [Position].
  String toSan(Move move) {
    final String san = _makeSanWithoutSuffix(move);
    final Position<T> newPos = playUnchecked(move);
    if (newPos.outcome?.winner != null) return '$san#';
    if (newPos.isCheck) return '$san+';
    return san;
  }

  /// Plays a move and returns the SAN representation of the [Move] from the [Position].
  ///
  /// Throws a [PlayError] if the move is not legal.
  Tuple2<Position<T>, String> playToSan(Move move) {
    if (isLegal(move)) {
      final String san = _makeSanWithoutSuffix(move);
      final Position<T> newPos = playUnchecked(move);
      final String suffixed = newPos.outcome?.winner != null
          ? '$san#'
          : newPos.isCheck
              ? '$san+'
              : san;
      return Tuple2<Position<T>, String>(newPos, suffixed);
    } else {
      throw PlayError('Invalid move $move');
    }
  }

  /// Plays a move.
  ///
  /// Throws a [PlayError] if the move is not legal.
  Position<T> play(Move move) {
    if (isLegal(move)) {
      return playUnchecked(move);
    } else {
      throw PlayError('Invalid move $move');
    }
  }

  /// Plays a move without checking if the move is legal.
  Position<T> playUnchecked(Move move) {
    assert(move is NormalMove || move is DropMove);
    if (move is NormalMove) {
      final Piece? piece = board.pieceAt(move.from);
      if (piece == null) {
        return _copyWith();
      }
      final CastlingSide? castlingSide = _getCastlingSide(move);
      final int epCaptureTarget = move.to + (turn == Side.white ? -8 : 8);
      Square? newEpSquare;
      Board newBoard = board.removePieceAt(move.from);
      Castles newCastles = castles;
      if (piece.role == Role.pawn) {
        if (move.to == epSquare) {
          newBoard = newBoard.removePieceAt(epCaptureTarget);
        }
        final int delta = move.from - move.to;
        if (delta.abs() == 16 && move.from >= 8 && move.from <= 55) {
          newEpSquare = (move.from + move.to) >>> 1;
        }
      } else if (piece.role == Role.rook) {
        newCastles = newCastles.discardRookAt(move.from);
      } else if (piece.role == Role.king) {
        if (castlingSide != null) {
          final Square? rookFrom = castles.rookOf(turn, castlingSide);
          if (rookFrom != null) {
            final Piece? rook = board.pieceAt(rookFrom);
            newBoard = newBoard
                .removePieceAt(rookFrom)
                .setPieceAt(_kingCastlesTo(turn, castlingSide), piece);
            if (rook != null) {
              newBoard =
                  newBoard.setPieceAt(_rookCastlesTo(turn, castlingSide), rook);
            }
          }
        }
        newCastles = newCastles.discardSide(turn);
      }

      if (castlingSide == null) {
        final Piece newPiece = move.promotion != null
            ? piece.copyWith(role: move.promotion, promoted: pockets != null)
            : piece;
        newBoard = newBoard.setPieceAt(move.to, newPiece);
      }

      final Piece? capturedPiece = castlingSide == null
          ? board.pieceAt(move.to)
          : move.to == epSquare
              ? board.pieceAt(epCaptureTarget)
              : null;
      final bool isCapture = capturedPiece != null;

      if (capturedPiece != null && capturedPiece.role == Role.rook) {
        newCastles = newCastles.discardRookAt(move.to);
      }

      return _copyWith(
        halfmoves: isCapture || piece.role == Role.pawn ? 0 : halfmoves + 1,
        fullmoves: turn == Side.black ? fullmoves + 1 : fullmoves,
        pockets: Box<Pockets?>(
          capturedPiece != null
              ? pockets?.increment(
                  capturedPiece.color.opposite,
                  capturedPiece.promoted ? Role.pawn : capturedPiece.role,
                )
              : pockets,
        ),
        board: newBoard,
        turn: turn.opposite,
        castles: newCastles,
        epSquare: Box<int?>(newEpSquare),
      );
    } else if (move is DropMove) {
      return _copyWith(
        halfmoves: move.role == Role.pawn ? 0 : halfmoves + 1,
        fullmoves: turn == Side.black ? fullmoves + 1 : fullmoves,
        turn: turn.opposite,
        board: board.setPieceAt(move.to, Piece(color: turn, role: move.role)),
        pockets: Box<Pockets?>(pockets?.decrement(turn, move.role)),
      );
    }
    return this;
  }

  /// Returns the normalized form of a [NormalMove] to avoid castling inconsistencies.
  Move normalizeMove(NormalMove move) {
    final CastlingSide? side = _getCastlingSide(move);
    if (side == null) return move;
    final Square? castlingRook = castles.rookOf(turn, side);
    return NormalMove(
      from: move.from,
      to: castlingRook ?? move.to,
    );
  }

  /// Checks the legality of this position.
  ///
  /// Throws a [PositionError] if it does not meet basic validity requirements.
  void validate({bool? ignoreImpossibleCheck}) {
    if (board.occupied.isEmpty) {
      throw PositionError.empty;
    }
    if (board.kings.size != 2) {
      throw PositionError.kings;
    }
    final Square? ourKing = board.kingOf(turn);
    if (ourKing == null) {
      throw PositionError.kings;
    }
    final Square? otherKing = board.kingOf(turn.opposite);
    if (otherKing == null) {
      throw PositionError.kings;
    }
    if (kingAttackers(otherKing, turn).isNotEmpty) {
      throw PositionError.oppositeCheck;
    }
    if (SquareSet.backranks.isIntersected(board.pawns)) {
      throw PositionError.pawnsOnBackrank;
    }
    final bool skipImpossibleCheck = ignoreImpossibleCheck ?? false;
    if (!skipImpossibleCheck) {
      _validateCheckers(ourKing);
    }
  }

  @override
  String toString() {
    return '$T(board: $board, turn: $turn, castles: $castles, halfmoves: $halfmoves, fullmoves: $fullmoves)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Position &&
            other.board == board &&
            other.pockets == pockets &&
            other.turn == turn &&
            other.castles == castles &&
            other.epSquare == epSquare &&
            other.halfmoves == halfmoves &&
            other.fullmoves == fullmoves;
  }

  @override
  int get hashCode => Object.hash(
        board,
        pockets,
        turn,
        castles,
        epSquare,
        halfmoves,
        fullmoves,
      );

  /// Checks if checkers are legal in this position.
  ///
  /// Throws a [PositionError.impossibleCheck] if it does not meet validity
  /// requirements.
  void _validateCheckers(Square ourKing) {
    final SquareSet checkers = kingAttackers(ourKing, turn.opposite);
    if (checkers.isNotEmpty) {
      if (epSquare != null) {
        // The pushed pawn must be the only checker, or it has uncovered
        // check by a single sliding piece.
        final int pushedTo = epSquare! ^ 8;
        final int pushedFrom = epSquare! ^ 24;
        if (checkers.moreThanOne ||
            (checkers.first != pushedTo &&
                board
                    .attacksTo(
                      ourKing,
                      turn.opposite,
                      occupied: board.occupied
                          .withoutSquare(pushedTo)
                          .withSquare(pushedFrom),
                    )
                    .isNotEmpty)) {
          throw PositionError.impossibleCheck;
        }
      } else {
        // Multiple sliding checkers aligned with king.
        if (checkers.size > 2 ||
            (checkers.size == 2 &&
                ray(checkers.first!, checkers.last!).has(ourKing))) {
          throw PositionError.impossibleCheck;
        }
      }
    }
  }

  String _makeSanWithoutSuffix(Move move) {
    assert(move is NormalMove || move is DropMove);
    String san = '';
    if (move is NormalMove) {
      final Role? role = board.roleAt(move.from);
      if (role == null) return '--';
      if (role == Role.king &&
          (board.bySide(turn).has(move.to) ||
              (move.to - move.from).abs() == 2)) {
        san = move.to > move.from ? 'O-O' : 'O-O-O';
      } else {
        final bool capture = board.occupied.has(move.to) ||
            (role == Role.pawn && squareFile(move.from) != squareFile(move.to));
        if (role != Role.pawn) {
          san = role.char.toUpperCase();

          // Disambiguation
          SquareSet others;
          if (role == Role.king) {
            others = kingAttacks(move.to) & board.kings;
          } else if (role == Role.queen) {
            others = queenAttacks(move.to, board.occupied) & board.queens;
          } else if (role == Role.rook) {
            others = rookAttacks(move.to, board.occupied) & board.rooks;
          } else if (role == Role.bishop) {
            others = bishopAttacks(move.to, board.occupied) & board.bishops;
          } else {
            others = knightAttacks(move.to) & board.knights;
          }
          others =
              others.intersect(board.bySide(turn)).withoutSquare(move.from);

          if (others.isNotEmpty) {
            final _Context ctx = _makeContext();
            for (final Square from in others.squares) {
              if (!_legalMovesOf(from, context: ctx).has(move.to)) {
                others = others.withoutSquare(from);
              }
            }
            if (others.isNotEmpty) {
              bool row = false;
              bool column = others
                  .isIntersected(SquareSet.fromRank(squareRank(move.from)));
              if (others
                  .isIntersected(SquareSet.fromFile(squareFile(move.from)))) {
                row = true;
              } else {
                column = true;
              }
              if (column) {
                san += kFileNames[squareFile(move.from)];
              }
              if (row) {
                san += kRankNames[squareRank(move.from)];
              }
            }
          }
        } else if (capture) {
          san = kFileNames[squareFile(move.from)];
        }

        if (capture) san += 'x';
        san += toAlgebraic(move.to);
        if (move.promotion != null) {
          san += '=${move.promotion!.char.toUpperCase()}';
        }
      }
    } else {
      move as DropMove;
      if (move.role != Role.pawn) san = move.role.char.toUpperCase();
      san += '@${toAlgebraic(move.to)}';
    }
    return san;
  }

  /// Gets the legal moves for that [Square].
  ///
  /// Optionnaly pass a [_Context] of the position, to optimize performance when
  /// calling this method several times.
  SquareSet _legalMovesOf(Square square, {_Context? context}) {
    final _Context ctx = context ?? _makeContext();
    if (ctx.isVariantEnd) return SquareSet.empty;
    final Piece? piece = board.pieceAt(square);
    if (piece == null || piece.color != turn) return SquareSet.empty;
    final Square? king = ctx.king;
    if (king == null) return SquareSet.empty;

    SquareSet pseudo;
    SquareSet? legalEpSquare;
    if (piece.role == Role.pawn) {
      pseudo = pawnAttacks(turn, square) & board.bySide(turn.opposite);
      final int delta = turn == Side.white ? 8 : -8;
      final int step = square + delta;
      if (0 <= step && step < 64 && !board.occupied.has(step)) {
        pseudo = pseudo.withSquare(step);
        final bool canDoubleStep =
            turn == Side.white ? square < 16 : square >= 64 - 16;
        final int doubleStep = step + delta;
        if (canDoubleStep && !board.occupied.has(doubleStep)) {
          pseudo = pseudo.withSquare(doubleStep);
        }
      }
      if (epSquare != null && _canCaptureEp(square)) {
        final int pawn = epSquare! - delta;
        if (ctx.checkers.isEmpty || ctx.checkers.singleSquare == pawn) {
          legalEpSquare = SquareSet.fromSquare(epSquare!);
        }
      }
    } else if (piece.role == Role.bishop) {
      pseudo = bishopAttacks(square, board.occupied);
    } else if (piece.role == Role.knight) {
      pseudo = knightAttacks(square);
    } else if (piece.role == Role.rook) {
      pseudo = rookAttacks(square, board.occupied);
    } else if (piece.role == Role.queen) {
      pseudo = queenAttacks(square, board.occupied);
    } else {
      pseudo = kingAttacks(square);
    }

    pseudo = pseudo.diff(board.bySide(turn));

    if (piece.role == Role.king) {
      final SquareSet occ = board.occupied.withoutSquare(square);
      for (final Square to in pseudo.squares) {
        if (kingAttackers(to, turn.opposite, occupied: occ).isNotEmpty) {
          pseudo = pseudo.withoutSquare(to);
        }
      }
      return pseudo
          .union(_castlingMove(CastlingSide.queen, ctx))
          .union(_castlingMove(CastlingSide.king, ctx));
    }

    if (ctx.checkers.isNotEmpty) {
      final int? checker = ctx.checkers.singleSquare;
      if (checker == null) return SquareSet.empty;
      pseudo = pseudo & between(checker, king).withSquare(checker);
    }

    if (ctx.blockers.has(square)) {
      pseudo = pseudo & ray(square, king);
    }

    if (legalEpSquare != null) {
      pseudo = pseudo | legalEpSquare;
    }

    return pseudo;
  }

  _Context _makeContext() {
    final Square? king = board.kingOf(turn);
    if (king == null) {
      return _Context(
        isVariantEnd: isVariantEnd,
        mustCapture: false,
        king: king,
        blockers: SquareSet.empty,
        checkers: SquareSet.empty,
      );
    }
    return _Context(
      isVariantEnd: isVariantEnd,
      mustCapture: false,
      king: king,
      blockers: _sliderBlockers(king),
      checkers: checkers,
    );
  }

  SquareSet _sliderBlockers(Square king) {
    final SquareSet snipers = rookAttacks(king, SquareSet.empty)
        .intersect(board.rooksAndQueens)
        .union(
          bishopAttacks(king, SquareSet.empty)
              .intersect(board.bishopsAndQueens),
        )
        .intersect(board.bySide(turn.opposite));
    SquareSet blockers = SquareSet.empty;
    for (final Square sniper in snipers.squares) {
      final SquareSet b = between(king, sniper) & board.occupied;
      if (!b.moreThanOne) blockers = blockers | b;
    }
    return blockers;
  }

  SquareSet _castlingMove(CastlingSide side, _Context context) {
    final Square? king = context.king;
    if (king == null || context.checkers.isNotEmpty) {
      return SquareSet.empty;
    }
    final Square? rook = castles.rookOf(turn, side);
    if (rook == null) return SquareSet.empty;
    if (castles.pathOf(turn, side).isIntersected(board.occupied)) {
      return SquareSet.empty;
    }

    final Square kingTo = _kingCastlesTo(turn, side);
    final SquareSet kingPath = between(king, kingTo);
    final SquareSet occ = board.occupied.withoutSquare(king);
    for (final Square sq in kingPath.squares) {
      if (kingAttackers(sq, turn.opposite, occupied: occ).isNotEmpty) {
        return SquareSet.empty;
      }
    }
    final Square rookTo = _rookCastlesTo(turn, side);
    final SquareSet after = board.occupied
        .toggleSquare(king)
        .toggleSquare(rook)
        .toggleSquare(rookTo);
    if (kingAttackers(kingTo, turn.opposite, occupied: after).isNotEmpty) {
      return SquareSet.empty;
    }
    return SquareSet.fromSquare(rook);
  }

  bool _canCaptureEp(Square pawn) {
    if (epSquare == null) return false;
    if (!pawnAttacks(turn, pawn).has(epSquare!)) return false;
    final Square? king = board.kingOf(turn);
    if (king == null) return true;
    final int captured = epSquare! + (turn == Side.white ? -8 : 8);
    final SquareSet occupied = board.occupied
        .toggleSquare(pawn)
        .toggleSquare(epSquare!)
        .toggleSquare(captured);
    return !board
        .attacksTo(king, turn.opposite, occupied: occupied)
        .isIntersected(occupied);
  }

  /// Detects if a move is a castling move.
  ///
  /// Returns the [CastlingSide] or `null` if the move is a regular move.
  CastlingSide? _getCastlingSide(Move move) {
    if (move is NormalMove) {
      final int delta = move.to - move.from;
      if (delta.abs() != 2 && !board.bySide(turn).has(move.to)) {
        return null;
      }
      if (!board.kings.has(move.from)) {
        return null;
      }
      return delta > 0 ? CastlingSide.king : CastlingSide.queen;
    }
    return null;
  }

  Square? _legalEpSquare() {
    if (epSquare == null) return null;
    final SquareSet ourPawns = board.piecesOf(turn, Role.pawn);
    final SquareSet candidates =
        ourPawns & pawnAttacks(turn.opposite, epSquare!);
    for (final Square candidate in candidates.squares) {
      if (_legalMovesOf(candidate).has(epSquare!)) {
        return epSquare;
      }
    }
    return null;
  }
}

/// A standard chess position.
@immutable
class Chess extends Position<Chess> {
  const Chess({
    required super.board,
    super.pockets,
    required super.turn,
    required super.castles,
    super.epSquare,
    required super.halfmoves,
    required super.fullmoves,
  });

  Chess._fromSetupUnchecked(super.setup) : super._fromSetupUnchecked();
  const Chess._initial() : super._initial();

  static const Chess initial = Chess._initial();

  @override
  bool get isVariantEnd => false;

  @override
  Outcome? get variantOutcome => null;

  /// Set up a playable [Chess] position.
  ///
  /// Throws a [PositionError] if the [Setup] does not meet basic validity
  /// requirements.
  /// Optionnaly pass a `ignoreImpossibleCheck` boolean if you want to skip that
  /// requirement.
  factory Chess.fromSetup(Setup setup, {bool? ignoreImpossibleCheck}) {
    final Chess pos = Chess._fromSetupUnchecked(setup);
    pos.validate(ignoreImpossibleCheck: ignoreImpossibleCheck);
    return pos;
  }

  @override
  Chess _copyWith({
    Board? board,
    Box<Pockets?>? pockets,
    Side? turn,
    Castles? castles,
    Box<Square?>? epSquare,
    int? halfmoves,
    int? fullmoves,
  }) {
    return Chess(
      board: board ?? this.board,
      pockets: pockets != null ? pockets.value : this.pockets,
      turn: turn ?? this.turn,
      castles: castles ?? this.castles,
      epSquare: epSquare != null ? epSquare.value : this.epSquare,
      halfmoves: halfmoves ?? this.halfmoves,
      fullmoves: fullmoves ?? this.fullmoves,
    );
  }
}

/// A variant of chess where you lose all your pieces or get stalemated to win.
@immutable
class Antichess extends Position<Antichess> {
  const Antichess({
    required super.board,
    super.pockets,
    required super.turn,
    required super.castles,
    super.epSquare,
    required super.halfmoves,
    required super.fullmoves,
  });

  Antichess._fromSetupUnchecked(super.setup) : super._fromSetupUnchecked();

  static const Antichess initial = Antichess(
    board: Board.standard,
    turn: Side.white,
    castles: Castles.empty,
    halfmoves: 0,
    fullmoves: 1,
  );

  @override
  bool get isVariantEnd => board.bySide(turn).isEmpty;

  @override
  Outcome? get variantOutcome {
    if (isVariantEnd || isStalemate) {
      return Outcome(winner: turn);
    }
    return null;
  }

  /// Set up a playable [Antichess] position.
  ///
  /// Throws a [PositionError] if the [Setup] does not meet basic validity
  /// requirements.
  /// Optionnaly pass a `ignoreImpossibleCheck` boolean if you want to skip that
  /// requirement.
  factory Antichess.fromSetup(Setup setup, {bool? ignoreImpossibleCheck}) {
    final Antichess pos = Antichess._fromSetupUnchecked(setup);
    final Antichess noCastles = pos._copyWith(castles: Castles.empty);
    noCastles.validate(ignoreImpossibleCheck: ignoreImpossibleCheck);
    return noCastles;
  }

  @override
  void validate({bool? ignoreImpossibleCheck}) {
    if (board.occupied.isEmpty) {
      throw PositionError.empty;
    }
    if (SquareSet.backranks.isIntersected(board.pawns)) {
      throw PositionError.pawnsOnBackrank;
    }
  }

  @override
  SquareSet kingAttackers(Square square, Side attacker, {SquareSet? occupied}) {
    return SquareSet.empty;
  }

  @override
  _Context _makeContext() {
    final _Context ctx = super._makeContext();
    if (epSquare != null &&
        pawnAttacks(turn.opposite, epSquare!)
            .isIntersected(board.piecesOf(turn, Role.pawn))) {
      return ctx.copyWith(mustCapture: true);
    }
    final SquareSet enemy = board.bySide(turn.opposite);
    for (final Square from in board.bySide(turn).squares) {
      if (_pseudoLegalMoves(this, from, ctx).isIntersected(enemy)) {
        return ctx.copyWith(mustCapture: true);
      }
    }
    return ctx;
  }

  @override
  SquareSet _legalMovesOf(Square square, {_Context? context}) {
    final _Context ctx = context ?? _makeContext();
    final SquareSet dests = _pseudoLegalMoves(this, square, ctx);
    final SquareSet enemy = board.bySide(turn.opposite);
    return dests &
        (ctx.mustCapture
            ? epSquare != null && board.roleAt(square) == Role.pawn
                ? enemy.withSquare(epSquare!)
                : enemy
            : SquareSet.full);
  }

  @override
  bool hasInsufficientMaterial(Side side) {
    if (board.bySide(side).isEmpty) return false;
    if (board.bySide(side.opposite).isEmpty) return true;
    if (board.occupied == board.bishops) {
      final bool weSomeOnLight =
          board.bySide(side).isIntersected(SquareSet.lightSquares);
      final bool weSomeOnDark =
          board.bySide(side).isIntersected(SquareSet.darkSquares);
      final bool theyAllOnDark =
          board.bySide(side.opposite).isDisjoint(SquareSet.lightSquares);
      final bool theyAllOnLight =
          board.bySide(side.opposite).isDisjoint(SquareSet.darkSquares);
      return (weSomeOnLight && theyAllOnDark) ||
          (weSomeOnDark && theyAllOnLight);
    }
    if (board.occupied == board.knights && board.occupied.size == 2) {
      return (board.white.isIntersected(SquareSet.lightSquares) !=
              board.black.isIntersected(SquareSet.darkSquares)) !=
          (turn == side);
    }
    return false;
  }

  @override
  Antichess _copyWith({
    Board? board,
    Box<Pockets?>? pockets,
    Side? turn,
    Castles? castles,
    Box<Square?>? epSquare,
    int? halfmoves,
    int? fullmoves,
  }) {
    return Antichess(
      board: board ?? this.board,
      pockets: pockets != null ? pockets.value : this.pockets,
      turn: turn ?? this.turn,
      castles: castles ?? this.castles,
      epSquare: epSquare != null ? epSquare.value : this.epSquare,
      halfmoves: halfmoves ?? this.halfmoves,
      fullmoves: fullmoves ?? this.fullmoves,
    );
  }
}

/// A variant of chess where captures cause an explosion to the surrounding pieces.
@immutable
class Atomic extends Position<Atomic> {
  const Atomic({
    required super.board,
    super.pockets,
    required super.turn,
    required super.castles,
    super.epSquare,
    required super.halfmoves,
    required super.fullmoves,
  });

  Atomic._fromSetupUnchecked(super.setup) : super._fromSetupUnchecked();
  const Atomic._initial() : super._initial();

  static const Atomic initial = Atomic._initial();

  @override
  bool get isVariantEnd => variantOutcome != null;

  @override
  Outcome? get variantOutcome {
    for (final Side color in Side.values) {
      if (board.piecesOf(color, Role.king).isEmpty) {
        return Outcome(winner: color.opposite);
      }
    }
    return null;
  }

  /// Set up a playable [Atomic] position.
  ///
  /// Throws a [PositionError] if the [Setup] does not meet basic validity
  /// requirements.
  /// Optionnaly pass a `ignoreImpossibleCheck` boolean if you want to skip that
  /// requirement.
  factory Atomic.fromSetup(Setup setup, {bool? ignoreImpossibleCheck}) {
    final Atomic pos = Atomic._fromSetupUnchecked(setup);
    pos.validate(ignoreImpossibleCheck: ignoreImpossibleCheck);
    return pos;
  }

  /// Attacks that a king on `square` would have to deal with.
  ///
  /// Contrary to chess, in Atomic kings can attack each other, without causing
  /// check.
  @override
  SquareSet kingAttackers(Square square, Side attacker, {SquareSet? occupied}) {
    final SquareSet attackerKings = board.piecesOf(attacker, Role.king);
    if (attackerKings.isEmpty ||
        kingAttacks(square).isIntersected(attackerKings)) {
      return SquareSet.empty;
    }
    return super.kingAttackers(square, attacker, occupied: occupied);
  }

  /// Checks the legality of this position.
  ///
  /// Validation is like chess, but it allows our king to be missing.
  /// Throws a [PositionError] if it does not meet basic validity requirements.
  @override
  void validate({bool? ignoreImpossibleCheck}) {
    if (board.occupied.isEmpty) {
      throw PositionError.empty;
    }
    if (board.kings.size > 2) {
      throw PositionError.kings;
    }
    final Square? otherKing = board.kingOf(turn.opposite);
    if (otherKing == null) {
      throw PositionError.kings;
    }
    if (kingAttackers(otherKing, turn).isNotEmpty) {
      throw PositionError.oppositeCheck;
    }
    if (SquareSet.backranks.isIntersected(board.pawns)) {
      throw PositionError.pawnsOnBackrank;
    }
    final bool skipImpossibleCheck = ignoreImpossibleCheck ?? false;
    final Square? ourKing = board.kingOf(turn);
    if (!skipImpossibleCheck && ourKing != null) {
      _validateCheckers(ourKing);
    }
  }

  @override
  void _validateCheckers(Square ourKing) {
    // Other king moving away can cause many checks to be given at the
    // same time. Not checking details or even that the king is close enough.
    if (epSquare == null) {
      super._validateCheckers(ourKing);
    }
  }

  /// Plays a move without checking if the move is legal.
  ///
  /// In addition to standard rules, all captures cause an explosion by which
  /// the captured piece, the piece used to capture, and all surrounding pieces
  /// except pawns that are within a one square radius are removed from the
  /// board.
  @override
  Atomic playUnchecked(Move move) {
    final CastlingSide? castlingSide = _getCastlingSide(move);
    final Piece? capturedPiece =
        castlingSide == null ? board.pieceAt(move.to) : null;
    final bool isCapture = capturedPiece != null || move.to == epSquare;
    final Atomic newPos = super.playUnchecked(move) as Atomic;

    if (isCapture) {
      Castles newCastles = newPos.castles;
      Board newBoard = newPos.board.removePieceAt(move.to);
      for (final Square explode in kingAttacks(move.to)
          .intersect(newBoard.occupied)
          .diff(newBoard.pawns)
          .squares) {
        final Piece? piece = newBoard.pieceAt(explode);
        newBoard = newBoard.removePieceAt(explode);
        if (piece != null) {
          if (piece.role == Role.rook) {
            newCastles = newCastles.discardRookAt(explode);
          }
          if (piece.role == Role.king) {
            newCastles = newCastles.discardSide(piece.color);
          }
        }
      }
      return newPos._copyWith(board: newBoard, castles: newCastles);
    } else {
      return newPos;
    }
  }

  /// Tests if a [Side] has insufficient winning material.
  @override
  bool hasInsufficientMaterial(Side side) {
    // Remaining material does not matter if the enemy king is already
    // exploded.
    if (board.piecesOf(side.opposite, Role.king).isEmpty) return false;

    // Bare king cannot mate.
    if (board.bySide(side).diff(board.kings).isEmpty) return true;

    // As long as the enemy king is not alone, there is always a chance their
    // own pieces explode next to it.
    if (board.bySide(side.opposite).diff(board.kings).isNotEmpty) {
      // Unless there are only bishops that cannot explode each other.
      if (board.occupied == board.bishops | board.kings) {
        if (!(board.bishops & board.white)
            .isIntersected(SquareSet.darkSquares)) {
          return !(board.bishops & board.black)
              .isIntersected(SquareSet.lightSquares);
        }
        if (!(board.bishops & board.white)
            .isIntersected(SquareSet.lightSquares)) {
          return !(board.bishops & board.black)
              .isIntersected(SquareSet.darkSquares);
        }
      }
      return false;
    }

    // Queen or pawn (future queen) can give mate against bare king.
    if (board.queens.isNotEmpty || board.pawns.isNotEmpty) return false;

    // Single knight, bishop or rook cannot mate against bare king.
    if ((board.knights | board.bishops | board.rooks).size == 1) {
      return true;
    }

    // If only knights, more than two are required to mate bare king.
    if (board.occupied == board.knights | board.kings) {
      return board.knights.size <= 2;
    }

    return false;
  }

  @override
  SquareSet _legalMovesOf(Square square, {_Context? context}) {
    SquareSet moves = SquareSet.empty;
    final _Context ctx = context ?? _makeContext();
    for (final Square to in _pseudoLegalMoves(this, square, ctx).squares) {
      final Atomic after = playUnchecked(NormalMove(from: square, to: to));
      final Square? ourKing = after.board.kingOf(turn);
      if (ourKing != null &&
          (after.board.kingOf(after.turn) == null ||
              after.kingAttackers(ourKing, after.turn).isEmpty)) {
        moves = moves.withSquare(to);
      }
    }
    return moves;
  }

  @override
  Atomic _copyWith({
    Board? board,
    Box<Pockets?>? pockets,
    Side? turn,
    Castles? castles,
    Box<Square?>? epSquare,
    int? halfmoves,
    int? fullmoves,
  }) {
    return Atomic(
      board: board ?? this.board,
      pockets: pockets != null ? pockets.value : this.pockets,
      turn: turn ?? this.turn,
      castles: castles ?? this.castles,
      epSquare: epSquare != null ? epSquare.value : this.epSquare,
      halfmoves: halfmoves ?? this.halfmoves,
      fullmoves: fullmoves ?? this.fullmoves,
    );
  }
}

/// A variant where captured pieces can be dropped back on the board instead of moving a piece.
@immutable
class Crazyhouse extends Position<Crazyhouse> {
  const Crazyhouse({
    required super.board,
    super.pockets,
    required super.turn,
    required super.castles,
    super.epSquare,
    required super.halfmoves,
    required super.fullmoves,
  });

  Crazyhouse._fromSetupUnchecked(super.setup) : super._fromSetupUnchecked();

  static const Crazyhouse initial = Crazyhouse(
    board: Board.standard,
    pockets: Pockets.empty,
    turn: Side.white,
    castles: Castles.standard,
    halfmoves: 0,
    fullmoves: 1,
  );

  @override
  bool get isVariantEnd => false;

  @override
  Outcome? get variantOutcome => null;

  /// Set up a playable [Crazyhouse] position.
  ///
  /// Throws a [PositionError] if the [Setup] does not meet basic validity
  /// requirements.
  /// Optionnaly pass a `ignoreImpossibleCheck` boolean if you want to skip that
  /// requirement.
  factory Crazyhouse.fromSetup(Setup setup, {bool? ignoreImpossibleCheck}) {
    final Crazyhouse pos = Crazyhouse._fromSetupUnchecked(setup)._copyWith(
      pockets: Box<Pockets?>(setup.pockets ?? Pockets.empty),
      board: setup.board.withPromoted(
        setup.board.promoted
            .intersect(setup.board.occupied)
            .diff(setup.board.kings)
            .diff(setup.board.pawns),
      ),
    );
    pos.validate(ignoreImpossibleCheck: ignoreImpossibleCheck);
    return pos;
  }

  @override
  void validate({bool? ignoreImpossibleCheck}) {
    super.validate(ignoreImpossibleCheck: ignoreImpossibleCheck);
    if (pockets == null) {
      throw PositionError.variant;
    } else {
      if (pockets!.count(Role.king) > 0) {
        throw PositionError.kings;
      }
      if (pockets!.size + board.occupied.size > 64) {
        throw PositionError.variant;
      }
    }
  }

  @override
  bool hasInsufficientMaterial(Side side) {
    if (pockets == null) {
      return super.hasInsufficientMaterial(side);
    }
    return board.occupied.size + pockets!.size <= 3 &&
        board.pawns.isEmpty &&
        board.promoted.isEmpty &&
        board.rooksAndQueens.isEmpty &&
        pockets!.count(Role.pawn) <= 0 &&
        pockets!.count(Role.rook) <= 0 &&
        pockets!.count(Role.queen) <= 0;
  }

  @override
  SquareSet get legalDrops {
    final SquareSet mask = board.occupied.complement().intersect(
          pockets != null && pockets!.hasQuality(turn)
              ? SquareSet.full
              : pockets != null && pockets!.hasPawn(turn)
                  ? SquareSet.backranks.complement()
                  : SquareSet.empty,
        );

    final _Context ctx = _makeContext();
    if (ctx.king != null && ctx.checkers.isNotEmpty) {
      final int? checker = ctx.checkers.singleSquare;
      if (checker == null) {
        return SquareSet.empty;
      } else {
        return mask & between(checker, ctx.king!);
      }
    } else {
      return mask;
    }
  }

  @override
  Crazyhouse _copyWith({
    Board? board,
    Box<Pockets?>? pockets,
    Side? turn,
    Castles? castles,
    Box<Square?>? epSquare,
    int? halfmoves,
    int? fullmoves,
  }) {
    return Crazyhouse(
      board: board ?? this.board,
      pockets: pockets != null ? pockets.value : this.pockets,
      turn: turn ?? this.turn,
      castles: castles ?? this.castles,
      epSquare: epSquare != null ? epSquare.value : this.epSquare,
      halfmoves: halfmoves ?? this.halfmoves,
      fullmoves: fullmoves ?? this.fullmoves,
    );
  }
}

/// A variant similar to standard chess, where you win by putting your king on the center
/// of the board.
@immutable
class KingOfTheHill extends Position<KingOfTheHill> {
  const KingOfTheHill({
    required super.board,
    super.pockets,
    required super.turn,
    required super.castles,
    super.epSquare,
    required super.halfmoves,
    required super.fullmoves,
  });

  KingOfTheHill._fromSetupUnchecked(super.setup) : super._fromSetupUnchecked();
  const KingOfTheHill._initial() : super._initial();

  static const KingOfTheHill initial = KingOfTheHill._initial();

  @override
  bool get isVariantEnd => board.kings.isIntersected(SquareSet.center);

  @override
  Outcome? get variantOutcome {
    for (final Side color in Side.values) {
      if (board.piecesOf(color, Role.king).isIntersected(SquareSet.center)) {
        return Outcome(winner: color);
      }
    }
    return null;
  }

  /// Set up a playable [KingOfTheHill] position.
  ///
  /// Throws a [PositionError] if the [Setup] does not meet basic validity
  /// requirements.
  /// Optionnaly pass a `ignoreImpossibleCheck` boolean if you want to skip that
  /// requirement.
  factory KingOfTheHill.fromSetup(Setup setup, {bool? ignoreImpossibleCheck}) {
    final KingOfTheHill pos = KingOfTheHill._fromSetupUnchecked(setup);
    pos.validate(ignoreImpossibleCheck: ignoreImpossibleCheck);
    return pos;
  }

  @override
  bool hasInsufficientMaterial(Side side) => false;

  @override
  KingOfTheHill _copyWith({
    Board? board,
    Box<Pockets?>? pockets,
    Side? turn,
    Castles? castles,
    Box<Square?>? epSquare,
    int? halfmoves,
    int? fullmoves,
  }) {
    return KingOfTheHill(
      board: board ?? this.board,
      pockets: pockets != null ? pockets.value : this.pockets,
      turn: turn ?? this.turn,
      castles: castles ?? this.castles,
      epSquare: epSquare != null ? epSquare.value : this.epSquare,
      halfmoves: halfmoves ?? this.halfmoves,
      fullmoves: fullmoves ?? this.fullmoves,
    );
  }
}

/// A variant similar to standard chess, where you can win if you put your opponent king
/// into the third check.
@immutable
class ThreeCheck extends Position<ThreeCheck> {
  const ThreeCheck({
    required super.board,
    super.pockets,
    required super.turn,
    required super.castles,
    super.epSquare,
    required super.halfmoves,
    required super.fullmoves,
    required this.remainingChecks,
  });

  /// Number of remainingChecks for white (`item1`) and black (`item2`).
  final Tuple2<int, int> remainingChecks;

  const ThreeCheck._initial()
      : remainingChecks = _defaultRemainingChecks,
        super._initial();

  static const ThreeCheck initial = ThreeCheck._initial();

  static const Tuple2<int, int> _defaultRemainingChecks =
      Tuple2<int, int>(3, 3);

  @override
  bool get isVariantEnd =>
      remainingChecks.item1 <= 0 || remainingChecks.item2 <= 0;

  @override
  Outcome? get variantOutcome {
    if (remainingChecks.item1 <= 0) {
      return Outcome.whiteWins;
    }
    if (remainingChecks.item2 <= 0) {
      return Outcome.blackWins;
    }
    return null;
  }

  /// Set up a playable [ThreeCheck] position.
  ///
  /// Throws a [PositionError] if the [Setup] does not meet basic validity
  /// requirements.
  /// Optionnaly pass a `ignoreImpossibleCheck` boolean if you want to skip that
  /// requirement.
  factory ThreeCheck.fromSetup(Setup setup, {bool? ignoreImpossibleCheck}) {
    if (setup.remainingChecks == null) {
      throw PositionError.variant;
    } else {
      final ThreeCheck pos = ThreeCheck(
        board: setup.board,
        turn: setup.turn,
        castles: Castles.fromSetup(setup),
        epSquare: _validEpSquare(setup),
        halfmoves: setup.halfmoves,
        fullmoves: setup.fullmoves,
        remainingChecks: setup.remainingChecks!,
      );
      pos.validate(ignoreImpossibleCheck: ignoreImpossibleCheck);
      return pos;
    }
  }

  @override
  String get fen {
    return Setup(
      board: board,
      turn: turn,
      unmovedRooks: castles.unmovedRooks,
      epSquare: _legalEpSquare(),
      halfmoves: halfmoves,
      fullmoves: fullmoves,
      remainingChecks: remainingChecks,
    ).fen;
  }

  @override
  bool hasInsufficientMaterial(Side side) =>
      board.piecesOf(side, Role.king) == board.bySide(side);

  @override
  ThreeCheck playUnchecked(Move move) {
    final ThreeCheck newPos = super.playUnchecked(move) as ThreeCheck;
    if (newPos.isCheck) {
      return newPos._copyWith(
        remainingChecks: turn == Side.white
            ? remainingChecks.withItem1(math.max(remainingChecks.item1 - 1, 0))
            : remainingChecks.withItem2(math.max(remainingChecks.item2 - 1, 0)),
      );
    } else {
      return newPos;
    }
  }

  @override
  ThreeCheck _copyWith({
    Board? board,
    Box<Pockets?>? pockets,
    Side? turn,
    Castles? castles,
    Box<Square?>? epSquare,
    int? halfmoves,
    int? fullmoves,
    Tuple2<int, int>? remainingChecks,
  }) {
    return ThreeCheck(
      board: board ?? this.board,
      pockets: pockets != null ? pockets.value : this.pockets,
      turn: turn ?? this.turn,
      castles: castles ?? this.castles,
      epSquare: epSquare != null ? epSquare.value : this.epSquare,
      halfmoves: halfmoves ?? this.halfmoves,
      fullmoves: fullmoves ?? this.fullmoves,
      remainingChecks: remainingChecks ?? this.remainingChecks,
    );
  }
}

/// The outcome of a [Position]. No `winner` means a draw.
@immutable
class Outcome {
  const Outcome({this.winner});

  final Side? winner;

  static const Outcome whiteWins = Outcome(winner: Side.white);
  static const Outcome blackWins = Outcome(winner: Side.black);
  static const Outcome draw = Outcome();

  @override
  String toString() {
    return 'winner: $winner';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Outcome && winner == other.winner;

  @override
  int get hashCode => winner.hashCode;

  /// Create [Outcome] from string
  static Outcome? fromPgn(String? outcome) {
    if (outcome == '1/2-1/2') {
      return Outcome.draw;
    } else if (outcome == '1-0') {
      return Outcome.whiteWins;
    } else if (outcome == '0-1') {
      return Outcome.blackWins;
    } else {
      return null;
    }
  }

  /// Create PGN String out of [Outcome]
  static String toPgnString(Outcome? outcome) {
    if (outcome == null) {
      return '*';
    } else if (outcome.winner == Side.white) {
      return '1-0';
    } else if (outcome.winner == Side.black) {
      return '0-1';
    } else {
      return '1/2-1/2';
    }
  }
}

enum IllegalSetup {
  /// There are no pieces on the board.
  empty,

  /// The player not to move is in check.
  oppositeCheck,

  /// There are impossibly many checkers, two sliding checkers are
  /// aligned, or check is not possible because the last move was a
  /// double pawn push.
  ///
  /// Such a position cannot be reached by any sequence of legal moves.
  impossibleCheck,

  /// There are pawns on the backrank.
  pawnsOnBackrank,

  /// A king is missing, or there are too many kings.
  kings,

  /// A variant specific rule is violated.
  variant,
}

@immutable
class PlayError implements Exception {
  final String message;
  const PlayError(this.message);

  @override
  String toString() => 'PlayError($message)';
}

/// Error when trying to create a [Position] from an illegal [Setup].
@immutable
class PositionError implements Exception {
  final IllegalSetup cause;
  const PositionError(this.cause);

  static const PositionError empty = PositionError(IllegalSetup.empty);
  static const PositionError oppositeCheck =
      PositionError(IllegalSetup.oppositeCheck);
  static const PositionError impossibleCheck =
      PositionError(IllegalSetup.impossibleCheck);
  static const PositionError pawnsOnBackrank =
      PositionError(IllegalSetup.pawnsOnBackrank);
  static const PositionError kings = PositionError(IllegalSetup.kings);
  static const PositionError variant = PositionError(IllegalSetup.variant);

  @override
  String toString() => 'PositionError(${cause.name})';
}

@immutable
class Castles {
  /// SquareSet of rooks that have not moved yet.
  final SquareSet unmovedRooks;

  final Square? _whiteRookQueenSide;
  final Square? _whiteRookKingSide;
  final Square? _blackRookQueenSide;
  final Square? _blackRookKingSide;
  final SquareSet _whitePathQueenSide;
  final SquareSet _whitePathKingSide;
  final SquareSet _blackPathQueenSide;
  final SquareSet _blackPathKingSide;

  const Castles({
    required this.unmovedRooks,
    required Square? whiteRookQueenSide,
    required Square? whiteRookKingSide,
    required Square? blackRookQueenSide,
    required Square? blackRookKingSide,
    required SquareSet whitePathQueenSide,
    required SquareSet whitePathKingSide,
    required SquareSet blackPathQueenSide,
    required SquareSet blackPathKingSide,
  })  : _whiteRookQueenSide = whiteRookQueenSide,
        _whiteRookKingSide = whiteRookKingSide,
        _blackRookQueenSide = blackRookQueenSide,
        _blackRookKingSide = blackRookKingSide,
        _whitePathQueenSide = whitePathQueenSide,
        _whitePathKingSide = whitePathKingSide,
        _blackPathQueenSide = blackPathQueenSide,
        _blackPathKingSide = blackPathKingSide;

  static const Castles standard = Castles(
    unmovedRooks: SquareSet.corners,
    whiteRookQueenSide: Squares.a1,
    whiteRookKingSide: Squares.h1,
    blackRookQueenSide: Squares.a8,
    blackRookKingSide: Squares.h8,
    whitePathQueenSide: SquareSet(0x000000000000000e),
    whitePathKingSide: SquareSet(0x0000000000000060),
    blackPathQueenSide: SquareSet(0x0e00000000000000),
    blackPathKingSide: SquareSet(0x6000000000000000),
  );

  static const Castles empty = Castles(
    unmovedRooks: SquareSet.empty,
    whiteRookQueenSide: null,
    whiteRookKingSide: null,
    blackRookQueenSide: null,
    blackRookKingSide: null,
    whitePathQueenSide: SquareSet.empty,
    whitePathKingSide: SquareSet.empty,
    blackPathQueenSide: SquareSet.empty,
    blackPathKingSide: SquareSet.empty,
  );

  factory Castles.fromSetup(Setup setup) {
    Castles castles = Castles.empty;
    final SquareSet rooks = setup.unmovedRooks & setup.board.rooks;
    for (final Side side in Side.values) {
      final SquareSet backrank = SquareSet.backrankOf(side);
      final Square? king = setup.board.kingOf(side);
      if (king == null || !backrank.has(king)) continue;
      final SquareSet backrankRooks =
          rooks & setup.board.bySide(side) & backrank;
      if (backrankRooks.first != null && backrankRooks.first! < king) {
        castles =
            castles._add(side, CastlingSide.queen, king, backrankRooks.first!);
      }
      if (backrankRooks.last != null && king < backrankRooks.last!) {
        castles =
            castles._add(side, CastlingSide.king, king, backrankRooks.last!);
      }
    }
    return castles;
  }

  /// Gets rooks positions by side and castling side.
  BySide<ByCastlingSide<Square?>> get rooksPositions {
    return BySide<ByCastlingSide<Square?>>(
      <Side, ByCastlingSide<Square?>>{
        Side.white: ByCastlingSide<Square?>(
          <CastlingSide, int?>{
            CastlingSide.queen: _whiteRookQueenSide,
            CastlingSide.king: _whiteRookKingSide,
          },
        ),
        Side.black: ByCastlingSide<Square?>(
          <CastlingSide, int?>{
            CastlingSide.queen: _blackRookQueenSide,
            CastlingSide.king: _blackRookKingSide,
          },
        ),
      },
    );
  }

  /// Gets rooks paths by side and castling side.
  BySide<ByCastlingSide<SquareSet>> get paths {
    return BySide<ByCastlingSide<SquareSet>>(
      <Side, ByCastlingSide<SquareSet>>{
        Side.white: ByCastlingSide<SquareSet>(
          <CastlingSide, SquareSet>{
            CastlingSide.queen: _whitePathQueenSide,
            CastlingSide.king: _whitePathKingSide,
          },
        ),
        Side.black: ByCastlingSide<SquareSet>(
          <CastlingSide, SquareSet>{
            CastlingSide.queen: _blackPathQueenSide,
            CastlingSide.king: _blackPathKingSide,
          },
        ),
      },
    );
  }

  /// Gets the rook [Square] by side and castling side.
  Square? rookOf(Side side, CastlingSide cs) => cs == CastlingSide.queen
      ? side == Side.white
          ? _whiteRookQueenSide
          : _blackRookQueenSide
      : side == Side.white
          ? _whiteRookKingSide
          : _blackRookKingSide;

  /// Gets the squares that need to be empty so that castling is possible
  /// on the given side.
  ///
  /// We're assuming the player still has the required castling rigths.
  SquareSet pathOf(Side side, CastlingSide cs) => cs == CastlingSide.queen
      ? side == Side.white
          ? _whitePathQueenSide
          : _blackPathQueenSide
      : side == Side.white
          ? _whitePathKingSide
          : _blackPathKingSide;

  Castles discardRookAt(Square square) {
    return _copyWith(
      unmovedRooks: unmovedRooks.withoutSquare(square),
      whiteRookQueenSide:
          _whiteRookQueenSide == square ? const Box<int?>(null) : null,
      whiteRookKingSide:
          _whiteRookKingSide == square ? const Box<int?>(null) : null,
      blackRookQueenSide:
          _blackRookQueenSide == square ? const Box<int?>(null) : null,
      blackRookKingSide:
          _blackRookKingSide == square ? const Box<int?>(null) : null,
    );
  }

  Castles discardSide(Side side) {
    return _copyWith(
      unmovedRooks: unmovedRooks.diff(SquareSet.backrankOf(side)),
      whiteRookQueenSide: side == Side.white ? const Box<int?>(null) : null,
      whiteRookKingSide: side == Side.white ? const Box<int?>(null) : null,
      blackRookQueenSide: side == Side.black ? const Box<int?>(null) : null,
      blackRookKingSide: side == Side.black ? const Box<int?>(null) : null,
    );
  }

  Castles _add(Side side, CastlingSide cs, Square king, Square rook) {
    final Square kingTo = _kingCastlesTo(side, cs);
    final Square rookTo = _rookCastlesTo(side, cs);
    final SquareSet path = between(rook, rookTo)
        .withSquare(rookTo)
        .union(between(king, kingTo).withSquare(kingTo))
        .withoutSquare(king)
        .withoutSquare(rook);
    return _copyWith(
      unmovedRooks: unmovedRooks.withSquare(rook),
      whiteRookQueenSide: side == Side.white && cs == CastlingSide.queen
          ? Box<int?>(rook)
          : null,
      whiteRookKingSide: side == Side.white && cs == CastlingSide.king
          ? Box<int?>(rook)
          : null,
      blackRookQueenSide: side == Side.black && cs == CastlingSide.queen
          ? Box<int?>(rook)
          : null,
      blackRookKingSide: side == Side.black && cs == CastlingSide.king
          ? Box<int?>(rook)
          : null,
      whitePathQueenSide:
          side == Side.white && cs == CastlingSide.queen ? path : null,
      whitePathKingSide:
          side == Side.white && cs == CastlingSide.king ? path : null,
      blackPathQueenSide:
          side == Side.black && cs == CastlingSide.queen ? path : null,
      blackPathKingSide:
          side == Side.black && cs == CastlingSide.king ? path : null,
    );
  }

  Castles _copyWith({
    SquareSet? unmovedRooks,
    Box<Square?>? whiteRookQueenSide,
    Box<Square?>? whiteRookKingSide,
    Box<Square?>? blackRookQueenSide,
    Box<Square?>? blackRookKingSide,
    SquareSet? whitePathQueenSide,
    SquareSet? whitePathKingSide,
    SquareSet? blackPathQueenSide,
    SquareSet? blackPathKingSide,
  }) {
    return Castles(
      unmovedRooks: unmovedRooks ?? this.unmovedRooks,
      whiteRookQueenSide: whiteRookQueenSide != null
          ? whiteRookQueenSide.value
          : _whiteRookQueenSide,
      whiteRookKingSide: whiteRookKingSide != null
          ? whiteRookKingSide.value
          : _whiteRookKingSide,
      blackRookQueenSide: blackRookQueenSide != null
          ? blackRookQueenSide.value
          : _blackRookQueenSide,
      blackRookKingSide: blackRookKingSide != null
          ? blackRookKingSide.value
          : _blackRookKingSide,
      whitePathQueenSide: whitePathQueenSide ?? _whitePathQueenSide,
      whitePathKingSide: whitePathKingSide ?? _whitePathKingSide,
      blackPathQueenSide: blackPathQueenSide ?? _blackPathQueenSide,
      blackPathKingSide: blackPathKingSide ?? _blackPathKingSide,
    );
  }

  @override
  String toString() {
    return 'Castles(unmovedRooks: $unmovedRooks)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Castles &&
          other.unmovedRooks == unmovedRooks &&
          other._whiteRookQueenSide == _whiteRookQueenSide &&
          other._whiteRookKingSide == _whiteRookKingSide &&
          other._blackRookQueenSide == _blackRookQueenSide &&
          other._blackRookKingSide == _blackRookKingSide &&
          other._whitePathQueenSide == _whitePathQueenSide &&
          other._whitePathKingSide == _whitePathKingSide &&
          other._blackPathQueenSide == _blackPathQueenSide &&
          other._blackPathKingSide == _blackPathKingSide;

  @override
  int get hashCode => Object.hash(
        unmovedRooks,
        _whiteRookQueenSide,
        _whiteRookKingSide,
        _blackRookQueenSide,
        _blackRookKingSide,
        _whitePathQueenSide,
        _whitePathKingSide,
        _blackPathQueenSide,
        _blackPathKingSide,
      );
}

@immutable
class _Context {
  const _Context({
    required this.isVariantEnd,
    required this.king,
    required this.blockers,
    required this.checkers,
    required this.mustCapture,
  });

  final bool isVariantEnd;
  final bool mustCapture;
  final Square? king;
  final SquareSet blockers;
  final SquareSet checkers;

  _Context copyWith({
    bool? isVariantEnd,
    bool? mustCapture,
    Square? king,
    SquareSet? blockers,
    SquareSet? checkers,
  }) {
    return _Context(
      isVariantEnd: isVariantEnd ?? this.isVariantEnd,
      mustCapture: mustCapture ?? this.mustCapture,
      king: king,
      blockers: blockers ?? this.blockers,
      checkers: checkers ?? this.checkers,
    );
  }
}

Square _rookCastlesTo(Side side, CastlingSide cs) {
  return side == Side.white
      ? (cs == CastlingSide.queen ? Squares.d1 : Squares.f1)
      : cs == CastlingSide.queen
          ? Squares.d8
          : Squares.f8;
}

Square _kingCastlesTo(Side side, CastlingSide cs) {
  return side == Side.white
      ? (cs == CastlingSide.queen ? Squares.c1 : Squares.g1)
      : cs == CastlingSide.queen
          ? Squares.c8
          : Squares.g8;
}

Square? _validEpSquare(Setup setup) {
  if (setup.epSquare == null) return null;
  final int epRank = setup.turn == Side.white ? 5 : 2;
  final int forward = setup.turn == Side.white ? 8 : -8;
  if (squareRank(setup.epSquare!) != epRank) return null;
  if (setup.board.occupied.has(setup.epSquare! + forward)) return null;
  final int pawn = setup.epSquare! - forward;
  if (!setup.board.pawns.has(pawn) ||
      !setup.board.bySide(setup.turn.opposite).has(pawn)) {
    return null;
  }
  return setup.epSquare;
}

SquareSet _pseudoLegalMoves(
  Position<Position<dynamic>> pos,
  Square square,
  _Context context,
) {
  if (pos.isVariantEnd) return SquareSet.empty;
  final Piece? piece = pos.board.pieceAt(square);
  if (piece == null || piece.color != pos.turn) return SquareSet.empty;

  SquareSet pseudo = attacks(piece, square, pos.board.occupied);
  if (piece.role == Role.pawn) {
    SquareSet captureTargets = pos.board.bySide(pos.turn.opposite);
    if (pos.epSquare != null) {
      captureTargets = captureTargets.withSquare(pos.epSquare!);
    }
    pseudo = pseudo & captureTargets;
    final int delta = pos.turn == Side.white ? 8 : -8;
    final int step = square + delta;
    if (0 <= step && step < 64 && !pos.board.occupied.has(step)) {
      pseudo = pseudo.withSquare(step);
      final bool canDoubleStep =
          pos.turn == Side.white ? square < 16 : square >= 64 - 16;
      final int doubleStep = step + delta;
      if (canDoubleStep && !pos.board.occupied.has(doubleStep)) {
        pseudo = pseudo.withSquare(doubleStep);
      }
    }
    return pseudo;
  } else {
    pseudo = pseudo.diff(pos.board.bySide(pos.turn));
  }
  if (square == context.king) {
    return pseudo
        .union(pos._castlingMove(CastlingSide.queen, context))
        .union(pos._castlingMove(CastlingSide.king, context));
  } else {
    return pseudo;
  }
}
