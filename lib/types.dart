import 'equal.dart';
import 'const.dart';
import 'state.dart';

const Map<int, Square> kSquares = <int, Square>{
  0: Square.a8,
  1: Square.b8,
  2: Square.c8,
  3: Square.d8,
  4: Square.e8,
  5: Square.f8,
  6: Square.g8,
  7: Square.h8,
  16: Square.a7,
  17: Square.b7,
  18: Square.c7,
  19: Square.d7,
  20: Square.e7,
  21: Square.f7,
  22: Square.g7,
  23: Square.h7,
  32: Square.a6,
  33: Square.b6,
  34: Square.c6,
  35: Square.d6,
  36: Square.e6,
  37: Square.f6,
  38: Square.g6,
  39: Square.h6,
  48: Square.a5,
  49: Square.b5,
  50: Square.c5,
  51: Square.d5,
  52: Square.e5,
  53: Square.f5,
  54: Square.g5,
  55: Square.h5,
  64: Square.a4,
  65: Square.b4,
  66: Square.c4,
  67: Square.d4,
  68: Square.e4,
  69: Square.f4,
  70: Square.g4,
  71: Square.h4,
  80: Square.a3,
  81: Square.b3,
  82: Square.c3,
  83: Square.d3,
  84: Square.e3,
  85: Square.f3,
  86: Square.g3,
  87: Square.h3,
  96: Square.a2,
  97: Square.b2,
  98: Square.c2,
  99: Square.d2,
  100: Square.e2,
  101: Square.f2,
  102: Square.g2,
  103: Square.h2,
  112: Square.a1,
  113: Square.b1,
  114: Square.c1,
  115: Square.d1,
  116: Square.e1,
  117: Square.f1,
  118: Square.g1,
  119: Square.h1,
};

enum Square {
  a8(0),
  b8(1),
  c8(2),
  d8(3),
  e8(4),
  f8(5),
  g8(6),
  h8(7),
  a7(16),
  b7(17),
  c7(18),
  d7(19),
  e7(20),
  f7(21),
  g7(22),
  h7(23),
  a6(32),
  b6(33),
  c6(34),
  d6(35),
  e6(36),
  f6(37),
  g6(38),
  h6(39),
  a5(48),
  b5(49),
  c5(50),
  d5(51),
  e5(52),
  f5(53),
  g5(54),
  h5(55),
  a4(64),
  b4(65),
  c4(66),
  d4(67),
  e4(68),
  f4(69),
  g4(70),
  h4(71),
  a3(80),
  b3(81),
  c3(82),
  d3(83),
  e3(84),
  f3(85),
  g3(86),
  h3(87),
  a2(96),
  b2(97),
  c2(98),
  d2(99),
  e2(100),
  f2(101),
  g2(102),
  h2(103),
  a1(112),
  b1(113),
  c1(114),
  d1(115),
  e1(116),
  f1(117),
  g1(118),
  h1(119);

  const Square(this.bits);

  final int bits;

  static Square? fromNotation(String notation) {
    if (notation.length != 2) return null;

    final int? rank = int.tryParse(notation[1]);
    final String file = notation[0];

    if (rank == null || !'abcdefgh'.contains(file)) return null;

    final int index = (8 - rank) * 16 + 'abcdefgh'.indexOf(file);

    return Square.fromBits(index);
  }

  static Square? fromBits(int bits) {
    return kSquares[bits];
  }

  String get notation => name;

  static const Square last = Square.h1;
  static const Square first = Square.a8;

  PieceColor get color {
    final int rankIndex = index ~/ 8;
    final int fileIndex = index % 8;

    return (fileIndex + (rankIndex.isEven ? 0 : 1)).isEven
        ? PieceColor.white
        : PieceColor.black;
  }
}

extension IsChessPiece on String {
  bool isChessPieceSymbol() =>
      length == 1 && PieceSymbol.fromChar(this) != null;
  bool isChessSquare() => length == 2 && Square.fromNotation(this) != null;
  PieceSymbol toChessPieceSymbol() => PieceSymbol.fromChar(this)!;
  Square toChessSquare() => Square.fromNotation(this)!;
}

enum PieceSymbol {
  pawn('p', <int>[]),
  knight('n', <int>[-18, -33, -31, -14, 18, 33, 31, 14]),
  bishop('b', <int>[-17, -15, 17, 15]),
  rook('r', <int>[-16, 1, 16, -1]),
  queen('q', <int>[-17, -16, -15, 1, 17, 16, 15, -1]),
  king('k', <int>[-17, -16, -15, 1, 17, 16, 15, -1]);

  const PieceSymbol(this.notation, this.offsets);

