import 'const.dart';
import 'types.dart';
import 'utils.dart';

HexMove buildMove({
  required State state,
  required Square from,
  required Square to,
  required List<Flag> flags,
  PieceSymbol? promotion,
}) {
  late final PieceSymbol? captured;

  if (state.board[to.bits] != null) {
    captured = state.board[to.bits]?.symbol;
  } else {
    captured = flags.bits.isNonZero(Flag.enPassantCapture.bits)
        ? PieceSymbol.pawn
        : null;
  }

  final List<Flag> implicityFlags = <Flag>[
    if (captured != null) Flag.capture,
    if (promotion != null) Flag.promotion
  ];

  return HexMove(
    to: to,
    from: from,
    color: state.turn,
    flags: flags + implicityFlags,
    piece: state.board[from.bits]!.symbol,
    promotion: promotion,
    captured: captured,
  );
}

State? removePiece(State prevState, Square? square) {
  if (square == null) return null;

  final int sq = square.bits;

  final Piece? piece = prevState.board[sq];

  if (piece == null) return null;

  State state = prevState.clone();

  if (piece.symbol == PieceSymbol.king) {
    state = state.modifyKing(piece.color, kEmpty);
  }

  return state.modifyPiece(square, null);
}

List<HexMove> generateMoves({
  required State state,
  Square? square,
  bool legal = true,
}) {
  void addMove({
    required Board board,
    required List<HexMove> moves,
    required Square from,
    required Square to,
    required List<Flag> flags,
  }) {
    /* if pawn promotion */
    final Piece? piece = board[from.bits];

    final bool isPawn = piece?.symbol == PieceSymbol.pawn;

    if (isPawn && (rank(to.bits) == kRank8 || rank(to.bits) == kRank1)) {
      final List<PieceSymbol> pieces = <PieceSymbol>[
        PieceSymbol.queen,
        PieceSymbol.rook,
        PieceSymbol.bishop,
        PieceSymbol.knight,
      ];

      for (int i = 0, len = pieces.length; i < len; i++) {
        moves.add(
          buildMove(
            state: state,
            from: from,
            to: to,
            flags: flags,
            promotion: pieces[i],
          ),
        );
      }
    } else {
      moves.add(
        buildMove(
          state: state,
          from: from,
          to: to,
          flags: flags,
        ),
      );
    }
  }

  final List<HexMove> moves = <HexMove>[];

  final PieceColor us = state.turn;
  final PieceColor them = us.swap();

  final Map<PieceColor, int> secondRank = <PieceColor, int>{
    black: kRank7,
    white: kRank2
  };

  int firstSquare = Square.a8.bits;
  int lastSquare = Square.h1.bits;
  bool singleSquare = false;

  /* are we generating moves for a single square? */
  if (square != null) {
    lastSquare = square.bits;
    firstSquare = lastSquare;
    singleSquare = true;
  }

  for (int i = firstSquare; i <= lastSquare; i++) {
    /* did we run off the end of the board */
    if (i.off) {
      i += 7;
    }

    final Piece? piece = state.board[i];

    if (piece == null || piece.color != us) {
      continue;
    }

    if (piece.symbol == PieceSymbol.pawn) {
      /* single square, non-capturing */
      final int square1 = i + us.pawnOffsets[0];

      if (state.board[square1] == null) {
        addMove(
          board: state.board,
          moves: moves,
          from: i.toSquare(),
          to: square1.toSquare(),
          flags: <Flag>[Flag.normal],
        );

        /* double square */
        final int square2 = i + us.pawnOffsets[1];

        if (secondRank[us] == rank(i) && state.board[square2] == null) {
          addMove(
            board: state.board,
            moves: moves,
            from: i.toSquare(),
            to: square2.toSquare(),
            flags: <Flag>[Flag.bigPawn],
          );
        }
      }

      /* pawn captures */
      for (int j = 2; j < 4; j++) {
        final int square = i + us.pawnOffsets[j];

        if (square.off) continue;

        if (state.board[square] != null && state.board[square]!.color == them) {
          addMove(
            board: state.board,
            moves: moves,
            from: i.toSquare(),
            to: square.toSquare(),
            flags: <Flag>[Flag.capture],
          );
        } else if (square == state.epSquare) {
          addMove(
            board: state.board,
            moves: moves,
            from: i.toSquare(),
            to: state.epSquare.toSquare(),
            flags: <Flag>[Flag.enPassantCapture],
          );
        }
      }
    } else {
      for (int j = 0, len = piece.symbol.offsets.length; j < len; j++) {
        final int offset = piece.symbol.offsets[j];
        int square = i;

        while (true) {
          square += offset;

          if (square.off) break;

          if (state.board[square] == null) {
            addMove(
              board: state.board,
              moves: moves,
              from: i.toSquare(),
              to: square.toSquare(),
              flags: <Flag>[Flag.normal],
            );
          } else {
            if (state.board[square]?.color == us) break;
            addMove(
              board: state.board,
              moves: moves,
              from: i.toSquare(),
              to: square.toSquare(),
              flags: <Flag>[Flag.capture],
            );
            break;
          }

          /* break, if knight or king */
          if (piece.symbol.isKnight || piece.symbol.isKing) break;
        }
      }
    }
  }

  /* check for castling if: a) we're generating all moves, or b) we're doing
   * single square move generation on the king's square
   */
  if (!singleSquare || lastSquare == state.kings[us]) {
    /* king-side castling */
    if (state.castling[us]!.isNonZero(Flag.kingSideCastle.bits)) {
      final int castlingFrom = state.kings[us]!;
      final int castlingTo = castlingFrom + 2;

      if (state.board[castlingFrom + 1] == null &&
          state.board[castlingTo] == null &&
          !isAttacked(state, them, state.kings[us]!) &&
          !isAttacked(state, them, castlingFrom + 1) &&
          !isAttacked(state, them, castlingTo)) {
        if (castlingTo.isSquare() && state.kings[us]!.isSquare()) {
          addMove(
            board: state.board,
            moves: moves,
            from: state.kings[us]!.toSquare(),
            to: castlingTo.toSquare(),
            flags: <Flag>[Flag.kingSideCastle],
          );
        }
      }
    }

    /* queen-side castling */
    if (state.castling[us]!.isNonZero(Flag.queenSideCastle.bits)) {
      final int castlingFrom = state.kings[us]!;
      final int castlingTo = castlingFrom - 2;

      if (state.board[castlingFrom - 1] == null &&
          state.board[castlingFrom - 2] == null &&
          state.board[castlingFrom - 3] == null &&
          !isAttacked(state, them, state.kings[us]!) &&
          !isAttacked(state, them, castlingFrom - 1) &&
          !isAttacked(state, them, castlingTo)) {
        addMove(
          board: state.board,
          moves: moves,
          from: state.kings[us]!.toSquare(),
          to: castlingTo.toSquare(),
          flags: <Flag>[Flag.queenSideCastle],
        );
      }
    }
  }

  /* return all pseudo-legal moves (this includes moves that allow the king
   * to be captured)
   */
  if (!legal) {
    return moves;
  }

  /* filter out illegal moves */
  final List<HexMove> legalMoves = <HexMove>[];

  for (int i = 0, len = moves.length; i < len; i++) {
    final State newState = makeMove(state, moves[i]);
    if (!isKingAttacked(newState, us)) {
      legalMoves.add(moves[i]);
    }
  }

  return legalMoves;
}

