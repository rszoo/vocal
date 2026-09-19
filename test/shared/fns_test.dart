// ./test/shared/fns_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_note_app/shared/fns.dart';

void main() {
  group('NumListExtension', () {
    group('mean', () {
      test('整数のリストの平均を計算できる', () {
        expect([1, 2, 3, 4].mean, closeTo(2.5, 1e-9));
      });

      test('負の数を含むdoubleのリストの平均を計算できる', () {
        expect([-1.5, 0.5, 4.0].mean, closeTo(1.0, 1e-9));
      });

      test('要素が1つのリストはその値自体を返す', () {
        expect([42].mean, closeTo(42.0, 1e-9));
      });
    });

    group('meansq', () {
      test('二乗平均を計算できる', () {
        // (1^2 + 2^2 + 3^2) / 3 = 14 / 3 ≈ 4.6666666667
        expect([1, 2, 3].meansq, closeTo(14 / 3, 1e-9));
      });

      test('負の数も二乗して正の平均になる', () {
        // ((-2)^2 + 2^2) / 2 = 4.0
        expect([-2, 2].meansq, closeTo(4.0, 1e-9));
      });
    });

    group('rms', () {
      test('実効値（RMS）を計算できる', () {
        // sqrt((3^2 + 4^2) / 2) = sqrt(12.5)
        expect([3, 4].rms, closeTo(3.5355339059, 1e-9));
      });

      test('すべて同じ値ならその絶対値になる', () {
        expect([-5, -5, -5].rms, closeTo(5.0, 1e-9));
      });
    });

    group('argmin', () {
      test('指定範囲 [from, to] 内の最小値のインデックスを返す', () {
        final list = [10, 2, 5, 1, 8, 3];
        // index 1..4 は [2, 5, 1, 8] -> 最小値は 1 (index 3)
        expect(list.argmin(1, 4), equals(3));
        // index 0..2 は [10, 2, 5] -> 最小値は 2 (index 1)
        expect(list.argmin(0, 2), equals(1));
      });

      test('最小値が複数ある場合は最初のインデックスを返す', () {
        final list = [5, 2, 7, 2, 9];
        expect(list.argmin(0, 4), equals(1));
      });

      test('doubleのリストでも動作する', () {
        final list = [1.5, 0.2, 0.2, 1.1];
        expect(list.argmin(0, 3), equals(1));
      });

      test('空のリストではAssertionErrorになる', () {
        expect(<int>[].argmin(0, 1), throwsA(isA<AssertionError>()));
      });

      test('インデックスが範囲外の場合はAssertionErrorになる', () {
        final list = [10, 20, 30];
        expect(() => list.argmin(-1, 2), throwsA(isA<AssertionError>()));
        expect(() => list.argmin(0, 3), throwsA(isA<AssertionError>()));
      });

      test('from >= to の場合はAssertionErrorになる', () {
        final list = [10, 20, 30];
        expect(() => list.argmin(1, 1), throwsA(isA<AssertionError>()));
        expect(() => list.argmin(2, 1), throwsA(isA<AssertionError>()));
      });
    });
  });
}