  static PieceSymbol? fromChar(String char) {
    switch (char.toLowerCase()) {
      case 'p':
        return PieceSymbol.pawn;
      case 'n':
        return PieceSymbol.knight;
      case 'b':
        return PieceSymbol.bishop;
      case 'r':
        return PieceSymbol.rook;
      case 'q':
        return PieceSymbol.queen;
      case 'k':
        return PieceSymbol.king;
    }

    return null;
  }

  final String notation;
  final List<int> offsets;

  bool get isPawn => this == PieceSymbol.pawn;
  bool get isKnight => this == PieceSymbol.knight;
  bool get isBishop => this == PieceSymbol.bishop;
  bool get isRook => this == PieceSymbol.rook;
  bool get isQueen => this == PieceSymbol.queen;
  bool get isKing => this == PieceSymbol.king;
}

const PieceSymbol pawn = PieceSymbol.pawn;
const PieceSymbol knight = PieceSymbol.knight;
const PieceSymbol bishop = PieceSymbol.bishop;
const PieceSymbol rook = PieceSymbol.rook;
const PieceSymbol queen = PieceSymbol.queen;
const PieceSymbol king = PieceSymbol.king;

class PartialMove {
  final Square to;
  final Square from;
  final PieceSymbol? promotion;

  const PartialMove({required this.to, required this.from, this.promotion});

  @override
  bool operator ==(Object other) {
    return other is PartialMove &&
        from == other.from &&
        to == other.to &&
        promotion == other.promotion;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[from, to, promotion]);

  @override
  String toString() {
    return 'PartialMove(to: $to, from: $from, promotion: $promotion)';
  }
}

extension BitMaskSquare0x88 on int {
  /// Off-the-board detection is a feature of chess programs which determines
  /// whether a piece is on or off the legal chess board.
  ///
  /// In 0x88, the highest bit of each nibble represents whether a piece
  /// is on the board or not. Specifically, out of the 8 bits to represent
  /// a square, the fourth and the eighth must both be 0 for a piece to be
  /// located within the board.[4] This allows off-the-board detection by
  /// bitwise [&] operations.
  ///
  /// If [this] square AND 0x88 (or, in binary, 0b10001000) is non-zero,
  /// then the square is not on the board. This bitwise operation
  /// requires fewer computer resources than integer comparisons.
  ///
  /// This makes calculations such as illegal move detection faster.
  bool get off => isNonZero(0x88);

  bool isNonZero(int other) => this & other != 0;

  Square toSquare() => Square.fromBits(this)!;

  bool isSquare() => Square.fromBits(this) != null;
}

extension MergeFlags on List<Flag> {
  int get bits => <int>[0, ...map((Flag flag) => flag.bits)]
      .reduce((int flags, int flag) => flags | flag);
}

enum Flag {
  /// A non-capture.
  normal('n', 'NORMAL', 1),

  /// A pawn push of two squares.
  bigPawn('b', 'BIG_PAWN', 2),

  // An en passant capture.
  enPassantCapture('e', 'EP_CAPTURE', 4),

  /// A standard capture.
  capture('c', 'CAPTURE', 8),

  /// A promotion.
  promotion('p', 'PROMOTION', 16),

  /// Kingside castling.
  kingSideCastle('k', 'KSIDE_CASTLE', 32),

  /// Queenside castling.
  queenSideCastle('q', 'QSIDE_CASTLE', 64);

  const Flag(this.notation, this.key, this.bits);

  static Flag? fromNotation(String char) {
    final String c = char.toLowerCase();

    for (final Flag flag in Flag.values) {
      if (flag.notation == c) {
        return flag;
      }
    }

    return null;
  }

  final String notation;

  /// Returns the following char for the following enum values:
  ///
  /// - 'n' for [normal].
  /// - 'b' for [pawnPush].
  /// - 'e' for [enPassant].
  /// - 'c' for [capture].
  /// - 'p' for [promotion].
  /// - 'k' for [kingsideCastle].
  /// - 'q' for [queensideCastle].
  final String key;

  /// Flag.normal: 1, // NORMAL
  /// Flag.capture: 2, // CAPTURE
  /// Flag.pawnPush: 4, // BIG_PAWN
  /// Flag.enPassant: 8, // EP_CAPTURE
  /// Flag.promotion: 16, // PROMOTION
  /// Flag.kingSideCastle: 32, // KSIDE_CASTLE
  /// Flag.queenSideCastle: 64 // QSIDE_CASTLE
  final int bits;

  // Alternative implementation that doesn't requires [bit] argument
  // but needs to compute it at runtime.
  // int get bit => pow(2, index) ~/ 1;
}

class Move extends PartialMove {
  final PieceColor color;
  final List<Flag> flags;
  final PieceSymbol piece;
  final String san;
  final PieceSymbol? captured;

