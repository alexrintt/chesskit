const List<String> kFileNames = <String>[
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h'
];
const List<String> kRankNames = <String>[
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8'
];

/// The board part of the initial position in the FEN format.
const String kInitialBoardFEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';

/// Initial position in the Extended Position Description format.
const String kInitialEPD = '$kInitialBoardFEN w KQkq -';

/// Initial position in the FEN format.
const String kInitialFEN = '$kInitialEPD 0 1';

/// Empty board part in the FEN format.
const String kEmptyBoardFEN = '8/8/8/8/8/8/8/8';

/// Empty board in the EPD format.
const String kEmptyEPD = '$kEmptyBoardFEN w - -';

/// Empty board in the FEN format.
const String kEmptyFEN = '$kEmptyEPD 0 1';
