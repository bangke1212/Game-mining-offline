import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'minigames/hash_runner_screen.dart';

const bg = Color(0xFF080B14);
const surface = Color(0xFF111827);
const elevated = Color(0xFF172238);
const line = Color(0xFF2B3A57);
const mint = Color(0xFF49F2C2);
const violet = Color(0xFF7C5CFF);
const amber = Color(0xFFFFB547);
const coral = Color(0xFFFF5C7A);
const muted = Color(0xFF8FA1BC);

void main() => runApp(const HashHavenApp());

class MinerMachine {
  MinerMachine({required this.name, required this.kind, required this.hash, this.level = 1, this.heat = 20, this.online = true});
  String name;
  String kind;
  double hash;
  int level;
  double heat;
  bool online;

  Map<String, dynamic> toJson() => {'name': name, 'kind': kind, 'hash': hash, 'level': level, 'heat': heat, 'online': online};
  factory MinerMachine.fromJson(Map<String, dynamic> json) => MinerMachine(
    name: json['name'] as String? ?? 'Unknown Rig',
    kind: json['kind'] as String? ?? 'GPU',
    hash: (json['hash'] as num?)?.toDouble() ?? 1,
    level: json['level'] as int? ?? 1,
    heat: (json['heat'] as num?)?.toDouble() ?? 20,
    online: json['online'] as bool? ?? true,
  );
}

class GameState {
  double credits;
  double energy;
  double temperature;
  double xp;
  int level;
  int completedRuns;
  DateTime lastSaved;
  List<MinerMachine> machines;

  GameState({this.credits = 12840, this.energy = 74, this.temperature = 42, this.xp = 5000, this.level = 4, this.completedRuns = 0, DateTime? lastSaved, List<MinerMachine>? machines})
      : lastSaved = lastSaved ?? DateTime.now(),
        machines = machines ?? [
          MinerMachine(name: 'GPU 01', kind: 'Neon Miner X2', hash: 4.2, heat: 34),
          MinerMachine(name: 'ASIC 02', kind: 'Frost ASIC', hash: 7.8, heat: 72),
          MinerMachine(name: 'FAN CORE', kind: 'Cooling Array', hash: 2.1, heat: 18),
        ];

  double get hashPower => machines.where((machine) => machine.online).fold(0, (sum, machine) => sum + machine.hash);
  double get productionPerMinute => hashPower * (temperature >= 90 ? 0.45 : 1.0) * 1.15;
  int get upgradeCost => 2400 + (machines.fold<int>(0, (sum, machine) => sum + machine.level) * 350);

  Map<String, dynamic> toJson() => {
    'credits': credits, 'energy': energy, 'temperature': temperature, 'xp': xp, 'level': level,
    'completedRuns': completedRuns, 'lastSaved': lastSaved.toIso8601String(),
    'machines': machines.map((machine) => machine.toJson()).toList(),
  };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
    credits: (json['credits'] as num?)?.toDouble() ?? 12840,
    energy: (json['energy'] as num?)?.toDouble() ?? 74,
    temperature: (json['temperature'] as num?)?.toDouble() ?? 42,
    xp: (json['xp'] as num?)?.toDouble() ?? 5000,
    level: json['level'] as int? ?? 4,
    completedRuns: json['completedRuns'] as int? ?? 0,
    lastSaved: DateTime.tryParse(json['lastSaved'] as String? ?? '') ?? DateTime.now(),
    machines: (json['machines'] as List<dynamic>? ?? []).map((item) => MinerMachine.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
  );
}

class HashHavenApp extends StatelessWidget {
  const HashHavenApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'HashHaven',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: mint, secondary: violet, surface: surface, error: coral),
      fontFamily: 'sans',
      sliderTheme: const SliderThemeData(activeTrackColor: mint, thumbColor: mint),
    ),
    home: const FactoryScreen(),
  );
}

class FactoryScreen extends StatefulWidget {
  const FactoryScreen({super.key});
  @override
  State<FactoryScreen> createState() => _FactoryScreenState();
}