  const Move({
    required super.to,
    required super.from,
    super.promotion,
    required this.color,
    this.flags = const <Flag>[],
    required this.piece,
    required this.san,
    this.captured,
  });

  @override
  bool operator ==(Object other) {
    return other is Move &&
        to == other.to &&
        from == other.from &&
        promotion == other.promotion &&
        color == other.color &&
        flags.bits == other.flags.bits &&
        piece == other.piece &&
        san == other.san &&
        captured == other.captured;
  }

  @override
  int get hashCode => Object.hashAll(
        <Object?>[
          from,
          to,
          promotion,
          color,
          flags.bits,
          piece,
          san,
          captured,
        ],
      );

  @override
  String toString() {
    return 'Move(to: $to, from: $from, promotion: $promotion, color: $color, flags: $flags, piece: $piece, san: $san, captured: $captured)';
  }
}

class HexMove {
  final Square to;
  final Square from;
  final PieceColor color;
  final List<Flag> flags;
  final PieceSymbol piece;
  final PieceSymbol? captured;
  final PieceSymbol? promotion;
  final String? san;

  const HexMove({
    required this.to,
    required this.from,
    required this.color,
    required this.flags,
    required this.piece,
    this.captured,
    this.promotion,
    this.san,
  });

  HexMove clone({
    Square? to,
    Square? from,
    PieceColor? color,
    List<Flag>? flags,
    PieceSymbol? piece,
    PieceSymbol? captured,
    PieceSymbol? promotion,
    String? san,
  }) {
    return HexMove(
      to: to ?? this.to,
      from: from ?? this.from,
      color: color ?? this.color,
      flags: List<Flag>.of(flags ?? this.flags),
      piece: piece ?? this.piece,
      promotion: promotion ?? this.promotion,
      captured: captured ?? this.captured,
      san: san ?? this.san,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Move &&
        to == other.to &&
        from == other.from &&
        promotion == other.promotion &&
        color == other.color &&
        flags.bits == other.flags.bits &&
        piece == other.piece &&
        san == other.san &&
        captured == other.captured;
  }

  @override
  int get hashCode => Object.hashAll(
        <Object?>[
          from,
          to,
          promotion,
          color,
          flags.bits,
          piece,
          san,
          captured,
        ],
      );

  @override
  String toString() {
    return 'HexMove(to: $to, from: $from, promotion: $promotion, color: $color, flags: $flags, piece: $piece, san: $san, captured: $captured)';
  }
}

class GameHistory {
  final HexMove move;
  final State state;

  const GameHistory({required this.state, required this.move});

  @override
  bool operator ==(Object other) {
    return other is GameHistory && move == other.move && state == other.state;
  }

  @override
  int get hashCode => Object.hashAll(
        <Object?>[
          move,
          state,
        ],
      );
}

class State {
  final Board board;
  final ColorState kings;
  final PieceColor turn;
  final ColorState castling;
  final int epSquare;
  final int halfMoves;
  final int moveNumber;

  const State({
    required this.board,
    required this.kings,
    required this.turn,
    required this.castling,
    required this.epSquare,
    required this.halfMoves,
    required this.moveNumber,
  }) : assert(board.length == 128);

  factory State.create({
    PieceColor? turn,
    Map<PieceColor, int>? castling,
    Map<PieceColor, int>? kings,
    int? epSquare,
    int? halfMoves,
    int? moveNumber,
  }) {
    final List<Piece?> board = List<Piece?>.filled(128, null);

    return State(
      board: List<Piece?>.unmodifiable(board),
      kings: kings ??
          Map<PieceColor, int>.unmodifiable(
            <PieceColor, int>{
              white: kEmpty,
              black: kEmpty,
            },
          ),
      turn: turn ?? white,
      castling: castling ??
          Map<PieceColor, int>.unmodifiable(
            <PieceColor, int>{
              white: 0,
              black: 0,
            },
          ),
      epSquare: epSquare ?? kEmpty,
      halfMoves: halfMoves ?? 0,
      moveNumber: moveNumber ?? 1,
    );
  }

  State modifyKing(PieceColor color, int value) {
    return clone(
      kings: Map<PieceColor, int>.from(kings)..[color] = value,
    );
  }

  State modifyCastling(PieceColor color, int value) {
    return clone(
      castling: Map<PieceColor, int>.from(castling)..[color] = value,
    );
  }

  State modifyPiece(Square square, Piece? piece) {
    return clone(
      board: List<Piece?>.from(board)..[square.bits] = piece,
    );
  }