bool isKingAttacked(State state, PieceColor color) {
  return isAttacked(state, color.swap(), state.kings[color]!);
}

bool inCheck(State state) {
  return isKingAttacked(state, state.turn);
}

State makeMove(State prevState, HexMove move) {
  State state = prevState.clone();

  final PieceColor us = state.turn;
  final PieceColor them = us.swap();

  state = state
      .modifyPiece(move.to, state.board[move.from.bits])
      .modifyPiece(move.from, null);

  /* if ep capture, remove the captured pawn */
  if (move.flags.bits.isNonZero(Flag.enPassantCapture.bits)) {
    if (state.turn == black) {
      state = state.modifyPiece(Square.fromBits(move.to.bits - 16)!, null);
    } else {
      state = state.modifyPiece(Square.fromBits(move.to.bits + 16)!, null);
    }
  }

  /* if pawn promotion, replace with new piece */
  if (move.flags.bits.isNonZero(Flag.promotion.bits) &&
      move.promotion != null) {
    state = state.modifyPiece(
      move.to,
      Piece.fromSymbolAndColor(move.promotion!, us),
    );
  }

  /* if we moved the king */
  final Piece? piece = state.board[move.to.bits];

  if (piece != null && piece.symbol == PieceSymbol.king) {
    state = state.modifyKing(piece.color, move.to.bits);

    /* if we castled, move the rook next to the king */
    if (move.flags.bits.isNonZero(Flag.kingSideCastle.bits)) {
      final int castlingTo = move.to.bits - 1;
      final int castlingFrom = move.to.bits + 1;

      state = state.modifyPiece(
        Square.fromBits(castlingTo)!,
        state.board[castlingFrom],
      );
      state = state.modifyPiece(
        Square.fromBits(castlingFrom)!,
        null,
      );
    } else if (move.flags.bits.isNonZero(Flag.queenSideCastle.bits)) {
      final int castlingTo = move.to.bits + 1;
      final int castlingFrom = move.to.bits - 2;

      state = state.modifyPiece(
        Square.fromBits(castlingTo)!,
        state.board[castlingFrom],
      );
      state = state.modifyPiece(
        Square.fromBits(castlingFrom)!,
        null,
      );
    }

    /* turn off castling */
    state = state.modifyCastling(us, 0);
  }

  /* turn off castling if we move a rook */
  if (state.castling[us] != 0) {
    for (int i = 0, len = us.rooks.length; i < len; i++) {
      final MapEntry<Flag, Square> rookSideEntry =
          us.rooks.entries.elementAt(i);

      if (move.from == rookSideEntry.value &&
          state.castling[us]!.isNonZero(rookSideEntry.key.bits)) {
        state = state.modifyCastling(
          us,
          state.castling[us]! ^ rookSideEntry.key.bits,
        );
        break;
      }
    }
  }

  /* turn off castling if we capture a rook */
  if (state.castling[them] != 0) {
    for (int i = 0, len = them.rooks.length; i < len; i++) {
      final MapEntry<Flag, Square> rookSideEntry =
          them.rooks.entries.elementAt(i);

      if (move.to == rookSideEntry.value &&
          state.castling[them]!.isNonZero(rookSideEntry.key.bits)) {
        state.modifyCastling(
          them,
          state.castling[them]! ^ rookSideEntry.key.bits,
        );
        break;
      }
    }
  }

  /* if big pawn move, update the en passant square */
  if (move.flags.bits.isNonZero(Flag.bigPawn.bits)) {
    if (state.turn.isBlack) {
      state = state.clone(epSquare: move.to.bits - 16);
    } else {
      state = state.clone(epSquare: move.to.bits + 16);
    }
  } else {
    state = state.clone(epSquare: kEmpty);
  }

  /* reset the 50 move counter if a pawn is moved or a piece is captured */
  if (move.piece == PieceSymbol.pawn) {
    state = state.clone(halfMoves: 0);
  } else if (move.flags.bits
      .isNonZero(Flag.capture.bits | Flag.enPassantCapture.bits)) {
    state = state.clone(halfMoves: 0);
  } else {
    state = state.clone(halfMoves: state.halfMoves + 1);
  }

  if (state.turn == black) {
    state = state.clone(moveNumber: state.moveNumber + 1);
  }

  return state.clone(turn: state.turn.swap());
}

