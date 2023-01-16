import 'package:nicochess/types.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  void testSquare(Square square, PieceColor expectedColor) {
    test('Test if square $square computes the $expectedColor color correctly',
        () {
      expect(
        square.color,
        expectedColor,
        reason:
            'Failed for $square, expected $expectedColor but got ${square.color}',
      );
    });
  }

  group('Test if square color is correctly computed', () {
    testSquare(Square.a1, PieceColor.black);
    testSquare(Square.a2, PieceColor.white);
    testSquare(Square.a3, PieceColor.black);
    testSquare(Square.a4, PieceColor.white);
    testSquare(Square.a5, PieceColor.black);
    testSquare(Square.a6, PieceColor.white);
    testSquare(Square.a7, PieceColor.black);
    testSquare(Square.a8, PieceColor.white);

    testSquare(Square.b1, PieceColor.white);
    testSquare(Square.b2, PieceColor.black);
    testSquare(Square.b3, PieceColor.white);
    testSquare(Square.b4, PieceColor.black);
    testSquare(Square.b5, PieceColor.white);
    testSquare(Square.b6, PieceColor.black);
    testSquare(Square.b7, PieceColor.white);
    testSquare(Square.b8, PieceColor.black);

    testSquare(Square.c1, PieceColor.black);
    testSquare(Square.c2, PieceColor.white);
    testSquare(Square.c3, PieceColor.black);
    testSquare(Square.c4, PieceColor.white);
    testSquare(Square.c5, PieceColor.black);
    testSquare(Square.c6, PieceColor.white);
    testSquare(Square.c7, PieceColor.black);
    testSquare(Square.c8, PieceColor.white);

    testSquare(Square.d1, PieceColor.white);
    testSquare(Square.d2, PieceColor.black);
    testSquare(Square.d3, PieceColor.white);
    testSquare(Square.d4, PieceColor.black);
    testSquare(Square.d5, PieceColor.white);
    testSquare(Square.d6, PieceColor.black);
    testSquare(Square.d7, PieceColor.white);
    testSquare(Square.d8, PieceColor.black);

    testSquare(Square.e1, PieceColor.black);
    testSquare(Square.e2, PieceColor.white);
    testSquare(Square.e3, PieceColor.black);
    testSquare(Square.e4, PieceColor.white);
    testSquare(Square.e5, PieceColor.black);
    testSquare(Square.e6, PieceColor.white);
    testSquare(Square.e7, PieceColor.black);
    testSquare(Square.e8, PieceColor.white);

    testSquare(Square.f1, PieceColor.white);
    testSquare(Square.f2, PieceColor.black);
    testSquare(Square.f3, PieceColor.white);
    testSquare(Square.f4, PieceColor.black);
    testSquare(Square.f5, PieceColor.white);
    testSquare(Square.f6, PieceColor.black);
    testSquare(Square.f7, PieceColor.white);
    testSquare(Square.f8, PieceColor.black);

    testSquare(Square.g1, PieceColor.black);
    testSquare(Square.g2, PieceColor.white);
    testSquare(Square.g3, PieceColor.black);
    testSquare(Square.g4, PieceColor.white);
    testSquare(Square.g5, PieceColor.black);
    testSquare(Square.g6, PieceColor.white);
    testSquare(Square.g7, PieceColor.black);
    testSquare(Square.g8, PieceColor.white);

    testSquare(Square.h1, PieceColor.white);
    testSquare(Square.h2, PieceColor.black);
    testSquare(Square.h3, PieceColor.white);
    testSquare(Square.h4, PieceColor.black);
    testSquare(Square.h5, PieceColor.white);
    testSquare(Square.h6, PieceColor.black);
    testSquare(Square.h7, PieceColor.white);
    testSquare(Square.h8, PieceColor.black);
  });
  group('Flags', () {
    test('If flags enum and extensions can be converted to bits', () {
      const List<Flag> src = <Flag>[Flag.bigPawn, Flag.enPassantCapture];

      expect(src.bits.isNonZero(Flag.bigPawn.bits), isTrue);
      expect(src.bits.isNonZero(Flag.enPassantCapture.bits), isTrue);
      expect(src.bits.isNonZero(Flag.capture.bits), isFalse);
    });
  });
}
