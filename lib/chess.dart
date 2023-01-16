import 'const.dart' as c;
import 'state.dart' as s;
import 'types.dart' as t;
import 'utils.dart' as u;

class Chess {
  late t.State _state;
  late List<t.GameHistory> _history;

  /// PGN header information as an object.
  ///
  /// @example
  /// ```js
  /// chess.header()
  /// // -> { White: 'Morphy', Black: 'Anderssen', Date: '1858-??-??' }
  /// ```
  late t.Header header;
  late t.Comments _comments;

  Chess._({
    required t.State state,
    required List<t.GameHistory> history,
    required t.Comments comments,
    required this.header,
  })  : _state = state,
        _history = history,
        _comments = comments;

  /// The Chess() constructor takes an optional parameter which specifies the board configuration
  /// in [Forsyth-Edwards Notation](http://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation).
  ///
  /// @example
  /// ```dart
  /// // board defaults to the starting position when called with no parameters.
  /// final chess = Chess();
  ///
  /// // pass in a FEN string to load a particular position
  /// final chess = Chess(
  ///   'r1k4r/p2nb1p1/2b4p/1p1n1p2/2PP4/3Q1NB1/1P3PPP/R5K1 b - c3 0 19'
  /// )
  /// ```
  Chess.create([String fen = c.kDefaultPosition]) {
    _state = t.State.create();
    _history = <t.GameHistory>[];
    header = <String, String>{};
    _comments = <String, String>{};

    final bool successfulyLoaded = load(fen);

    if (!successfulyLoaded) {
      throw Exception('Error loading fen');
    }
  }

  /// Returns the FEN string for the current position.
  ///
  /// @example
  /// ```dart
  /// Chess chess = Chess.create()
  ///
  /// // make some moves
  /// chess.move('e4');
  /// chess.move('e5');
  /// chess.move('f4');
  ///
  /// chess.fen()
  /// // -> 'rnbqkbnr/pppp1ppp/8/4p3/4PP2/8/PPPP2PP/RNBQKBNR b KQkq f3 0 2'
  /// ```
  String fen() {
    return _state.fen;
  }

  /// Attempts to make a move on the board, returning a move object if the move was
  /// legal, otherwise null. The .move function can be called two ways, by passing
  /// a string in Standard Algebraic Notation (SAN):
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  ///
  /// chess.move('e4')
  /// // -> { color: 'w', from: 'e2', to: 'e4', flags: 'b', piece: 'p', san: 'e4' }
  ///
  /// chess.move('nf6') // SAN is case sensitive!!
  /// // -> null
  ///
  /// chess.move('Nf6')
  /// // -> { color: 'b', from: 'g8', to: 'f6', flags: 'n', piece: 'n', san: 'Nf6' }
  /// ```
  ///
  ///
  /// Or by passing .move() a move object (only the 'to', 'from', and when necessary
  /// 'promotion', fields are needed):
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  ///
  /// chess.move({ from: 'g2', to: 'g3' })
  /// // -> { color: 'w', from: 'g2', to: 'g3', flags: 'n', piece: 'p', san: 'g3' }
  /// ```
  ///
  /// An optional sloppy flag can be used to parse a variety of non-standard move
  /// notations:
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  ///
  /// // various forms of Long Algebraic Notation
  /// chess.move('e2e4', sloppy: true)
  /// // -> { color: 'w', from: 'e2', to: 'e4', flags: 'b', piece: 'p', san: 'e4' }
  /// chess.move('e7-e5', sloppy: true)
  /// // -> { color: 'b', from: 'e7', to: 'e5', flags: 'b', piece: 'p', san: 'e5' }
  /// chess.move('Pf2f4', sloppy: true)
  /// // -> { color: 'w', from: 'f2', to: 'f4', flags: 'b', piece: 'p', san: 'f4' }
  /// chess.move('Pe5xf4', sloppy: true)
  /// // -> { color: 'b', from: 'e5', to: 'f4', flags: 'c', piece: 'p', captured: 'p', san: 'exf4' }
  ///
  /// // correctly parses incorrectly disambiguated moves
  /// chess = new Chess(
  ///     'r2qkbnr/ppp2ppp/2n5/1B2pQ2/4P3/8/PPP2PPP/RNB1K2R b KQkq - 3 7'
  /// )
  ///
  /// chess.move('Nge7') // Ne7 is unambiguous because the knight on c6 is pinned
  /// // -> null
  ///
  /// chess.move('Nge7', sloppy: true)
  /// // -> { color: 'b', from: 'g8', to: 'e7', flags: 'n', piece: 'n', san: 'Ne7' }
  /// ```
  ///
  /// @param move - Case-sensitive SAN string or object, e.g. `'Nxb7'` or
  /// `{ from: 'h7', to: 'h8', promotion: 'q' }`
  /// @param options - Options to enable parsing of a variety of non-standard
  /// move notations
  t.Move? move({
    bool sloppy = false,
    bool dryRun = false,
    String? san,
    t.Square? from,
    t.Square? to,
    t.PieceSymbol? promotion,
  }) {
    if (san == null && (from == null && to == null)) {
      return null;
    }

    late final t.HexMove? validMove;

    if (san != null) {
      validMove = s.sanToMove(_state, san, sloppy: sloppy);
    } else {
      validMove = s.validateMove(
        state: state,
        move: t.PartialMove(from: from!, to: to!, promotion: promotion),
      );
    }

    if (validMove == null) {
      return null;
    }

    // Create pretty move before updating the state
    final t.Move prettyMove = s.makePretty(_state, validMove);

    if (!dryRun) {
      makeMove(validMove);
    }

    return prettyMove;
  }