HexMove? validateMove({
  required State state,
  required PartialMove move,
  bool checkPromotion = true,

  // Allow the user to specify the sloppy move parser to work around over
  // disambiguation bugs in Fritz and Chessbase
  bool sloppy = false,
}) {
  // if (typeof move == 'string') {
  //   return sanToMove(state, move, options)
  // }

  final List<HexMove> moves = generateMoves(state: state, square: move.from);

  // Find a matching move
  for (final HexMove moveObj in moves) {
    if (move.from == moveObj.from &&
        move.to == moveObj.to &&
        (!checkPromotion ||
            moveObj.promotion == null ||
            move.promotion == moveObj.promotion)) {
      return moveObj;
    }
  }

  return null;
}

bool isAttacked(State state, PieceColor color, int square) {
  for (int i = Square.a8.bits; i <= Square.h1.bits; i++) {
    /* did we run off the end of the board */
    if (i.off) {
      i += 7;
      continue;
    }

    /* if empty square or wrong color */
    if (state.board[i] == null || state.board[i]!.color != color) continue;

    final Piece piece = state.board[i]!;
    final int difference = i - square;
    final int index = difference + 119;

    if (kAttacks[index].isNonZero(1 << kShifts[piece.symbol]!)) {
      if (piece.symbol == PieceSymbol.pawn) {
        if (difference > 0) {
          if (piece.color == white) return true;
        } else {
          if (piece.color == black) return true;
        }
        continue;
      }

      /* if the piece is a knight or a king */
      if (piece.symbol.isKnight || piece.symbol.isKing) return true;

      final int offset = kRays[index];
      int j = i + offset;

      bool blocked = false;
      while (j != square) {
        if (state.board[j] != null) {
          blocked = true;
          break;
        }
        j += offset;
      }

      if (!blocked) return true;
    }
  }

  return false;
}

State? putPiece(
  State prevState,
  Piece piece,
  Square square,
) {
  State state = prevState.clone();

  /* don't let the user place more than one king */
  if (piece.symbol == PieceSymbol.king &&
      state.kings[piece.color] != kEmpty &&
      state.kings[piece.color] != square.bits) {
    return null;
  }

  state = state.modifyPiece(square, piece);

  if (piece.symbol == PieceSymbol.king) {
    state = state.modifyKing(piece.color, square.bits);
  }

  return state;
}

