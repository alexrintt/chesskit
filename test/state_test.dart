import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../lib/nicochess.dart';

void main() {
  group('FEN parsing', () {
    test('Load default position', () {
      final State? state = loadFen(kDefaultPosition);

      expect(state, isNotNull);
    });
    test('Load a checkmate position', () {
      final State? state = loadFen('8/5r2/4K1q1/4p3/3k4/8/8/8 w - - 0 7');

      expect(state, isNotNull);
    });
  });
  group('Recognize a checkmate position', () {
    test('Load a checkmate position', () {
      final State? state = loadFen('8/5r2/4K1q1/4p3/3k4/8/8/8 w - - 0 7');

      expect(inCheckmate(state!), isTrue);
    });
  });
  test('State equality', () {
    expect(
      State.create(),
      equals(State.create()),
      reason:
          'When creating two State fresh instances equality is done via identity instead of equality.',
    );

    final State state = State.create();

    expect(
      state,
      equals(state.clone()),
      reason:
          'When creating cloning a State instance equality is done via identity instead of equality.',
    );

    expect(
      state,
      isNot(equals(state.modifyPiece(Square.a1, Piece.blackBishop))),
      reason:
          'When modifying an state instance it must not be equal to the original instance.',
    );

    expect(
      state,
      equals(
        state.clone(
          // modify map instance but do not modify the state.
          kings: Map<PieceColor, int>.from(state.kings),
        ),
      ),
      reason:
          'When modifying an state instance it must not be equal to the original instance.',
    );

    expect(
      state,
      isNot(
        equals(
          state.clone(
            // modify map instance but do not modify the state.
            kings: Map<PieceColor, int>.from(
              <PieceColor, int>{
                ...state.kings,
                PieceColor.black: (state.kings[PieceColor.black] ?? 0) + 1,
              },
            ),
          ),
        ),
      ),
      reason:
          'When modifying an state instance it must not be equal to the original instance.',
    );

    expect(
      state.clone(
        kings: Map<PieceColor, int>.from(
          <PieceColor, int>{
            ...state.kings,
            PieceColor.white: (state.kings[PieceColor.black] ?? 0) + 1,
          },
        ),
      ),
      isNot(
        equals(
          state.clone(
            // modify map instance but do not modify the state.
            kings: Map<PieceColor, int>.from(
              <PieceColor, int>{
                ...state.kings,
                PieceColor.black: (state.kings[PieceColor.black] ?? 0) + 1,
              },
            ),
          ),
        ),
      ),
      reason:
          'When modifying an state instance it must not be equal to the original instance.',
    );

    expect(
      state.clone(
        kings: Map<PieceColor, int>.from(
          <PieceColor, int>{
            ...state.kings,
            PieceColor.black: (state.kings[PieceColor.black] ?? 0) + 1,
          },
        ),
      ),
      equals(
        state.clone(
          // modify map instance but do not modify the state.
          kings: Map<PieceColor, int>.from(
            <PieceColor, int>{
              ...state.kings,
              PieceColor.black: (state.kings[PieceColor.black] ?? 0) + 1,
            },
          ),
        ),
      ),
      reason:
          'When modifying an state instance it must not be equal to the original instance.',
    );
  });
}