  /// Validates a sequence of moves, returning an array of move objects if the
  /// moves are all legal, otherwise null.
  ///
  /// @example
  /// ```dart
  /// final chess = Chess.create();
  ///
  /// chess.validateMoves(['e4', 'Nf6'])
  /// // -> [{ color: 'w', from: 'e2', to: 'e4', flags: 'b', piece: 'p', san: 'e4' },
  ///        { color: 'b', from: 'g8', to: 'f6', flags: 'n', piece: 'n', san: 'Nf6' }]
  ///
  /// chess.validateMoves(['e4, 'nf6']); // SAN is case sensitive!
  /// // -> null
  /// ```
  ///
  /// @param moves - Array of case-sensitive SAN strings or objects, e.g. `'Nxb7'` or
  /// `{ from: 'h7', to: 'h8', promotion: 'q' }`
  /// @param options - Options to enable parsing of a variety of non-standard
  /// move notations.
  List<t.Move>? validateMoves(List<String> moves, {bool sloppy = false}) {
    final List<t.Move> validMoves = <t.Move>[];

    t.State state = _state.clone();

    for (final String move in moves) {
      final t.HexMove? validMove = s.sanToMove(state, move, sloppy: sloppy);

      if (validMove == null) {
        return null;
      }

      validMoves.add(s.makePretty(state, validMove));
      state = s.makeMove(state, validMove);
    }

    return validMoves;
  }

  /// Checks if a move results in a promotion.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  ///
  /// chess.isPromotion('e4')
  /// // -> false
  ///
  /// chess.load('8/2P2k2/8/8/8/5K2/8/8 w - - 0 1')
  /// chess.isPromotion('c8')
  /// // -> true
  /// ```
  ///
  /// @param move - Case-sensitive SAN string or object, e.g. `'Nxb7'` or
  /// `{ from: 'h7', to: 'h8' }`
  /// @param options - Options to enable parsing of a variety of non-standard
  /// move notations
  bool isPromotion({
    String? san,
    bool sloppy = false,
    t.Square? from,
    t.Square? to,
  }) {
    assert(san != null || (from != null && to != null));

    late final t.HexMove? validMove;

    if (san != null) {
      validMove =
          s.sanToMove(_state, san, checkPromotion: false, sloppy: sloppy);
    } else {
      validMove = s.validateMove(
        state: _state,
        move: t.PartialMove(
          to: to!,
          from: from!,
        ),
        checkPromotion: false,
        sloppy: sloppy,
      );
    }

    if (validMove == null) {
      return false;
    }

    return (validMove.flags.bits & t.Flag.promotion.bits) != 0;
  }

  /// Clears the board and loads the Forsyth–Edwards Notation (FEN) string.
  ///
  /// @param fen - FEN string.
  /// @param keepHeaders - Flag to keep headers.
  /// @returns True if the position was successfully loaded, otherwise false.
  bool load(String fen, {bool keepHeaders = false}) {
    final t.State? state = s.loadFen(fen);

    if (state == null) {
      return false;
    }

    _state = state;
    _history = <t.GameHistory>[];

    if (!keepHeaders) header = <String, String>{};

    _comments = <String, String>{};
    _updateSetup();

    return true;
  }