class _FactoryScreenState extends State<FactoryScreen> with WidgetsBindingObserver {
  GameState state = GameState();
  Timer? ticker;
  int tab = 0;
  bool loaded = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();
    _save();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused || appState == AppLifecycleState.detached) _save();
    if (appState == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('hashhaven.save');
    if (raw != null) {
      try {
        final saved = GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        final offlineSeconds = DateTime.now().difference(saved.lastSaved).inSeconds.clamp(0, 8 * 60 * 60);
        saved.credits += offlineSeconds * saved.productionPerMinute / 60 * 0.25;
        state = saved;
        if (offlineSeconds > 60 && mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _showOfflineReward(Duration(seconds: offlineSeconds)));
      } catch (_) {
        state = GameState();
      }
    }
    if (mounted) setState(() => loaded = true);
  }

  Future<void> _save() async {
    state.lastSaved = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hashhaven.save', jsonEncode(state.toJson()));
  }

  void _tick() {
    if (!loaded || !mounted) return;
    setState(() {
      if (state.energy > 0 && state.hashPower > 0) {
        state.credits += state.productionPerMinute / 60;
        state.xp += 0.2;
        state.energy = math.max(0, state.energy - 0.018);
        state.temperature = math.min(100, state.temperature + 0.055);
      }
      for (final machine in state.machines) {
        if (machine.online) machine.heat = math.min(100, machine.heat + 0.04);
      }
    });
    if (DateTime.now().second % 10 == 0) _save();
  }

  void _mineNow() {
    HapticFeedback.mediumImpact();
    setState(() {
      state.credits += 240;
      state.xp += 30;
      state.temperature = math.min(100, state.temperature + 2);
      state.energy = math.max(0, state.energy - 1);
    });
    _save();
  }

  void _coolDown() {
    HapticFeedback.lightImpact();
    setState(() {
      state.temperature = math.max(18, state.temperature - 14);
      state.energy = math.max(0, state.energy - 4);
      for (final machine in state.machines) machine.heat = math.max(12, machine.heat - 18);
    });
    _save();
  }

  void _upgrade(MinerMachine machine) {
    if (state.credits < state.upgradeCost) {
      _toast('Need ${state.upgradeCost} Credits for the next upgrade.');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      state.credits -= state.upgradeCost;
      machine.level += 1;
      machine.hash += 1.8;
      machine.heat = math.min(100, machine.heat + 5);
      state.xp += 120;
    });
    _save();
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: elevated));

  void _showOfflineReward(Duration elapsed) {
    final reward = (elapsed.inSeconds * state.productionPerMinute / 60 * 0.25).round();
    showDialog<void>(context: context, builder: (_) => AlertDialog(
      backgroundColor: surface,
      title: const Text('WELCOME BACK, TECHNICIAN'),
      content: Text('Your rigs worked for ${elapsed.inMinutes} minutes.\n\n+$reward Credits collected from offline production.\n\nOffline cap: 8 hours.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('COLLECT ALL'))],
    ));
  }

  void _settings() => showModalBottomSheet<void>(context: context, backgroundColor: surface, builder: (sheetContext) => SafeArea(child: Padding(
    padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SETTINGS', style: TextStyle(color: mint, fontWeight: FontWeight.bold, letterSpacing: 2)),
      const SizedBox(height: 18),
      const ListTile(leading: Icon(Icons.volume_up_outlined), title: Text('Sound & music'), trailing: Switch(value: true, onChanged: null)),
      const ListTile(leading: Icon(Icons.vibration), title: Text('Haptic feedback'), trailing: Switch(value: true, onChanged: null)),
      ListTile(leading: const Icon(Icons.delete_outline, color: coral), title: const Text('Reset local save', style: TextStyle(color: coral)), onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('hashhaven.save');
        if (mounted) setState(() => state = GameState());
        if (sheetContext.mounted) Navigator.pop(sheetContext);
      }),
    ]),
  )));

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Scaffold(body: Center(child: CircularProgressIndicator(color: mint)));
    return LayoutBuilder(builder: (context, constraints) {
      final landscape = constraints.maxWidth > 700 || constraints.maxWidth / constraints.maxHeight > 1.25;
      return Scaffold(
        body: SafeArea(child: landscape ? _landscapeLayout() : _portraitLayout()),
        bottomNavigationBar: landscape ? null : _bottomNav(),
      );
    });
  }

  Widget _header({bool compact = false}) => Padding(padding: EdgeInsets.fromLTRB(compact ? 14 : 18, 12, compact ? 14 : 18, 8), child: Row(children: [
    const Text('HASH', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
    const Text('HAVEN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: mint)),
    const Spacer(),
    Text('Credits ${state.credits.round()}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
    const SizedBox(width: 14),
    Text('⚡ ${state.energy.round()}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
    const SizedBox(width: 8),
    IconButton(onPressed: _settings, icon: const Icon(Icons.settings_outlined), tooltip: 'Settings'),
  ]));

  Widget _resourceStrip() => Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Row(children: [
    _resource('CREDITS', state.credits.round().toString()),
    const SizedBox(width: 7), _resource('ENERGY', '⚡ ${state.energy.round()}'),
    const SizedBox(width: 7), _resource('LEVEL', 'LV ${state.level}'),
  ]));

  Widget _resource(String label, String value) => Expanded(child: _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: muted, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold))])));

  Widget _portraitLayout() => Column(children: [
    _header(), _resourceStrip(), Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 3, 14, 8), child: _factoryContent(portrait: true))),
  ]);

  Widget _landscapeLayout() => Column(children: [
    _header(compact: true), const Divider(height: 1, color: Color(0xFF17243B)), Expanded(child: Row(children: [
      _rail(), Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _factoryContent(portrait: false))), _readout(),
    ])),
  ]);

  Widget _rail() => SizedBox(width: 112, child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [
    Text('LV ${state.level}', style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 16),
    for (final item in const [(Icons.home_outlined, 'Factory'), (Icons.blur_on, 'Games'), (Icons.account_tree_outlined, 'Research'), (Icons.person_outline, 'Crew'), (Icons.auto_awesome, 'Events')])
      Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(onTap: () => setState(() => tab = 0), borderRadius: BorderRadius.circular(10), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: item.$2 == 'Factory' ? const Color(0xFF183C3B) : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Column(children: [Icon(item.$1, size: 18, color: item.$2 == 'Factory' ? mint : muted), const SizedBox(height: 3), Text(item.$2, style: TextStyle(fontSize: 9, color: item.$2 == 'Factory' ? mint : muted))])))),
  ]));

  Widget _factoryContent({required bool portrait}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Text('FACTORY / NEON GARAGE', style: TextStyle(color: mint, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.7)), const Spacer(), Text('+${state.productionPerMinute.toStringAsFixed(1)} / min', style: const TextStyle(color: muted, fontSize: 11))]),
    const SizedBox(height: 7),
    _panel(gradient: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('HASH POWER', style: TextStyle(color: mint, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.6)), const SizedBox(height: 5), Text('${state.hashPower.toStringAsFixed(2)} TH/s', style: const TextStyle(fontSize: 29, fontFamily: 'monospace', fontWeight: FontWeight.bold)), const SizedBox(height: 10), _bar((state.hashPower / 7).clamp(0, 1).toDouble()), const SizedBox(height: 6), Text('Efficiency boost +12%', style: const TextStyle(color: muted, fontSize: 11))])),
    const SizedBox(height: 10),
    GridView.count(crossAxisCount: portrait ? 2 : 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: portrait ? 1.16 : 1.55, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: [
      for (final machine in state.machines) _machineCard(machine),
      _emptySlot(),
    ]),
    const SizedBox(height: 10), _temperatureCard(), const SizedBox(height: 10), _quickRun(),
    if (portrait) const SizedBox(height: 6),
    if (portrait) SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _mineNow, style: ElevatedButton.styleFrom(backgroundColor: mint, foregroundColor: const Color(0xFF07131B), minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('MINE NOW   +240 CREDITS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .4)))),
  ]);

  Widget _machineCard(MinerMachine machine) {
    final hot = machine.heat >= 70;
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(hot ? '● HOT ${machine.heat.round()}%' : '● ONLINE', style: TextStyle(color: hot ? amber : mint, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: .7)),
      const SizedBox(height: 7), Text(machine.name, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5),
      Text('+${machine.hash.toStringAsFixed(1)} / sec', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)), const Spacer(), _bar((machine.heat / 100).clamp(0, 1).toDouble(), color: hot ? amber : violet),
      SizedBox(width: double.infinity, child: TextButton(onPressed: () => hot ? _coolDown() : _upgrade(machine), style: TextButton.styleFrom(backgroundColor: hot ? amber : const Color(0xFF263954), foregroundColor: hot ? const Color(0xFF15110A) : Colors.white, padding: const EdgeInsets.symmetric(vertical: 5)), child: Text(hot ? 'COOL' : 'UPGRADE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
    ]));
  }

  Widget _emptySlot() => _panel(border: Border.all(color: line, style: BorderStyle.solid), child: Center(child: Text('＋ BUILD SLOT', style: const TextStyle(color: muted, fontSize: 11))));

  Widget _temperatureCard() {
    final critical = state.temperature >= 90;
    return _panel(border: Border.all(color: critical ? coral : amber), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(critical ? '⚠ CRITICAL HEAT' : '⚠ TEMPERATURE', style: TextStyle(color: critical ? coral : amber, fontWeight: FontWeight.bold, fontSize: 11)), const Spacer(), Text('${state.temperature.round()}°C / 70°C', style: const TextStyle(color: muted, fontSize: 11))]), const SizedBox(height: 8), _bar((state.temperature / 100).clamp(0, 1).toDouble(), color: critical ? coral : amber), const SizedBox(height: 6), Row(children: [Expanded(child: Text(critical ? 'Rigs slowing down — cool now.' : 'Healthy · keep the rigs below the redline.', style: const TextStyle(color: muted, fontSize: 11))), TextButton(onPressed: _coolDown, child: const Text('COOL DOWN'))])])));
  }

  Widget _quickRun() => _panel(border: Border.all(color: const Color(0xFF344073)), child: Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('QUICK RUN', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 5), Text('Hash Runner · route the signal', style: TextStyle(color: muted, fontSize: 11))])), TextButton(onPressed: _openHashRunner, style: TextButton.styleFrom(backgroundColor: violet, foregroundColor: Colors.white), child: const Text('PLAY NOW'))]));

  Widget _readout() => SizedBox(width: 218, child: Padding(padding: const EdgeInsets.fromLTRB(12, 16, 14, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('LIVE READOUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)), const SizedBox(height: 12), _metric('HASH POWER', '${state.hashPower.toStringAsFixed(2)} TH/s', '+${state.productionPerMinute.toStringAsFixed(1)} / min'), const SizedBox(height: 8), _panel(border: Border.all(color: amber), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('TEMPERATURE', style: TextStyle(color: muted, fontSize: 10)), const SizedBox(height: 5), Text('${state.temperature.round()}°C / 70°C', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 8), _bar((state.temperature / 100).clamp(0, 1).toDouble(), color: amber)])), const SizedBox(height: 8), Row(children: [Expanded(child: _metric('ENERGY', '${state.energy.round()} / 100', '')), const SizedBox(width: 7), Expanded(child: _metric('XP', state.xp.round().toString(), ''))]), const Spacer(), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _mineNow, style: ElevatedButton.styleFrom(backgroundColor: mint, foregroundColor: const Color(0xFF07131B), minimumSize: const Size.fromHeight(44)), child: const Text('COLLECT'))])));

  Widget _metric(String label, String value, String sub) => _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: muted, fontSize: 10)), const SizedBox(height: 5), Text(value, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 18)), if (sub.isNotEmpty) Text(sub, style: const TextStyle(color: mint, fontSize: 10))]));

  Widget _panel({required Widget child, Color? color, Border? border, bool gradient = false}) => Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: color ?? surface, gradient: gradient ? const LinearGradient(colors: [Color(0xFF102B32), Color(0xFF151B37)]) : null, border: border ?? Border.all(color: const Color(0xFF26334D)), borderRadius: BorderRadius.circular(12)), child: child);
  Widget _bar(double value, {Color color = mint}) => ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: value, minHeight: 7, backgroundColor: const Color(0xFF26324A), valueColor: AlwaysStoppedAnimation<Color>(color)));

  Widget _bottomNav() => NavigationBar(backgroundColor: bg, indicatorColor: const Color(0xFF183C3B), selectedIndex: tab, onDestinationSelected: (index) { if (index == 1) _openHashRunner(); else setState(() => tab = index); }, destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Factory'), NavigationDestination(icon: Icon(Icons.blur_on), label: 'Mini-games'), NavigationDestination(icon: Icon(Icons.account_tree_outlined), label: 'Research'), NavigationDestination(icon: Icon(Icons.person_outline), label: 'Crew'), NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Events')]);

  Future<void> _openHashRunner() async {
    final result = await Navigator.push<HashRunnerResult>(context, MaterialPageRoute(builder: (_) => const HashRunnerScreen()));
    if (!mounted || result == null) return;
    setState(() {
      state.credits += result.reward;
      state.temperature = math.max(18.0, state.temperature + result.heatChange);
      state.xp += result.score * 0.2;
      if (result.completed) state.completedRuns += 1;
    });
    await _save();
    _toast(result.completed ? 'Hash Runner cleared — +${result.reward} Credits' : 'Run ended — +${result.reward} recovery Credits');
  }

  void _playCoolingPanic() {
    int score = 0;
    int target = 0;
    final random = math.Random();
    showDialog<void>(context: context, barrierDismissible: false, builder: (dialogContext) => StatefulBuilder(builder: (context, update) {
      target = target == 0 ? random.nextInt(4) : target;
      return AlertDialog(backgroundColor: surface, title: const Text('COOLING PANIC'), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Tap the glowing fan node before the heat spikes.', style: TextStyle(color: muted)), const SizedBox(height: 16), Text('Combo $score / 5', style: const TextStyle(color: mint, fontWeight: FontWeight.bold)), const SizedBox(height: 12), Wrap(spacing: 10, runSpacing: 10, children: List.generate(4, (index) => SizedBox(width: 82, height: 54, child: ElevatedButton(onPressed: () { if (index == target) { score++; target = random.nextInt(4); update(() {}); if (score >= 5) { Navigator.pop(dialogContext); setState(() { state.credits += 650; state.temperature = math.max(18, state.temperature - 12); state.completedRuns++; state.xp += 250; }); _save(); _toast('Cooling Panic cleared — +650 Credits'); } } else { update(() => score = math.max(0, score - 1)); } }, style: ElevatedButton.styleFrom(backgroundColor: index == target ? mint : elevated, foregroundColor: index == target ? const Color(0xFF07131B) : Colors.white), child: Icon(index == target ? Icons.bolt : Icons.circle_outlined)))),)])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('PAUSE / EXIT'))]);
    }));
  }
}
