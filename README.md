Fork of: https://github.com/lubert/chess.ts.

The original repository is written in TypesScript but this fork was rewritten in Dart.

All credits goes to the original author.

---
# ChessKit

[![Pub Version](https://img.shields.io/pub/v/chesskit)](https://pub.dev/packages/chesskit)

This library aims to provide a rich and simple API to generate chess moves and validate board. This also support `FEN` and `PGN` to import or export chess matches.

## Why another chess engine?

Although there are some other Dart-based libraries for chess, I did not found one that:

- Has built-in customizable game engines to allow `vs computer`-like features, which will be the focus of this library on `v0.2.0`.
- Is up-to-date with latest Dart code style guides.
- Is designed to be fully functional and stateless (immutable).

## Installation

```yaml
dependencies:
  chesskit: ^<latest-version>
```

Import:

```dart
import 'package:chesskit/chesskit.dart';
```

## Usage

```dart
const SquareSet fullSet = SquareSet.full;
print(fullSet);
```

## Contributing

TODO.