  /// Clears the board.
  ///
  /// @example
  /// ```dart
  /// chess.clear();
  /// chess.fen();
  /// // -> '8/8/8/8/8/8/8/8 w - - 0 1' <- empty board
  /// ```
  ///
  /// @param keepHeaders - Flag to keep headers
  void clear({bool keepHeaders = false}) {
    _state = t.State.create();
    _history = <t.GameHistory>[];

    if (!keepHeaders) header = <String, String>{};

    _comments = <String, String>{};
    _updateSetup();
  }

  /// Reset the board to the initial starting position.
  void reset() {
    load(c.kDefaultPosition);
  }

  /// Returns the piece on the square.
  ///
  /// @example
  /// ```dart
  /// chess.clear()
  /// chess.put({ type: chess.PAWN, color: chess.BLACK }, 'a5') // put a black pawn on a5
  ///
  /// chess.get('a5')
  /// // -> { type: 'p', color: 'b' },
  /// chess.get('a6')
  /// // -> null
  /// ```
  ///
  /// @param square - e.g. 'e4'
  /// @returns Copy of the piece or null
  t.Piece? get(String square) {
    return s.getPiece(_state, t.Square.fromNotation(square));
  }

  /// Place a piece on the square where piece is an object with the form
  /// `{ type: ..., color: ... }`. Returns true if the piece was successfully
  /// placed, otherwise, the board remains unchanged and false is returned.
  /// `put()` will fail when passed an invalid piece or square, or when two or
  /// more kings of the same color are placed.
  ///
  /// @example
  /// ```js
  /// chess.clear()
  ///
  /// chess.put({ type: chess.PAWN, color: chess.BLACK }, 'a5') // put a black pawn on a5
  /// // -> true
  /// chess.put({ type: 'k', color: 'w' }, 'h1') // shorthand
  /// // -> true
  ///
  /// chess.fen()
  /// // -> '8/8/8/p7/8/8/8/7K w - - 0 0'
  ///
  /// chess.put({ type: 'z', color: 'w' }, 'a1') // invalid piece
  /// // -> false
  ///
  /// chess.clear()
  ///
  /// chess.put({ type: 'k', color: 'w' }, 'a1')
  /// // -> true
  ///
  /// chess.put({ type: 'k', color: 'w' }, 'h1') // fail - two kings
  /// // -> false
  /// ```
  ///
  /// @param piece - Object of the form `{ type: 'p', color: 'w' }`
  /// @param square - e.g. `'e4'`
  /// @returns True if placed successfully, otherwise false
  bool put(t.Piece piece, String square) {
    if (!square.isChessSquare()) return false;

    final t.State? newState =
        s.putPiece(_state, piece, t.Square.fromNotation(square)!);

    if (newState != null) {
      _state = newState;
      _updateSetup();
      return true;
    }

    return false;
  }

  /// Remove and return the piece on `square`.
  ///
  /// @example
  /// ```js
  /// chess.clear()
  /// chess.put({ type: chess.PAWN, color: chess.BLACK }, 'a5') // put a black pawn on a5
  /// chess.put({ type: chess.KING, color: chess.WHITE }, 'h1') // put a white king on h1
  ///
  /// chess.remove('a5')
  /// // -> { type: 'p', color: 'b' },
  /// chess.remove('h1')
  /// // -> { type: 'k', color: 'w' },
  /// chess.remove('e1')
  /// // -> null
  /// ```
  ///
  /// @param square - e.g. 'e4'
  /// @returns Piece or null
  t.Piece? remove([String? square]) {
    final t.Square? sq = square != null ? t.Square.fromNotation(square) : null;

    final t.Piece? piece = s.getPiece(_state, sq);
    if (piece == null) {
      return null;
    }

    final t.State? newState = s.removePiece(_state, sq);
    if (newState == null) {
      return null;
    }

    _state = newState;

    return piece;
  }

  /// Returns a list of legal moves from the current position. The function
  /// takes an optional parameter which controls the single-square move
  /// generation and verbosity.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  /// chess.moves()
  /// // -> [{ color: 'w', from: 'a2', to: 'a3',
  /// //       flags: 'n', piece: 'p', san 'a3'
  /// //       # a captured: key is included when the move is a capture
  /// //       # a promotion: key is included when the move is a promotion
  /// //     },
  /// //     ...
  /// //     ]
  /// ```
  List<t.Move> moves([String? square]) {
    if (square != null) {
      if (!square.isChessSquare()) {
        return <t.Move>[];
      }
    }

    // The internal representation of a chess move is in 0x88 format, and
    // not meant to be human-readable.  The code below converts the 0x88
    // square coordinates to algebraic coordinates. It also prunes an
    // unnecessary move keys resulting from a verbose call.
    final List<t.HexMove> uglyMoves = s.generateMoves(
      state: _state,
      square: square != null ? t.Square.fromNotation(square) : null,
    );

    return uglyMoves
        .map((t.HexMove uglyMove) => s.makePretty(_state, uglyMove))
        .toList();
  }