State? loadFen(String fen) {
  final List<String> tokens = fen.split(RegExp(r'\s+'));

  final String position = tokens[0];
  int square = 0;

  if (validateFenStructure(fen) != null) {
    return null;
  }

  State state = State.create();

  for (int i = 0; i < position.length; i++) {
    final String piece = position[i];

    if (piece == '/') {
      square += 8;
    } else if (isDigit(piece)) {
      square += int.parse(piece, radix: 10);
    } else {
      final PieceColor color = piece.isUpperCase() ? white : black;

      if (!square.isSquare()) return null;

      if (!piece.isChessPieceSymbol()) return null;

      final State? newState = putPiece(
        state,
        Piece.fromSymbolAndColor(
          PieceSymbol.fromChar(piece.toLowerCase())!,
          color,
        ),
        square.toSquare(),
      );

      if (newState == null) return null;

      state = newState;
      square++;
    }
  }

  state = state.clone(turn: tokens[1] == black.notation ? black : white);

  if (tokens[2].contains('K')) {
    state = state.modifyCastling(
      PieceColor.white,
      state.castling[PieceColor.white]! | Flag.kingSideCastle.bits,
    );
  }
  if (tokens[2].contains('Q')) {
    state = state.modifyCastling(
      PieceColor.white,
      state.castling[PieceColor.white]! | Flag.queenSideCastle.bits,
    );
  }
  if (tokens[2].contains('k')) {
    state = state.modifyCastling(
      PieceColor.black,
      state.castling[PieceColor.black]! | Flag.kingSideCastle.bits,
    );
  }
  if (tokens[2].contains('q')) {
    state = state.modifyCastling(
      PieceColor.black,
      state.castling[PieceColor.black]! | Flag.queenSideCastle.bits,
    );
  }

  state = state.clone(
    epSquare: tokens[3] == '-' ? kEmpty : Square.fromNotation(tokens[3])!.bits,
  );
  state = state.clone(halfMoves: int.parse(tokens[4], radix: 10));
  state = state.clone(moveNumber: int.parse(tokens[5], radix: 10));

  return state;
}

class Pgn {
  final State state;
  final Comments comments;
  final List<GameHistory> history;
  final Map<String, String> header;

  const Pgn({
    required this.state,
    required this.comments,
    required this.history,
    required this.header,
  });
}

/* using the specification from http://www.chessclub.com/help/PGN-spec
   * example for html usage: .pgn({ max_width: 72, newline_char: "<br />" })
   */
