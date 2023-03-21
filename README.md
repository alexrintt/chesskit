# Chesskit

Fork of: https://github.com/lubert/chess.ts.


---

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

## Standard Chess Game

### Start a game
To instantiate a standard Chess game, use the Chess.initial constructor.
```dart
Chess game = Chess.initial;
```

### Make a move
From UCI Notation:
```dart
final Move? move = Move.fromUci("e2e4");
```

### Update the game
```dart
if (move != null && game.isLegal(move)) {
	game = game.playUnchecked(move) as Chess;
}
```

### Get the outcome
```dart
if (game.isGameOver) {
	final Outcome outcome = game.outcome!;
}
```

## Chess Variants
There are other Chess variants available to play.

### Antichess
```dart
Antichess game = Antichess.initial;
```

### Atomic
```dart
Atomic game = Atomic.initial;
```

### King Of The Hill
```dart
KingOfTheHill game = KingOfTheHill.initial;
```

### Crazy House
```dart
Crazyhouse game = Crazyhouse.initial;
```

### Three Check
```dart
ThreeCheck game = ThreeCheck.initial;
```

## Getting Info From A Position
### Get Rank
```dart
final rank = squareRank(Squares.f1); // 0
```

### Get File
```dart
final file = squareFile(Squares.c4); // 2
```

### Get Piece
```dart
final piece = game.pieceAt(Squares.d4); // Get Piece at d4
```

### Get Occupied Squares

```dart
final occupied = game.board.occupied;
```

### Get All Legal Moves
```dart
final legalMoves = game.legalMoves;
```

### Get All Legal Moves Of Square
```dart
final legaMovesA1 = game.legalMovesOf(Squares.a1);
```