  /// Delete and return the comment for a position, if it exists.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  ///
  /// chess.loadPgn("1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 {giuoco piano} *")
  ///
  /// chess.getComment()
  /// // -> "giuoco piano"
  ///
  /// chess.deleteComments()
  /// // -> "giuoco piano"
  ///
  /// chess.getComment()
  /// // -> undefined
  /// ```
  ///
  /// @param fen - Defaults to the current position
  String? deleteComment([String? fen]) {
    final String position = fen ?? this.fen();

    final String? comment = _comments[fen];

    _comments.remove(position);

    return comment;
  }

  /// Returns true or false if the side to move is in check.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess(
  ///     'rnb1kbnr/pppp1ppp/8/4p3/5PPq/8/PPPPP2P/RNBQKBNR w KQkq - 1 3'
  /// )
  /// chess.inCheck()
  /// // -> true
  /// ```
  bool inCheck() {
    return s.inCheck(_state);
  }

  /// Returns true or false if the side to move has been checkmated.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess(
  ///     'rnb1kbnr/pppp1ppp/8/4p3/5PPq/8/PPPPP2P/RNBQKBNR w KQkq - 1 3'
  /// )
  /// chess.inCheckmate()
  /// // -> true
  /// ```
  bool inCheckmate() {
    return s.inCheckmate(_state);
  }

  /// Returns true or false if the side to move has been stalemated.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess('4k3/4P3/4K3/8/8/8/8/8 b - - 0 78')
  /// chess.inStalemate()
  /// // -> true
  /// ```
  bool inStalemate() {
    return s.inStalemate(_state);
  }

  /// Returns true if the game is drawn due to insufficient material (K vs. K,
  /// K vs. KB, or K vs. KN) otherwise false.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess('k7/8/n7/8/8/8/8/7K b - - 0 1')
  /// chess.insufficientMaterial()
  /// // -> true
  /// ```
  bool insufficientMaterial() {
    return s.insufficientMaterial(_state);
  }

  /// Returns true or false if the current board position has occurred three or more
  /// times.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')
  /// // -> true
  /// // rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq occurs 1st time
  /// chess.inThreefoldRepetition()
  /// // -> false
  ///
  /// chess.move('Nf3') chess.move('Nf6') chess.move('Ng1') chess.move('Ng8')
  /// // rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq occurs 2nd time
  /// chess.inThreefoldRepetition()
  /// // -> false
  ///
  /// chess.move('Nf3') chess.move('Nf6') chess.move('Ng1') chess.move('Ng8')
  /// // rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq occurs 3rd time
  /// chess.inThreefoldRepetition()
  /// // -> true
  /// ```
  bool inThreefoldRepetition() {
    final Map<String, int> positions = <String, int>{};

    bool checkState(t.State state) {
      final String key = state.fen.split(' ').sublist(0, 4).join(' ');

      // Has the position occurred three or move times?
      positions[key] = positions.containsKey(key) ? positions[key]! + 1 : 1;

      if (positions[key]! >= 3) {
        return true;
      }

      return false;
    }

    for (final t.GameHistory gameHistory in _history) {
      if (checkState(gameHistory.state)) {
        return true;
      }
    }

    return checkState(_state);
  }

  /// Returns true or false if the game is drawn (50-move rule or insufficient material).
  /// @example
  /// ```js
  /// const chess = new Chess('4k3/4P3/4K3/8/8/8/8/8 b - - 0 78')
  /// chess.inDraw()
  /// // -> true
  /// ```
  bool inDraw() {
    return _state.halfMoves >= 100 ||
        inStalemate() ||
        insufficientMaterial() ||
        inThreefoldRepetition();
  }

  /// Returns true if the game has ended via checkmate, stalemate, draw,
  /// threefold repetition, or insufficient material. Otherwise, returns false.
  /// @example
  /// ```js
  /// const chess = new Chess()
  /// chess.gameOver()
  /// // -> false
  ///
  /// // stalemate
  /// chess.load('4k3/4P3/4K3/8/8/8/8/8 b - - 0 78')
  /// chess.gameOver()
  /// // -> true
  ///
  /// // checkmate
  /// chess.load('rnb1kbnr/pppp1ppp/8/4p3/5PPq/8/PPPPP2P/RNBQKBNR w KQkq - 1 3')
  /// chess.gameOver()
  /// // -> true
  /// ```
  bool gameOver() {
    return inCheckmate() || inDraw();
  }

