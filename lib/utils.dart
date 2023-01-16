extension IsLowerCase on String {
  bool isLowerCase() => toLowerCase() == this;
  bool isUpperCase() => toUpperCase() == this;
}

/// Extracts the zero-based rank of an 0x88 square.
int rank(int i) {
  return i >> 4;
}

/// Extracts the zero-based file of an 0x88 square.
int file(int i) {
  return i & 15;
}

/// Converts a 0x88 square to algebraic notation.
String algebraic(int i) {
  final int f = file(i);
  final int r = rank(i);
  return 'abcdefgh'[f] + '87654321'[r];
}

/// Checks if a character is a numeric digit.
bool isDigit(String c) {
  return RegExp(r'^[0-9]$').hasMatch(c);
}

class FenValidation {
  final String message;
  final int? errorCode;

  const FenValidation(this.errorCode, this.message);

  const FenValidation.invalidFieldCount()
      : errorCode = 0x1,
        message = 'FEN string must contain six space-delimited fields.';

  FenValidation.moveNumberIsNotAPositiveInteger()
      : errorCode = 0x2,
        message = '6th field (move number) must be a positive integer.';

  FenValidation.halfMoveCounterIsNotAPositiveInteger()
      : errorCode = 0x3,
        message =
            '5th field (half move counter) must be a non-negative integer.';

  FenValidation.invalidEnPassantSquare()
      : errorCode = 0x4,
        message = '4th field (en-passant square) is invalid.';

  FenValidation.invalidCastlingAvailability()
      : errorCode = 0x5,
        message = '3rd field (castling availability) is invalid.';

  FenValidation.invalidSideToMove()
      : errorCode = 0x6,
        message = '2nd field (side to move) is invalid.';

  FenValidation.invalidDelimitedRowsCount()
      : errorCode = 0x7,
        message =
            "1st field (piece positions) does not contain 8 '/'-delimited rows.";

  FenValidation.invalidConsecutiveNumbers()
      : errorCode = 0x8,
        message =
            "1st field (piece positions) is invalid [consecutive numbers].";

  FenValidation.invalidPiece()
      : errorCode = 0x9,
        message = '1st field (piece positions) is invalid [invalid piece].';

  FenValidation.rowTooLarge()
      : errorCode = 0xa,
        message = '1st field (piece positions) is invalid [row too large].';

  FenValidation.illegalEnPassantSquare()
      : errorCode = 0xb,
        message = 'Illegal en-passant square';
}

/// Is not a number try parse a [numeric] string as a [int], return true if it fails.
bool isNaN(String numeric) => num.tryParse(numeric) == null;

/// Is not a integer try parse a [numeric] string as a [int], return true if it fails.
bool isNaI(String numeric) => int.tryParse(numeric) == null;

/// Is not a double, try parse a [numeric] string as a [double], return true if it fails.
bool isNaD(String numeric) => double.tryParse(numeric) == null;

FenValidation? validateFenStructure(String fen) {
  // 1st criterion: 6 space-seperated fields?
  final List<String> tokens = fen.split(RegExp(r'\s+'));

  if (tokens.length != 6) {
    return const FenValidation.invalidFieldCount();
  }

  // 2nd criterion: move number field is a integer value > 0?
  if (isNaI(tokens[5]) || int.parse(tokens[5], radix: 10) <= 0) {
    return FenValidation.moveNumberIsNotAPositiveInteger();
  }

  /* 3rd criterion: half move counter is an integer >= 0? */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  if (isNaI(tokens[4]) || int.parse(tokens[4], radix: 10) < 0) {
    return FenValidation.halfMoveCounterIsNotAPositiveInteger();
  }

  /* 4th criterion: 4th field is a valid e.p.-string? */
  if (!RegExp(r'^(-|[abcdefgh][36])$').hasMatch(tokens[3])) {
    return FenValidation.invalidEnPassantSquare();
  }

  /* 5th criterion: 3th field is a valid castle-string? */
  if (!RegExp(r'^(KQ?k?q?|Qk?q?|kq?|q|-)$').hasMatch(tokens[2])) {
    return FenValidation.invalidCastlingAvailability();
  }

  /* 6th criterion: 2nd field is "w" (white) or "b" (black)? */
  if (!RegExp(r'^(w|b)$').hasMatch(tokens[1])) {
    return FenValidation.invalidSideToMove();
  }

  /* 7th criterion: 1st field contains 8 rows? */
  final List<String> rows = tokens[0].split('/');

  if (rows.length != 8) {
    return FenValidation.invalidDelimitedRowsCount();
  }

  /* 8th criterion: every row is valid? */
  for (int i = 0; i < rows.length; i++) {
    /* check for right sum of fields AND not two numbers in succession */
    int sumFields = 0;
    bool previousWasNumber = false;

    for (int k = 0; k < rows[i].length; k++) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      if (!isNaN(rows[i][k])) {
        if (previousWasNumber) {
          return FenValidation.invalidConsecutiveNumbers();
        }
        sumFields += int.parse(rows[i][k], radix: 10);
        previousWasNumber = true;
      } else {
        if (!RegExp(r'^[prnbqkPRNBQK]$').hasMatch(rows[i][k])) {
          return FenValidation.invalidPiece();
        }
        sumFields += 1;
        previousWasNumber = false;
      }
    }
    if (sumFields != 8) {
      return FenValidation.rowTooLarge();
    }
  }

  if (tokens[3] != '-') {
    if ((tokens[3][1] == '3' && tokens[1] == 'w') ||
        (tokens[3][1] == '6' && tokens[1] == 'b')) {
      return FenValidation.illegalEnPassantSquare();
    }
  }

  return null;
}

/// Parses all of the decorators out of a SAN string.
String strippedSan(String move) {
  return move
      .replaceFirst(RegExp('='), '')
      .replaceFirst(RegExp(r'[+#]?[?!]*$'), '');
}