  State clone({
    List<Piece?>? board,
    Map<PieceColor, int>? kings,
    PieceColor? turn,
    Map<PieceColor, int>? castling,
    int? epSquare,
    int? halfMoves,
    int? moveNumber,
  }) {
    return State(
      board: List<Piece?>.unmodifiable(List<Piece?>.of(board ?? this.board)),
      kings: Map<PieceColor, int>.unmodifiable(
        Map<PieceColor, int>.of(kings ?? this.kings),
      ),
      turn: turn ?? this.turn,
      castling: Map<PieceColor, int>.unmodifiable(
        Map<PieceColor, int>.of(castling ?? this.castling),
      ),
      epSquare: epSquare ?? this.epSquare,
      halfMoves: halfMoves ?? this.halfMoves,
      moveNumber: moveNumber ?? this.moveNumber,
    );
  }

  String get fen => getFen(this);

  @override
  bool operator ==(Object other) {
    if (other is! State) return false;

    return board.equals(other.board) &&
        kings.equals(other.kings) &&
        turn == other.turn &&
        castling.equals(other.castling) &&
        epSquare == other.epSquare &&
        halfMoves == other.halfMoves &&
        moveNumber == other.moveNumber;
  }

  @override
  int get hashCode => Object.hashAll(
        <Object?>[
          ...board,
          kings.equalityHashCode,
          turn,
          castling.equalityHashCode,
          epSquare,
          halfMoves,
          moveNumber,
        ],
      );
}

extension MapEqualityHashCode<K, V> on Map<K, V> {
  int get equalityHashCode {
    return Object.hashAllUnordered(
      <Object?>[
        // Generate a hash for each map entry.
        for (final MapEntry<K, V> e in entries) Object.hash(e.key, e.value),
      ],
    );
  }
}

enum PieceColor {
  white(
    'w',
    pawnOffsets: <int>[-16, -32, -17, -15],
    rooks: <Flag, Square>{
      Flag.queenSideCastle: a1,
      Flag.kingSideCastle: h1,
    },
  ),
  black(
    'b',
    pawnOffsets: <int>[16, 32, 17, 15],
    rooks: <Flag, Square>{
      Flag.queenSideCastle: a8,
      Flag.kingSideCastle: h8,
    },
  );

  const PieceColor(
    this.notation, {
    required this.pawnOffsets,
    required this.rooks,
  });

  final String notation;

  /// Returns the opposite color.
  PieceColor swap() {
    return this == PieceColor.white ? PieceColor.black : PieceColor.white;
  }

  bool get isWhite => this == PieceColor.white;
  bool get isBlack => this == PieceColor.black;

  final List<int> pawnOffsets;
  final Map<Flag, Square> rooks;

  static PieceColor fromChar(String char) {
    return char.toLowerCase() == PieceColor.black.notation
        ? PieceColor.black
        : PieceColor.white;
  }
}

const PieceColor white = PieceColor.white;
const PieceColor black = PieceColor.black;

class FenComment {
  final String fen;
  final String comment;

  const FenComment({required this.fen, required this.comment});
}

enum Piece {
  blackPawn(PieceSymbol.pawn, PieceColor.black),
  whitePawn(PieceSymbol.pawn, PieceColor.white),

  blackKnight(PieceSymbol.knight, PieceColor.black),
  whiteKnight(PieceSymbol.knight, PieceColor.white),

  blackBishop(PieceSymbol.bishop, PieceColor.black),
  whiteBishop(PieceSymbol.bishop, PieceColor.white),

  blackRook(PieceSymbol.rook, PieceColor.black),
  whiteRook(PieceSymbol.rook, PieceColor.white),

  blackQueen(PieceSymbol.queen, PieceColor.black),
  whiteQueen(PieceSymbol.queen, PieceColor.white),

  blackKing(PieceSymbol.king, PieceColor.black),
  whiteKing(PieceSymbol.king, PieceColor.white);

  const Piece(this.symbol, this.color);

  factory Piece.fromSymbolAndColor(PieceSymbol symbol, PieceColor color) {
    for (final Piece e in Piece.values) {
      if (e.color == color && e.symbol == symbol) return e;
    }
    throw Exception('Never. Piece of $symbol $color.');
  }

  static Piece? fromSymbolAndColorChar(String symbolAndColor) {
    if (symbolAndColor.length != 2 || !symbolAndColor[0].isChessPieceSymbol()) {
      return null;
    }

    return Piece.fromSymbolAndColor(
      PieceSymbol.fromChar(symbolAndColor[0])!,
      PieceColor.fromChar(symbolAndColor[1]),
    );
  }

  final PieceSymbol symbol;
  final PieceColor color;

  // Returns the ASCII symbol for each piece.
  // White pieces are in uppercase, black in lowercase.
  String get notation => color == PieceColor.black
      ? symbol.notation.toLowerCase()
      : symbol.notation.toUpperCase();
}

typedef Board = List<Piece?>;

typedef ColorState = Map<PieceColor, int>;

typedef Comments = Map<String?, String?>;

typedef Header = Map<String, String>;