  /// Returns an 2D array representation of the current position. Empty squares
  /// are represented by `null`.
  /// @example
  /// ```js
  /// const chess = new Chess()
  ///
  /// chess.board()
  /// // -> [[{type: 'r', color: 'b'},
  ///         {type: 'n', color: 'b'},
  ///         {type: 'b', color: 'b'},
  ///         {type: 'q', color: 'b'},
  ///         {type: 'k', color: 'b'},
  ///         {type: 'b', color: 'b'},
  ///         {type: 'n', color: 'b'},
  ///         {type: 'r', color: 'b'}],
  ///         [...],
  ///         [...],
  ///         [...],
  ///         [...],
  ///         [...],
  ///         [{type: 'r', color: 'w'},
  ///          {type: 'n', color: 'w'},
  ///          {type: 'b', color: 'w'},
  ///          {type: 'q', color: 'w'},
  ///          {type: 'k', color: 'w'},
  ///          {type: 'b', color: 'w'},
  ///          {type: 'n', color: 'w'},
  ///          {type: 'r', color: 'w'}]]
  /// ```
  List<List<t.Piece?>> board() {
    return s.getBoard(_state.board);
  }

  /// Returns the game in PGN format. Options is an optional parameter which may include
  /// max width and/or a newline character settings.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  /// chess.header('White', 'Plunky', 'Black', 'Plinkie')
  /// chess.move('e4')
  /// chess.move('e5')
  /// chess.move('Nc3')
  /// chess.move('Nc6')
  ///
  /// chess.pgn({ max_width: 5, newline_char: '<br />' })
  /// // -> '[White "Plunky"]<br />[Black "Plinkie"]<br /><br />1. e4 e5<br />2. Nc3 Nc6'
  /// ```
  String pgn({String newlineChar = '\n', int maxWidth = 0}) {
    return s.getPgn(
      s.Pgn(
        state: _state,
        comments: _comments,
        history: _history,
        header: header,
      ),
      maxWidth: maxWidth,
      newlineChar: newlineChar,
    );
  }

