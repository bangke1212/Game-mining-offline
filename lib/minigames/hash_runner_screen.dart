import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _bg = Color(0xFF080B14);
const _surface = Color(0xFF111827);
const _elevated = Color(0xFF172238);
const _line = Color(0xFF2B3A57);
const _mint = Color(0xFF49F2C2);
const _violet = Color(0xFF7C5CFF);
const _amber = Color(0xFFFFB547);
const _coral = Color(0xFFFF5C7A);
const _muted = Color(0xFF8FA1BC);

/// Returned to the factory screen when Hash Runner ends.
class HashRunnerResult {
  const HashRunnerResult({
    required this.score,
    required this.reward,
    required this.heatChange,
    required this.completed,
    required this.accuracy,
    required this.mistakes,
    required this.elapsed,
  });

  final int score;
  final int reward;
  final double heatChange;
  final bool completed;
  final double accuracy;
  final int mistakes;
  final Duration elapsed;
}

/// Pure gameplay state. Keeping this separate from the widget makes the rules
/// easy to unit-test and prevents widget rebuilds from resetting the run.
class HashRunnerController {
  HashRunnerController({this.duration = const Duration(seconds: 45), int? seed})
      : _random = Random(seed);

  static const int laneCount = 3;
  static const int columnsPerPattern = 8;

  final Duration duration;
  final Random _random;

  List<int> pattern = <int>[];
  int currentColumn = 0;
  int score = 0;
  int combo = 0;
  int bestCombo = 0;
  int mistakes = 0;
  int correctTaps = 0;
  Duration remaining = Duration.zero;
  Duration elapsed = Duration.zero;
  bool running = false;
  bool paused = false;
  bool finished = false;

  double get accuracy {
    final total = correctTaps + mistakes;
    return total == 0 ? 1 : correctTaps / total;
  }

  int get targetLane => pattern.isEmpty ? 0 : pattern[currentColumn];
  bool get patternComplete => currentColumn >= pattern.length;

  void start() {
    pattern = _newPattern();
    currentColumn = 0;
    score = 0;
    combo = 0;
    bestCombo = 0;
    mistakes = 0;
    correctTaps = 0;
    elapsed = Duration.zero;
    remaining = duration;
    running = true;
    paused = false;
    finished = false;
  }

  void pause() {
    if (running && !finished) paused = true;
  }

  void resume() {
    if (running && !finished) paused = false;
  }

  void advance(Duration delta) {
    if (!running || paused || finished) return;
    elapsed += delta;
    remaining = duration - elapsed;
    if (remaining <= Duration.zero) {
      remaining = Duration.zero;
      finish();
    }
  }

  bool tapLane(int lane) {
    if (!running || paused || finished || lane < 0 || lane >= laneCount) return false;

    if (lane == targetLane) {
      correctTaps += 1;
      combo += 1;
      bestCombo = max(bestCombo, combo);
      score += 100 + (combo - 1) * 25;
      currentColumn += 1;
      if (patternComplete) {
        score += 250;
        pattern = _newPattern();
        currentColumn = 0;
      }
      return true;
    }

    mistakes += 1;
    combo = 0;
    score = max(0, score - 35);
    // A wrong node costs 1.5 seconds but never finishes the game instantly.
    elapsed += const Duration(milliseconds: 1500);
    remaining = duration - elapsed;
    if (remaining <= Duration.zero) {
      remaining = Duration.zero;
      finish();
    }
    return false;
  }

  HashRunnerResult finish() {
    if (!finished) {
      finished = true;
      running = false;
    }
    final completed = score >= 600 && accuracy >= 0.5;
    final reward = completed ? min(1200, 350 + score ~/ 2 + bestCombo * 30) : max(80, score ~/ 4);
    final heatChange = completed ? -10.0 : -3.0;
    return HashRunnerResult(
      score: score,
      reward: reward,
      heatChange: heatChange,
      completed: completed,
      accuracy: accuracy,
      mistakes: mistakes,
      elapsed: elapsed,
    );
  }

  List<int> _newPattern() => List<int>.generate(columnsPerPattern, (_) => _random.nextInt(laneCount));
}