String getPgn(Pgn pgn, {String newlineChar = '\n', int maxWidth = 0}) {
  final List<String> result = <String>[];
  bool headerExists = false;

  State state = pgn.state.clone();

  final Map<String, String> header = Map<String, String>.from(pgn.header);
  final List<GameHistory> history = List<GameHistory>.from(pgn.history);

  /* add the PGN header headerrmation */
  for (final String i in header.keys) {
    /* TODO: order of enumerated properties in header object is not
     * guaranteed, see ECMA-262 spec (section 12.6.4)
     */
    result.add('${'[$i "${header[i]!}'}"]$newlineChar');
    headerExists = true;
  }

  if (headerExists && pgn.history.isNotEmpty) {
    result.add(newlineChar);
  }

  String appendComment(String moveStr) {
    final String? comment = pgn.comments[state.fen];

    if (comment != null) {
      final String delimiter = moveStr.isNotEmpty ? ' ' : '';
      return '$moveStr$delimiter{$comment}';
    }

    return moveStr;
  }

  // Set initial state
  if (history.isNotEmpty) {
    state = history[0].state;
  }

  final List<String> moves = <String>[];
  String moveStr = '';

  /* special case of a commented starting position with no moves */
  if (history.isEmpty) {
    moves.add(appendComment(''));
  }

  /* build the list of moves.  a move_string looks like: "3. e3 e6" */
  history.asMap().forEach((int i, GameHistory historyState) {
    final HexMove move = historyState.move;

    moveStr = appendComment(moveStr);

    /* if the position started with black to move, start PGN with 1. ... */
    if (i == 0 && move.color == black) {
      moveStr = '${state.moveNumber}' + '. ...';
    } else if (move.color == white) {
      /* store the previous generated move_string if we have one */
      if (moveStr.isNotEmpty) {
        moves.add(moveStr);
      }
      moveStr = '${state.moveNumber}' + '.';
    }

    moveStr = '$moveStr ${moveToSan(state: state, move: move)}';
    state = makeMove(state, move);
  });

  // Append leftover moves
  if (moveStr.isNotEmpty) {
    moves.add(appendComment(moveStr));
  }

  /* is there a result? */
  if (header['Result'] != null) {
    moves.add(header['Result']!);
  }

  /* history should be back to what it was before we started generating PGN,
   * so join together moves
   */
  if (maxWidth == 0) {
    return result.join() + moves.join(' ');
  }

  bool strip() {
    if (result.isNotEmpty && result[result.length - 1] == ' ') {
      result.removeLast();
      return true;
    }
    return false;
  }

  /* NB: this does not preserve comment whitespace. */
  int wrapComment(int width, String move) {
    int mwidth = width;

    for (final String token in move.split(' ')) {
      if (token.isEmpty) {
        continue;
      }
      if (mwidth + token.length > maxWidth) {
        while (strip()) {
          mwidth--;
        }
        result.add(newlineChar);
        mwidth = 0;
      }
      result.add(token);
      mwidth += token.length;
      result.add(' ');
      mwidth++;
    }
    if (strip()) {
      mwidth--;
    }
    return mwidth;
  }

  /* wrap the PGN output at max_width */
  int currentWidth = 0;
  for (int i = 0; i < moves.length; i++) {
    if (currentWidth + moves[i].length > maxWidth) {
      if (moves[i].contains('{')) {
        currentWidth = wrapComment(currentWidth, moves[i]);
        continue;
      }
    }
    /* if the current move will push past max_width */
    if (currentWidth + moves[i].length > maxWidth && i != 0) {
      /* don't end the line with whitespace */
      if (result[result.length - 1] == ' ') {
        result.removeLast();
      }

      result.add(newlineChar);
      currentWidth = 0;
    } else if (i != 0) {
      result.add(' ');
      currentWidth++;
    }
    result.add(moves[i]);
    currentWidth += moves[i].length;
  }

  return result.join();
}

Pgn? loadPgn(
  String pgn, {
  String newlineChar = '\r?\n',
  bool sloppy = false,
}) {
  String mask(String src) {
    return src.replaceAll(RegExp(r'\\'), r'\\');
  }

  Map<String, String> parsePgnHeader(
    String header, {
    required String newlineChar,
    required bool sloppy,
  }) {
    final Map<String, String> headerObj = <String, String>{};

    final List<String> headers = header.split(RegExp(mask(newlineChar)));

    String key = '';
    String value = '';

    for (int i = 0; i < headers.length; i++) {
      key = headers[i].replaceFirstMapped(
        RegExp(r'^\[([A-Z][A-Za-z]*)\s.*\]$'),
        (Match match) => match.group(1) ?? '',
      );
      value = headers[i].replaceFirstMapped(
        RegExp(r'^\[[A-Za-z]+\s"(.*)" *\]$'),
        (Match match) => match.group(1) ?? '',
      );

      if (key.trim().isNotEmpty) {
        headerObj[key.trim()] = value;
      }
    }

    return headerObj;
  }

  // RegExp to split header. Takes advantage of the fact that header and movetext
  // will always have a blank line between them (ie, two newlineChar's).
  // With default newlineChar, will equal: /^(\[((?:\r?\n)|.)*\])(?:\r?\n){2}/
  final RegExp headerRegex = RegExp(
    '^(\\[((?:${mask(newlineChar)})|.)*\\])(?:${mask(newlineChar)}){2}',
  );

  // If no header given, begin with moves.
  late final String headerString;

  final List<RegExpMatch> allHeaderRegexMatches =
      headerRegex.allMatches(pgn).toList();

  if (allHeaderRegexMatches.isNotEmpty &&
      allHeaderRegexMatches[0].groupCount >= 2) {
    final RegExpMatch match = allHeaderRegexMatches[0];
    headerString = match.group(1)!;
  } else {
    headerString = '';
  }

  // Put the board in the starting position
  State state = loadFen(kDefaultPosition)!;

  // parse PGN header
  final Map<String, String> header =
      parsePgnHeader(headerString, newlineChar: newlineChar, sloppy: sloppy);

  // Load the starting position indicated by [Setup '1'] and [FEN position].
  if (header['SetUp'] == '1') {
    if (header.containsKey('FEN')) {
      final State? newState = loadFen(header['FEN']!);
      if (newState == null) {
        return null;
      }
      state = newState;
    }
  }

  // NB: the regexes below that delete move numbers, recursive
  // annotations, and numeric annotation glyphs may also match
  // text in comments. To prevent this, we transform comments
  // by hex-encoding them in place and decoding them again after
  // the other tokens have been deleted.
  //
  // While the spec states that PGN files should be ASCII encoded,
  // we use {en,de}codeURIComponent here to support arbitrary UTF8
  // as a convenience for modern users.
  String toHex(String str) {
    return str
        .split('')
        /* encodeURI doesn't transform most ASCII characters,
         * so we handle these ourselves */
        .map(
          (String c) => c.codeUnitAt(0) < 128
              ? c.codeUnitAt(0).toRadixString(16)
              : Uri.encodeComponent(c).replaceAll('%', '').toLowerCase(),
        )
        .join();
  }

  String fromHex(String str) {
    if (str.isEmpty) return '';

    return Uri.decodeComponent(
      '%${RegExp('.{1,2}').allMatches(str).map((RegExpMatch e) => str.substring(e.start, e.end)).join('%')}',
    );
  }

  String encodeComment(String str) {
    final String s = str.replaceAll(RegExp(mask(newlineChar)), ' ');

    return '{${toHex(s.substring(1, s.length - 1))}}';
  }

  String? decodeComment(String str) {
    if (str.startsWith('{') && str.endsWith('}')) {
      return fromHex(str.substring(1, str.length - 1));
    }
    return null;
  }

  /* delete header to get the moves */
  String ms = pgn.replaceFirst(headerString, '').replaceAllMapped(
    /* encode comments so they don't get deleted below */
    RegExp('({[^}]*})+?|;([^${mask(newlineChar)}]*)'),
    (Match match) {
      final String? bracket = match.group(1);
      final String? semicolon = match.group(2);

      return bracket != null
          ? encodeComment(bracket)
          : ' ${encodeComment('{${(semicolon?.length ?? 0) > 1 ? semicolon!.substring(1) : ''}}')}';
    },
  ).replaceAll(RegExp(mask(newlineChar)), ' ');

  /* delete recursive annotation variations */
  final RegExp ravRegex = RegExp(r'(\([^()]+\))+?');

  while (ravRegex.hasMatch(ms)) {
    ms = ms.replaceAll(ravRegex, '');
  }

  /* delete move numbers */
  ms = ms.replaceAll(RegExp(r'\d+\.(\.\.)?'), '');

  /* delete ... indicating black to move */
  ms = ms.replaceAll(RegExp(r'\.\.\.'), '');

  /* delete numeric annotation glyphs */
  ms = ms.replaceAll(RegExp(r'\$\d+'), '');

  /* trim and get array of moves/comments */
  final List<String> tokens = ms
      .trim()
      .split(RegExp(r'\s+'))
      .join(',')
      .replaceAll(RegExp(',,+'), ',')
      .split(',');

  final Comments comments = <String?, String?>{};
  final List<GameHistory> history = <GameHistory>[];

  for (int halfMove = 0; halfMove < tokens.length; halfMove++) {
    final String token = tokens[halfMove];
    final String? comment = decodeComment(token);

    if (comment != null) {
      comments[state.fen] = comment;
      continue;
    }

    if (halfMove == tokens.length - 1 && kPossibleResults.contains(token)) {
      if (header.keys.isNotEmpty && header['Result'] == null) {
        header['Result'] = token;
      }
      continue;
    }

    final HexMove? move = sanToMove(state, tokens[halfMove], sloppy: sloppy);

    if (move == null) {
      return null;
    } else {
      history.add(GameHistory(state: state, move: move));
      final State newState = makeMove(state, move);
      state = newState;
    }
  }

  return Pgn(
    state: state,
    comments: comments,
    history: history,
    header: header,
  );
}

String ascii(Board board, {String eol = '\n'}) {
  final List<String> pieces = kRanks.map(
    (int rank) {
      final List<Piece?> rankPieces = board.sublist(rank * 16, rank * 16 + 8);

      // Use a loop because `map` skips empty indexes
      final List<String> row = <String>[];

      for (final Piece? piece in rankPieces) {
        row.add(' ${piece?.notation ?? '.'} ');
      }

      final String rankStr = row.join();

      return '${'87654321'[rank]} |$rankStr|';
    },
  ).toList();

  return <String>[
    '  +------------------------+',
    pieces.join(eol),
    '  +------------------------+',
    '    a  b  c  d  e  f  g  h',
  ].join(eol);
}

HexMove? sanToMove(
  State state,
  String move, {
  bool sloppy = false,
  bool checkPromotion = true,
}) {
  // strip off any move decorations: e.g Nf3+?!
  final String cleanMove = strippedSan(move);

  RegExpMatch? matches;
  Square? from;
  Square? to;
  Piece? piece;
  Piece? promotion;

  // if we're using the sloppy parser run a regex to grab piece, to, and from
  // this should parse invalid SAN like: Pe2-e4, Rc1c4, Qf3xf7
  if (sloppy) {
    matches =
        RegExp('([pnbrqkPNBRQK])?([a-h][1-8])x?-?([a-h][1-8])([qrbnQRBN])?')
            .firstMatch(cleanMove);

    if (matches != null) {
      piece = matches[1] != null
          ? Piece.fromSymbolAndColor(
              PieceSymbol.fromChar(matches[1]!)!,
              PieceColor.fromChar(matches[1]!),
            )
          : null;
      from = matches[2] != null ? Square.fromNotation(matches[2]!) : null;
      to = matches[3] != null ? Square.fromNotation(matches[3]!) : null;
      promotion = matches[4] != null
          ? Piece.fromSymbolAndColor(
              PieceSymbol.fromChar(matches[4]!)!,
              PieceColor.fromChar(matches[4]!),
            )
          : null;
    }
  }

  final List<HexMove> moves = generateMoves(state: state, square: from);

  for (int i = 0, len = moves.length; i < len; i++) {
    // try the strict parser first, then the sloppy parser if requested
    // by the user
    final String san =
        moveToSan(state: state, checkPromotion: checkPromotion, move: moves[i]);

    if (cleanMove == strippedSan(san) ||
        (sloppy &&
            cleanMove ==
                strippedSan(
                  moveToSan(
                    state: state,
                    move: moves[i],
                    checkPromotion: checkPromotion,
                    sloppy: sloppy,
                  ),
                ))) {
      return moves[i];
    }

    if (from != null &&
        to != null &&
        matches != null &&
        (piece?.symbol == null || piece?.symbol == moves[i].piece) &&
        from.bits == moves[i].from.bits &&
        to.bits == moves[i].to.bits &&
        (!checkPromotion ||
            promotion?.symbol == null ||
            promotion?.symbol == moves[i].promotion)) {
      return moves[i];
    }
  }

  return null;
}

String getFen(State state) {
  int empty = 0;
  String fen = '';

  for (int i = Square.a8.bits; i <= Square.h1.bits; i++) {
    final Piece? piece = state.board[i];
    if (piece == null) {
      empty++;
    } else {
      if (empty > 0) {
        fen += '$empty';
        empty = 0;
      }
      final PieceColor color = piece.color;
      final PieceSymbol pieceSymbol = piece.symbol;

      fen += color == PieceColor.white
          ? pieceSymbol.notation.toUpperCase()
          : pieceSymbol.notation.toLowerCase();
    }

    if ((i + 1).off) {
      if (empty > 0) {
        fen += '$empty';
      }

      if (i != Square.h1.bits) {
        fen += '/';
      }

      empty = 0;
      i += 8;
    }
  }

  String cflags = '';
  if (state.castling[PieceColor.white]!.isNonZero(Flag.kingSideCastle.bits)) {
    cflags += 'K';
  }
  if (state.castling[PieceColor.white]!.isNonZero(Flag.queenSideCastle.bits)) {
    cflags += 'Q';
  }
  if (state.castling[PieceColor.black]!.isNonZero(Flag.kingSideCastle.bits)) {
    cflags += 'k';
  }
  if (state.castling[PieceColor.black]!.isNonZero(Flag.queenSideCastle.bits)) {
    cflags += 'q';
  }

  /* do we have an empty castling flag? */
  cflags = cflags.isEmpty ? '-' : cflags;

  final String epflags =
      state.epSquare == kEmpty ? '-' : algebraic(state.epSquare);

  return <String>[
    fen,
    state.turn.notation,
    cflags,
    epflags,
    '${state.halfMoves}',
    '${state.moveNumber}'
  ].join(' ');
}

Piece? getPiece(State state, [Square? square]) {
  if (square == null) return null;
  return state.board[square.bits];
}

Move makePretty(State state, HexMove uglyMove) {
  final HexMove move = uglyMove.clone();

  final List<Flag> flags = <Flag>[
    for (final Flag flag in Flag.values)
      if (flag.bits.isNonZero(move.flags.bits)) flag
  ];

  return Move(
    to: move.to,
    from: move.from,
    color: move.color,
    piece: move.piece,
    san: moveToSan(state: state, move: move),
    captured: move.captured,
    promotion: move.promotion,
    flags: flags,
  );
}

/* this function is used to uniquely identify ambiguous moves */
String getDisambiguator(State state, HexMove move, {required bool sloppy}) {
  final List<HexMove> moves = generateMoves(state: state, legal: !sloppy);

  final int from = move.from.bits;
  final int to = move.to.bits;
  final PieceSymbol piece = move.piece;

  int ambiguities = 0;
  int sameRank = 0;
  int sameFile = 0;

  for (int i = 0, len = moves.length; i < len; i++) {
    final int ambigFrom = moves[i].from.bits;
    final int ambigTo = moves[i].to.bits;
    final PieceSymbol ambigPiece = moves[i].piece;

    /* if a move of the same piece type ends on the same to square, we'll
     * need to add a disambiguator to the algebraic notation
     */
    if (piece == ambigPiece && from != ambigFrom && to == ambigTo) {
      ambiguities++;

      if (rank(from) == rank(ambigFrom)) {
        sameRank++;
      }

      if (file(from) == file(ambigFrom)) {
        sameFile++;
      }
    }
  }

  if (ambiguities > 0) {
    /* if there exists a similar moving piece on the same rank and file as
     * the move in question, use the square as the disambiguator
     */
    if (sameRank > 0 && sameFile > 0) {
      return algebraic(from);
    } else if (sameFile > 0) {
      /* if the moving piece rests on the same file, use the rank symbol as the
       * disambiguator
       */
      return algebraic(from)[1];
    } else {
      /* else use the file symbol */
      return algebraic(from)[0];
    }
  }

  return '';
}

/* convert a move from 0x88 coordinates to Standard Algebraic Notation
 * (SAN)
 *
 * @param {boolean} sloppy Use the sloppy SAN generator to work around over
 * disambiguation bugs in Fritz and Chessbase.  See below:
 *
 * r1bqkbnr/ppp2ppp/2n5/1B1pP3/4P3/8/PPPP2PP/RNBQK1NR b KQkq - 2 4
 * 4. ... Nge7 is overly disambiguated because the knight on c6 is pinned
 * 4. ... Ne7 is technically the valid SAN
 */
String moveToSan({
  required State state,
  required HexMove move,
  bool sloppy = false,
  bool checkPromotion = true,
}) {
  String output = '';

  if (move.flags.bits.isNonZero(Flag.kingSideCastle.bits)) {
    output = 'O-O';
  } else if (move.flags.bits.isNonZero(Flag.queenSideCastle.bits)) {
    output = 'O-O-O';
  } else {
    final String disambiguator = getDisambiguator(state, move, sloppy: sloppy);

    if (move.piece != PieceSymbol.pawn) {
      output += move.piece.notation.toUpperCase() + disambiguator;
    }

    if (move.flags.bits
        .isNonZero(Flag.capture.bits | Flag.enPassantCapture.bits)) {
      if (move.piece == PieceSymbol.pawn) {
        output += algebraic(move.from.bits)[0];
      }
      output += 'x';
    }

    output += algebraic(move.to.bits);

    if (checkPromotion && move.flags.bits.isNonZero(Flag.promotion.bits)) {
      output += '=${move.promotion?.notation.toUpperCase()}';
    }
  }

  final State newState = makeMove(state, move);

  if (inCheck(newState)) {
    if (inCheckmate(newState)) {
      output += '#';
    } else {
      output += '+';
    }
  }

  return output;
}

bool inCheckmate(State state) {
  return inCheck(state) && generateMoves(state: state).isEmpty;
}

bool inStalemate(State state) {
  return !inCheck(state) && generateMoves(state: state).isEmpty;
}

bool insufficientMaterial(State state) {
  final Map<PieceSymbol, int> pieces = <PieceSymbol, int>{};
  final List<int> bishops = <int>[];

  int numPieces = 0;

  for (int i = Square.a8.bits; i <= Square.h1.bits; i++) {
    if (i.off) {
      i += 7;
      continue;
    }

    final Piece? piece = state.board[i];
    final Square square = Square.fromBits(i)!;

    if (piece != null) {
      pieces[piece.symbol] = (pieces[piece.symbol] ?? 0) + 1;

      if (piece.symbol == PieceSymbol.bishop) {
        bishops.add(square.color.isWhite ? 1 : 0);
      }

      numPieces++;
    }
  }

  if (numPieces == 2) {
    /* k vs. k */
    return true;
  } else if (numPieces == 3 &&
      (pieces[PieceSymbol.bishop] == 1 || pieces[PieceSymbol.knight] == 1)) {
    /* k vs. kn .... or .... k vs. kb */
    return true;
  } else if (numPieces == (pieces[PieceSymbol.bishop] ?? 0) + 2) {
    /* kb vs. kb where any number of bishops are all on the same color */
    int sum = 0;
    final int len = bishops.length;
    for (int i = 0; i < len; i++) {
      sum += bishops[i];
    }
    if (sum == 0 || sum == len) {
      return true;
    }
  }
  return false;
}

List<List<Piece?>> getBoard(Board board) {
  final List<List<Piece?>> output = <List<Piece?>>[];

  List<Piece?> row = <Piece?>[];

  for (int i = Square.a8.bits; i <= Square.h1.bits; i++) {
    final Piece? piece = board[i];

    if (piece == null) {
      row.add(null);
    } else {
      row.add(piece);
    }

    if ((i + 1).off) {
      output.add(row);
      row = <Piece?>[];
      i += 8;
    }
  }

  return output;
}