  /// Load the moves of a game stored in
  /// [Portable Game Notation](http://en.wikipedia.org/wiki/Portable_Game_Notation).
  /// `pgn` should be a string. Options is an optional `object` which may contain
  /// a string `newline_char` and a boolean `sloppy`.
  ///
  /// The `newline_char` is a string representation of a valid RegExp fragment and is
  /// used to process the PGN. It defaults to `\r?\n`. Special characters
  /// should not be pre-escaped, but any literal special characters should be escaped
  /// as is normal for a RegExp. Keep in mind that backslashes in JavaScript strings
  /// must themselves be escaped (see `sloppy_pgn` example below). Avoid using
  /// a `newline_char` that may occur elsewhere in a PGN, such as `.` or `x`, as this
  /// will result in unexpected behavior.
  ///
  /// The `sloppy` flag is a boolean that permits chess.js to parse moves in
  /// non-standard notations. See `.move` documentation for more information about
  /// non-SAN notations.
  ///
  /// The method will return `true` if the PGN was parsed successfully, otherwise `false`.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  /// const pgn = [
  ///     '[Event "Casual Game"]',
  ///     '[Site "Berlin GER"]',
  ///     '[Date "1852.??.??"]',
  ///     '[EventDate "?"]',
  ///     '[Round "?"]',
  ///     '[Result "1-0"]',
  ///     '[White "Adolf Anderssen"]',
  ///     '[Black "Jean Dufresne"]',
  ///     '[ECO "C52"]',
  ///     '[WhiteElo "?"]',
  ///     '[BlackElo "?"]',
  ///     '[PlyCount "47"]',
  ///     '',
  ///     '1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 4.b4 Bxb4 5.c3 Ba5 6.d4 exd4 7.O-O',
  ///     'd3 8.Qb3 Qf6 9.e5 Qg6 10.Re1 Nge7 11.Ba3 b5 12.Qxb5 Rb8 13.Qa4',
  ///     'Bb6 14.Nbd2 Bb7 15.Ne4 Qf5 16.Bxd3 Qh5 17.Nf6+ gxf6 18.exf6',
  ///     'Rg8 19.Rad1 Qxf3 20.Rxe7+ Nxe7 21.Qxd7+ Kxd7 22.Bf5+ Ke8',
  ///     '23.Bd7+ Kf8 24.Bxe7# 1-0'
  /// ]
  ///
  /// chess.loadPgn(pgn.join('\n'))
  /// // -> true
  ///
  /// chess.fen()
  /// // -> 1r3kr1/pbpBBp1p/1b3P2/8/8/2P2q2/P4PPP/3R2K1 b - - 0 24
  ///
  /// chess.ascii()
  /// // -> '  +------------------------+
  /// //     8 | .  r  .  .  .  k  r  . |
  /// //     7 | p  b  p  B  B  p  .  p |
  /// //     6 | .  b  .  .  .  P  .  . |
  /// //     5 | .  .  .  .  .  .  .  . |
  /// //     4 | .  .  .  .  .  .  .  . |
  /// //     3 | .  .  P  .  .  q  .  . |
  /// //     2 | P  .  .  .  .  P  P  P |
  /// //     1 | .  .  .  R  .  .  K  . |
  /// //       +------------------------+
  /// //         a  b  c  d  e  f  g  h'
  ///
  /// // Parse non-standard move formats and unusual line separators
  /// const sloppyPgn = [
  ///     '[Event "Wijk aan Zee (Netherlands)"]',
  ///     '[Date "1971.01.26"]',
  ///     '[Result "1-0"]',
  ///     '[White "Tigran Vartanovich Petrosian"]',
  ///     '[Black "Hans Ree"]',
  ///     '[ECO "A29"]',
  ///     '',
  ///     '1. Pc2c4 Pe7e5', // non-standard
  ///     '2. Nc3 Nf6',
  ///     '3. Nf3 Nc6',
  ///     '4. g2g3 Bb4', // non-standard
  ///     '5. Nd5 Nxd5',
  ///     '6. c4xd5 e5-e4', // non-standard
  ///     '7. dxc6 exf3',
  ///     '8. Qb3 1-0'
  /// ].join('|')
  ///
  /// const options = {
  ///     newline_char: '\\|', // Literal '|' character escaped
  ///     sloppy: true
  /// }
  ///
  /// chess.loadPgn(sloppyPgn)
  /// // -> false
  ///
  /// chess.loadPgn(sloppyPgn, options)
  /// // -> true
  ///
  /// chess.fen()
  /// // -> 'r1bqk2r/pppp1ppp/2P5/8/1b6/1Q3pP1/PP1PPP1P/R1B1KB1R b KQkq - 1 8'
  /// ```
  bool loadPgn(
    String pgn, {
    String newlineChar = '\r?\n',
    bool sloppy = false,
  }) {
    final s.Pgn? res = s.loadPgn(pgn, newlineChar: newlineChar, sloppy: sloppy);

    if (res == null) {
      return false;
    }

    _state = res.state;
    header = res.header;
    _comments = res.comments;
    _history = res.history;

    return true;
  }

  /// Retrieve comments for all positions.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  ///
  /// chess.loadPgn("1. e4 e5 {king's pawn opening} 2. Nf3 Nc6 3. Bc4 Bc5 {giuoco piano} *")
  ///
  /// chess.getComments()
  /// // -> [
  /// //     {
  /// //       fen: "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2",
  /// //       comment: "king's pawn opening"
  /// //     },
  /// //     {
  /// //       fen: "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3",
  /// //       comment: "giuoco piano"
  /// //     }
  /// //    ]
  /// ```
  List<t.FenComment> getComments() {
    _pruneComments();

    return <t.FenComment>[
      for (final String? fen in _comments.keys)
        if (fen != null) t.FenComment(comment: _comments[fen]!, fen: fen)
    ];
  }

  /// Adds a PGN header entry.
  ///
  /// @example
  /// ```js
  /// chess.addHeader('White', 'Robert James Fischer')
  /// chess.addHeader('Black', 'Mikhail Tal')
  /// ```
  void addHeader(String key, String val) => header[key] = val;

  /// Removes a PGN header entry
  ///
  /// @example
  /// ```js
  /// chess.removeHeader('White')
  /// ```
  void removeHeader(String key) {
    header.remove(key);
  }

  /// Removes all PGN header information.
  ///
  /// @example
  /// ```js
  /// chess.setHeader('White', 'Robert James Fischer')
  /// chess.setHeader('Black', 'Mikhail Tal')
  /// ```
  void clearHeader() {
    header.clear();
  }