/// Hash Runner is a short offline reflex game. The player routes a signal by
/// tapping the glowing lane in the current column before the timer expires.
class HashRunnerScreen extends StatefulWidget {
  const HashRunnerScreen({super.key, this.duration = const Duration(seconds: 45), this.seed});

  final Duration duration;
  final int? seed;

  @override
  State<HashRunnerScreen> createState() => _HashRunnerScreenState();
}

class _HashRunnerScreenState extends State<HashRunnerScreen> with WidgetsBindingObserver {
  late final HashRunnerController controller;
  late final FocusNode focusNode;
  Timer? timer;
  HashRunnerResult? result;
  DateTime? _lastTick;
  String? feedback;
  bool _exitRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = HashRunnerController(duration: widget.duration, seed: widget.seed);
    focusNode = FocusNode(debugLabel: 'hash-runner-input');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (controller.running && !controller.finished) {
        setState(controller.pause);
      }
    }
  }

  void _start() {
    setState(() {
      result = null;
      feedback = null;
      controller.start();
    });
    _lastTick = DateTime.now();
    timer?.cancel();
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    focusNode.requestFocus();
  }

  void _tick() {
    if (!mounted || !controller.running || controller.finished) return;
    final now = DateTime.now();
    final delta = _lastTick == null ? const Duration(milliseconds: 100) : now.difference(_lastTick!);
    _lastTick = now;
    setState(() => controller.advance(delta));
    if (controller.finished) _complete();
  }

  void _complete() {
    if (result != null) return;
    timer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() => result = controller.finish());
  }

  void _tapLane(int lane) {
    if (!controller.running || controller.paused || controller.finished) return;
    final correct = controller.tapLane(lane);
    if (correct) {
      HapticFeedback.selectionClick();
      setState(() => feedback = controller.combo > 1 ? 'COMBO ×${controller.combo}' : 'SIGNAL LOCKED');
    } else {
      HapticFeedback.heavyImpact();
      setState(() => feedback = 'FIREWALL HIT  −1.5s');
    }
    if (controller.finished) _complete();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.gameButtonStart) {
      _togglePause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW || key == LogicalKeyboardKey.digit1) {
      _tapLane(0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS || key == LogicalKeyboardKey.digit2) {
      _tapLane(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD || key == LogicalKeyboardKey.digit3) {
      _tapLane(2);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _togglePause() {
    if (!controller.running || controller.finished) return;
    setState(() {
      if (controller.paused) {
        controller.resume();
        _lastTick = DateTime.now();
      } else {
        controller.pause();
      }
    });
  }

  Future<void> _requestExit() async {
    if (_exitRequested) return;
    _exitRequested = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Exit Hash Runner?'),
        content: const Text('This run will not award a reward.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('KEEP PLAYING')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('EXIT')),
        ],
      ),
    );
    _exitRequested = false;
    if (shouldExit == true && mounted) {
      timer?.cancel();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (controller.running && !controller.finished) {
          await _requestExit();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Focus(
            focusNode: focusNode,
            autofocus: true,
            onKeyEvent: _handleKey,
            child: LayoutBuilder(builder: (context, constraints) {
              final landscape = constraints.maxWidth > 700 || constraints.maxWidth / constraints.maxHeight > 1.25;
              return landscape ? _landscapeLayout() : _portraitLayout();
            }),
          ),
        ),
      ),
    );
  }

  Widget _portraitLayout() => Column(children: [
        _header(),
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: controller.running ? _playingView(landscape: false) : _introOrResult(landscape: false))),
      ]);

  Widget _landscapeLayout() => Column(children: [
        _header(),
        Expanded(child: Row(children: [
          Expanded(flex: 7, child: Padding(padding: const EdgeInsets.fromLTRB(18, 6, 10, 16), child: controller.running ? _playingView(landscape: true) : _introOrResult(landscape: true))),
          SizedBox(width: 240, child: Padding(padding: const EdgeInsets.fromLTRB(10, 6, 18, 16), child: _sideStats())),
        ])),
      ]);

  Widget _header() => Padding(padding: const EdgeInsets.fromLTRB(16, 10, 12, 8), child: Row(children: [
        const Text('HASH', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const Text(' RUNNER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _mint, letterSpacing: 1.2)),
        const Spacer(),
        if (controller.running && !controller.finished) Text(_formatDuration(controller.remaining), style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold, color: _amber)),
        const SizedBox(width: 8),
        IconButton(onPressed: controller.running ? _togglePause : _requestExit, icon: Icon(controller.running ? (controller.paused ? Icons.play_arrow : Icons.pause) : Icons.close), tooltip: controller.running ? 'Pause' : 'Close'),
      ]));

  Widget _introOrResult({required bool landscape}) {
    final completedResult = result;
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _card(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(completedResult == null ? 'ROUTE THE SIGNAL' : (completedResult.completed ? 'SIGNAL DELIVERED' : 'SIGNAL LOST'), style: const TextStyle(color: _mint, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.8)),
      const SizedBox(height: 10),
      Text(completedResult == null ? 'Hash Runner' : 'Run complete', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(completedResult == null ? 'Tap the glowing lane in sequence to route the data packet through the grid. Wrong nodes trigger a firewall hit and cost 1.5 seconds.' : 'Score ${completedResult.score}  ·  accuracy ${(completedResult.accuracy * 100).round()}%  ·  mistakes ${completedResult.mistakes}', style: const TextStyle(color: _muted, height: 1.45)),
      const SizedBox(height: 16),
      if (completedResult != null) _resultStats(completedResult),
      if (completedResult == null) ...[
        _instructionRow(Icons.touch_app_outlined, 'Tap', 'Choose the glowing lane'),
        _instructionRow(Icons.timer_outlined, 'Race', '45 seconds per run'),
        _instructionRow(Icons.bolt_outlined, 'Reward', 'Up to 1,200 Credits + heat reduction'),
      ],
      const SizedBox(height: 18),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: _mint, foregroundColor: const Color(0xFF07131B), minimumSize: const Size.fromHeight(54)), child: Text(completedResult == null ? 'START RUN' : 'RUN AGAIN', style: const TextStyle(fontWeight: FontWeight.w900)))),
      if (completedResult == null) ...[const SizedBox(height: 10), const Center(child: Text('Keyboard: 1 / 2 / 3 or W / S / D', style: TextStyle(color: _muted, fontSize: 11)))],
    ]))));
  }

  Widget _playingView({required bool landscape}) => Column(children: [
        _progressHeader(),
        const SizedBox(height: 10),
        Expanded(child: _grid()),
        const SizedBox(height: 10),
        _laneControls(landscape: landscape),
        const SizedBox(height: 8),
        if (controller.paused) _pauseBanner(),
      ]);

  Widget _progressHeader() => Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('DATA ROUTE / NODE GRID', style: TextStyle(color: _mint, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.4)), const SizedBox(height: 5), Text(feedback ?? 'Tap the highlighted lane', style: const TextStyle(color: _muted, fontSize: 12))])),
        _scorePill('SCORE', controller.score.toString()),
        const SizedBox(width: 6), _scorePill('COMBO', '×${controller.combo}'),
      ]);

  Widget _grid() => _card(padding: const EdgeInsets.all(12), child: Column(children: [
        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var lane = 0; lane < HashRunnerController.laneCount; lane++) Expanded(child: Padding(padding: EdgeInsets.only(left: lane == 0 ? 0 : 4, right: lane == HashRunnerController.laneCount - 1 ? 0 : 4), child: _laneColumn(lane))),
        ])),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var column = 0; column < HashRunnerController.columnsPerPattern; column++) _columnDot(column)]),
      ]));

  Widget _laneColumn(int lane) => Column(children: [
        Expanded(child: Container(decoration: BoxDecoration(color: const Color(0xFF0C1322), borderRadius: BorderRadius.circular(12), border: Border.all(color: lane == controller.targetLane ? _mint.withOpacity(.65) : _line))), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(lane == controller.targetLane ? Icons.bolt : Icons.circle_outlined, color: lane == controller.targetLane ? _mint : _line, size: 34),
          const SizedBox(height: 8), Text('LANE ${lane + 1}', style: TextStyle(color: lane == controller.targetLane ? _mint : _muted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          if (lane == controller.targetLane) const Padding(padding: EdgeInsets.only(top: 6), child: Text('TARGET', style: TextStyle(color: _mint, fontSize: 9, fontWeight: FontWeight.bold))),
        ])))),
        const SizedBox(height: 8),
        AnimatedContainer(duration: const Duration(milliseconds: 160), height: 7, decoration: BoxDecoration(color: lane == controller.targetLane ? _mint : _elevated, borderRadius: BorderRadius.circular(99))),
      ]);

  Widget _columnDot(int column) {
    final active = column == controller.currentColumn;
    final passed = column < controller.currentColumn;
    return Container(width: 13, height: 6, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: active ? _mint : passed ? _violet : _line, borderRadius: BorderRadius.circular(99)));
  }

  Widget _laneControls({required bool landscape}) => Row(children: [
        for (var lane = 0; lane < HashRunnerController.laneCount; lane++) Expanded(child: Padding(padding: EdgeInsets.only(left: lane == 0 ? 0 : 4, right: lane == HashRunnerController.laneCount - 1 ? 0 : 4), child: SizedBox(height: landscape ? 52 : 58, child: ElevatedButton(onPressed: () => _tapLane(lane), style: ElevatedButton.styleFrom(backgroundColor: lane == controller.targetLane ? _mint : _elevated, foregroundColor: lane == controller.targetLane ? const Color(0xFF07131B) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text('${lane + 1}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))))),
      ]);

  Widget _pauseBanner() => _card(color: const Color(0xFF211D37), child: Row(children: [const Icon(Icons.pause_circle_outline, color: _violet), const SizedBox(width: 9), const Expanded(child: Text('RUN PAUSED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), TextButton(onPressed: _togglePause, child: const Text('RESUME'))]));

  Widget _sideStats() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('RUN READOUT', style: TextStyle(color: _mint, fontWeight: FontWeight.bold, letterSpacing: 1.4, fontSize: 11)), const SizedBox(height: 12), _sideMetric('TIME', _formatDuration(controller.remaining)), _sideMetric('BEST COMBO', '×${controller.bestCombo}'), _sideMetric('ERRORS', '${controller.mistakes}'), _sideMetric('TARGET', 'LANE ${controller.targetLane + 1}'), const Spacer(), const Text('Controls', style: TextStyle(color: _muted, fontSize: 11)), const SizedBox(height: 6), const Text('1 / 2 / 3\nW / S / D\nArrow keys', style: TextStyle(color: Colors.white, height: 1.5)), const SizedBox(height: 12), SizedBox(width: double.infinity, child: OutlinedButton(onPressed: controller.running ? _togglePause : null, child: Text(controller.paused ? 'RESUME' : 'PAUSE')))]);

  Widget _sideMetric(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: _muted, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold))])));

  Widget _resultStats(HashRunnerResult value) => Wrap(spacing: 8, runSpacing: 8, children: [_statChip('REWARD', '+${value.reward}'), _statChip('HEAT', '${value.heatChange.round()}°C'), _statChip('BEST', '×${controller.bestCombo}')]);
  Widget _statChip(String label, String value) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9), decoration: BoxDecoration(color: _elevated, borderRadius: BorderRadius.circular(9), border: Border.all(color: _line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: _muted, fontSize: 9)), const SizedBox(height: 3), Text(value, style: const TextStyle(color: _mint, fontFamily: 'monospace', fontWeight: FontWeight.bold))]));
  Widget _scorePill(String label, String value) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: _line)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(label, style: const TextStyle(color: _muted, fontSize: 8)), Text(value, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold))]));
  Widget _instructionRow(IconData icon, String title, String body) => Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [Icon(icon, color: _violet, size: 20), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 7), Expanded(child: Text(body, style: const TextStyle(color: _muted, fontSize: 12)))]));
  Widget _card({required Widget child, Color color = _surface, EdgeInsets padding = const EdgeInsets.all(14)}) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)), child: child);

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 5999);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
