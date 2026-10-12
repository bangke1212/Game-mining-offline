import 'package:flutter_test/flutter_test.dart';
import 'package:hashhaven/minigames/hash_runner_screen.dart';

void main() {
  group('HashRunnerController', () {
    test('starts with a deterministic target pattern when seeded', () {
      final first = HashRunnerController(seed: 42);
      final second = HashRunnerController(seed: 42);
      first.start();
      second.start();

      expect(first.pattern, equals(second.pattern));
      expect(first.remaining, const Duration(seconds: 45));
      expect(first.score, 0);
    });

    test('correct taps advance the route and build combo', () {
      final controller = HashRunnerController(seed: 7);
      controller.start();
      final target = controller.targetLane;

      expect(controller.tapLane(target), isTrue);
      expect(controller.correctTaps, 1);
      expect(controller.combo, 1);
      expect(controller.score, 100);
      expect(controller.currentColumn, 1);
    });

    test('wrong taps cost time and reset combo without negative score', () {
      final controller = HashRunnerController(seed: 7);
      controller.start();
      controller.tapLane(controller.targetLane);
      final before = controller.remaining;
      final wrong = (controller.targetLane + 1) % HashRunnerController.laneCount;

      expect(controller.tapLane(wrong), isFalse);
      expect(controller.mistakes, 1);
      expect(controller.combo, 0);
      expect(controller.remaining, lessThan(before));
      expect(controller.score, greaterThanOrEqualTo(0));
    });

    test('finish awards a bounded reward and marks the run complete', () {
      final controller = HashRunnerController(seed: 1);
      controller.start();
      final result = controller.finish();

      expect(controller.finished, isTrue);
      expect(result.reward, inInclusiveRange(80, 1200));
      expect(result.heatChange, lessThanOrEqualTo(0));
    });
  });
}