  /// Returns a string containing an ASCII diagram of the current position.
  /// @example
  /// ```js
  /// const chess = new Chess()
  ///
  /// // Make some moves
  /// chess.move('e4')
  /// chess.move('e5')
  /// chess.move('f4')
  ///
  /// chess.ascii()
  /// // -> '   +------------------------+
  /// //      8 | r  n  b  q  k  b  n  r |
  /// //      7 | p  p  p  p  .  p  p  p |
  /// //      6 | .  .  .  .  .  .  .  . |
  /// //      5 | .  .  .  .  p  .  .  . |
  /// //      4 | .  .  .  .  P  P  .  . |
  /// //      3 | .  .  .  .  .  .  .  . |
  /// //      2 | P  P  P  P  .  .  P  P |
  /// //      1 | R  N  B  Q  K  B  N  R |
  /// //        +------------------------+
  /// //          a  b  c  d  e  f  g  h'
  /// ```
  String ascii([String eol = '\n']) {
    return s.ascii(_state.board, eol: eol);
  }

  /// Returns the current side to move.
  ///
  /// @example
  /// ```js
  /// chess.load('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1')
  /// chess.turn()
  /// // -> 'b'
  /// ```
  t.PieceColor turn() {
    return _state.turn;
  }

  /// Comment on a position.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  ///
  /// chess.move("e4")
  /// chess.setComment("king's pawn opening")
  ///
  /// chess.pgn()
  /// // -> "1. e4 {king's pawn opening}"
  /// ```
  ///
  /// @param comment
  /// @param fen - Defaults to the current position
  void setComment(String comment, [String? fen]) {
    _comments[fen ?? this.fen()] =
        comment.replaceFirst('{', '[').replaceFirst('}', ']');
  }

  /// Delete and return comments for all positions.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  ///
  /// chess.loadPgn("1. e4 e5 {king's pawn opening} 2. Nf3 Nc6 3. Bc4 Bc5 {giuoco piano} *")
  ///
  /// chess.deleteComments()
  /// // -> [
  /// //     {
  /// //       fen: "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2",
  /// //       comment: "king's pawn opening"
  /// //     },
  /// //     {
  /// //       fen: "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3",
  /// //       comment: "giuoco piano"
  /// //     }
  /// //    ]
  ///
  /// chess.getComments()
  /// // -> []
  /// ```
  List<t.FenComment> deleteComments() {
    _pruneComments();

    final Map<String?, String?> deletedComments =
        Map<String?, String?>.from(_comments);

    _comments.clear();

    t.FenComment fenToComment(String? fen) {
      final String? comment = deletedComments[fen];
      return t.FenComment(fen: fen!, comment: comment!);
    }

    bool commentIsNotNull(String? key) =>
        key != null && deletedComments[key] != null;

    return deletedComments.keys
        .where(commentIsNotNull)
        .map(fenToComment)
        .toList();
  }

  /// Returns a validation object specifying validity or the errors found
  /// within the FEN string.
  ///
  /// @example
  /// ```dart
  /// chess.validateFen('2n1r3/p1k2pp1/B1p3b1/P7/5bP1/2N1B3/1P2KP2/2R5 b - - 4 25')
  /// // -> { valid: true, errorNumber: 0, error: 'No errors.' }
  ///
  /// chess.validateFen('4r3/8/X12XPk/1p6/pP2p1R1/P1B5/2P2K2/3r4 w - - 1 45')
  /// // -> { valid: false, errorNumber: 9,
  /// //     error: '1st field (piece positions) is invalid [invalid piece].' }
  /// ```
  u.FenValidation validateFen(String fen) {
    return validateFen(fen);
  }

  Chess clone() {
    return Chess._(
      comments: t.Header.unmodifiable(_comments),
      header: t.Header.unmodifiable(header),
      history: List<t.GameHistory>.unmodifiable(_history),
      state: _state.clone(),
    );
  }

  int perft(int depth) {
    final List<t.HexMove> moves = s.generateMoves(state: _state, legal: false);

    int nodes = 0;

    final t.PieceColor color = _state.turn;

    for (int i = 0, len = moves.length; i < len; i++) {
      makeMove(moves[i]);

      if (!_kingAttacked(color)) {
        if (depth - 1 > 0) {
          final int childNodes = perft(depth - 1);
          nodes += childNodes;
        } else {
          nodes++;
        }
      }

      undoMove();
    }

    return nodes;
  }

  /// Takeback the last half-move, returning a move object if successful, otherwise null.
  ///
  /// @example
  /// ```dart
  /// final chess = Chess.create()
  ///
  /// chess.fen()
  /// // -> 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
  /// chess.move('e4')
  /// chess.fen()
  /// // -> 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1'
  ///
  /// chess.undo()
  /// // -> { color: 'w', from: 'e2', to: 'e4', flags: 'b', piece: 'p', san: 'e4' }
  /// chess.fen()
  /// // -> 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
  /// chess.undo()
  /// // -> null
  /// ```
  t.Move? undo() {
    final t.HexMove? move = undoMove();
    return move != null ? s.makePretty(_state, move) : null;
  }

  /// Returns the color of the square ('light' or 'dark').
  ///
  /// @example
  /// ```js
  /// const chess = Chess()
  /// chess.squareColor('h1')
  /// // -> 'light'
  /// chess.squareColor('a7')
  /// // -> 'dark'
  /// chess.squareColor('bogus square')
  /// // -> null
  /// ```
  t.PieceColor? squareColor(String square) {
    final t.Square? source = t.Square.fromNotation(square);

    if (source != null) {
      return source.color;
    }

    return null;
  }

  /// Returns a list containing the moves of the current game.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  /// chess.move('e4')
  /// chess.move('e5')
  /// chess.move('f4')
  /// chess.move('exf4')
  ///
  /// chess.history({ verbose: true })
  /// // -> [{ color: 'w', from: 'e2', to: 'e4', flags: 'b', piece: 'p', san: 'e4' },
  /// //     { color: 'b', from: 'e7', to: 'e5', flags: 'b', piece: 'p', san: 'e5' },
  /// //     { color: 'w', from: 'f2', to: 'f4', flags: 'b', piece: 'p', san: 'f4' },
  /// //     { color: 'b', from: 'e5', to: 'f4', flags: 'c', piece: 'p', captured: 'p', san: 'exf4' }]
  /// ```
  List<t.Move> history() {
    if (_history.isEmpty) {
      return <t.Move>[];
    }

    return <t.Move>[
      for (final t.GameHistory gameHistory in _history)
        s.makePretty(gameHistory.state, gameHistory.move)
    ];
    // return this._history.map((gameHistory) => {
    //   const move = gameHistory.move
    //   state = gameHistory.state
    //   return moveToSan(state, move)
    // })
  }

  /// Called when the initial board setup is changed with put() or remove().
  /// modifies the SetUp and FEN properties of the header object. If the FEN is
  /// equal to the default position, the SetUp and FEN are deleted
  /// the setup is only updated if history.length is zero, ie moves haven't been
  /// made.
  ///
  /// @internal
  void _updateSetup() {
    final String fen = _state.fen;

    if (_history.isNotEmpty) return;

    if (fen != c.kDefaultPosition) {
      header['SetUp'] = '1';
      header['FEN'] = fen;
    } else {
      header.remove('SetUp');
      header.remove('FEN');
    }
  }

  /// Retrieve the comment for a position, if it exists.
  ///
  /// @example
  /// ```js
  /// const chess = new Chess()
  ///
  /// chess.loadPgn("1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 {giuoco piano} *")
  ///
  /// chess.getComment()
  /// // -> "giuoco piano"
  /// ```
  ///
  /// @param fen - Defaults to the current position.
  String? getComment([String? fen]) {
    return _comments[fen ?? this.fen()];
  }

  t.State get state => _state.clone();

  List<t.State> get states {
    return <t.State>[
      ..._history.map((t.GameHistory gameHistory) => gameHistory.state.clone()),
      state
    ];
  }

  void _pruneComments() {
    final t.Comments comments = <String, String>{};

    void copyComments(String fen) {
      if (_comments.containsKey(fen)) {
        comments[fen] = _comments[fen];
      }
    }

    for (final t.GameHistory history in _history) {
      final t.State state = history.state;
      copyComments(state.fen);
    }

    final t.State state = _state;

    copyComments(state.fen);

    _comments = comments;
  }

  bool _attacked(t.PieceColor color, t.Square square) {
    return s.isAttacked(_state, color, square.bits);
  }

  bool _kingAttacked(t.PieceColor color) {
    return _attacked(color.swap(), t.Square.fromBits(_state.kings[color]!)!);
  }

  void makeMove(t.HexMove move) {
    _history.add(
      t.GameHistory(
        move: move,
        state: _state,
      ),
    );

    _state = s.makeMove(_state, move);
  }

  t.HexMove? undoMove() {
    if (_history.isEmpty) {
      return null;
    }

    final t.GameHistory prev = _history.removeLast();

    _state = prev.state;

    return prev.move;
  }
}
