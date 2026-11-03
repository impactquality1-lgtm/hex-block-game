import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'hex.dart';
import 'sounds.dart';

void main() => runApp(const HexBlocksApp());

const List<Color> pieceColors = [
  Color(0xFFEF5350),
  Color(0xFF42A5F5),
  Color(0xFFFDD835),
  Color(0xFF66BB6A),
  Color(0xFFAB47BC),
  Color(0xFFFF7043),
];

class HexBlocksApp extends StatelessWidget {
  const HexBlocksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hex Blocks',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      home: const SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}
class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800));
  final AudioPlayer _splashPlayer = AudioPlayer();
  bool _navigated = false;
  @override
  void initState() {
    super.initState();
    _splashPlayer.play(BytesSource(buildChimeWav([261.63, 329.63, 392.00, 523.25, 659.25, 783.99], noteSeconds: 0.16))).catchError((_) {});
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 4800), _goToGame);
  }
  @override
  void dispose() {
    _splashPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }
  Widget _splashPopup(double t, double start, Alignment alignment, String text) {
    final local = ((t - start) / 0.22).clamp(0.0, 1.0);
    final opacity = (local < 0.7 ? 1.0 : 1.0 - (local - 0.7) / 0.3).clamp(0.0, 1.0);
    final scale = Curves.easeOutBack.transform(local);
    return Align(alignment: alignment, child: Opacity(opacity: opacity, child: Transform.scale(scale: scale, child: Text(text, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.amber, shadows: [Shadow(blurRadius: 12, color: Colors.black54, offset: Offset(0, 2))])))));
  }
  void _goToGame() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(transitionDuration: const Duration(milliseconds: 400), pageBuilder: (context, animation, secondaryAnimation) => const GamePage(), transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child)));
  }
  @override
  Widget build(BuildContext context) {
    const hexPiece = Piece([Axial(0, 0), Axial(1, 0), Axial(0, 1), Axial(-1, 1), Axial(0, -1), Axial(1, -1), Axial(-1, 0)], 1);
    return GestureDetector(
      onTap: _goToGame,
      child: Scaffold(
        backgroundColor: const Color(0xFF102027),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final titleScale = Curves.elasticOut.transform((t * 1.8).clamp(0.0, 1.0));
            final hexScale = Curves.elasticOut.transform(((t - 0.15) * 1.6).clamp(0.0, 1.0));
            final subOpacity = ((t - 0.45) * 2.5).clamp(0.0, 1.0);
            return Stack(
              children: [
                Center(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(scale: hexScale, child: SizedBox(width: 150, height: 150, child: CustomPaint(painter: _PiecePainter(hexPiece, 20)))),
                  const SizedBox(height: 16),
                  Transform.scale(scale: titleScale, child: const Text('HEX BLOCKS', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white, shadows: [Shadow(blurRadius: 16, color: Colors.tealAccent, offset: Offset(0, 0))]))),
                  const SizedBox(height: 8),
                  Opacity(opacity: subOpacity, child: const Text('Fill lines. Clear them. Score big.', style: TextStyle(fontSize: 18, color: Colors.white70))),
                  const SizedBox(height: 48),
                  const Text('Tap to skip', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
                ),
                _splashPopup(t, 0.12, const Alignment(-0.65, -0.65), '+100'),
                _splashPopup(t, 0.32, const Alignment(0.65, -0.35), 'Combo! 2 lines!'),
                _splashPopup(t, 0.52, const Alignment(-0.6, 0.45), '+250'),
                _splashPopup(t, 0.72, const Alignment(0.6, 0.65), '+100'),
              ],
            );
          },
        ),
      ),
    );
  }
}
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  final HexGame game = HexGame();
  int best = 0;
  final AudioPlayer _clearPlayer = AudioPlayer();
  late final AnimationController _clearController = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
  late final Animation<double> _clearScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.35), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 20),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 20),
  ]).animate(_clearController);
  late final Animation<double> _clearOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 75),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
  ]).animate(_clearController);
  @override
  void dispose() {
    _clearController.dispose();
    _clearPlayer.dispose();
    super.dispose();
  }
  Uint8List _clearSoundWav(bool combo) {
    const sampleRate = 22050;
    const noteSeconds = 0.14;
    final notes = combo ? [523.25, 659.25, 783.99, 1046.50, 1318.51] : [523.25, 659.25, 783.99, 1046.50];
    final samplesPerNote = (sampleRate * noteSeconds).round();
    final pcm = <int>[];
    for (var n = 0; n < notes.length; n++) {
      for (var i = 0; i < samplesPerNote; i++) {
        final t = i / sampleRate;
        final progress = i / samplesPerNote;
        final envelope = progress < 0.05 ? progress / 0.05 : 1.0 - 0.6 * ((progress - 0.05) / 0.95);
        final value = math.sin(2 * math.pi * notes[n] * t) * envelope * 0.5;
        final sample = (value * 32767).round().clamp(-32768, 32767);
        pcm.add(sample & 0xFF);
        pcm.add((sample >> 8) & 0xFF);
      }
    }
    final dataSize = pcm.length;
    final header = ByteData(44);
    void writeString(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }
    writeString(0, 'RIFF');
    header.setUint32(4, 36 + dataSize, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    writeString(36, 'data');
    header.setUint32(40, dataSize, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
  }
  Future<void> _playClearSound(bool combo) async {
    try {
      await _clearPlayer.play(BytesSource(_clearSoundWav(combo)));
    } catch (_) {}
  }
  int? selectedTrayIndex;
  int? draggingTrayIndex;
  Offset? dragPosition;
  Axial? ghostAnchor;
  bool ghostValid = false;
  final GlobalKey _boardKey = GlobalKey();
  double _boardWidth = 300;
  double _boardHexSize = 18;

  HexLayout get _layout => HexLayout(_boardHexSize);

  Offset _boardCenter() {
    final height = _boardHexSize * 15;
    return Offset(_boardWidth / 2, height / 2);
  }

  void _startDrag(int trayIndex, Offset globalPosition) {
    setState(() {
      draggingTrayIndex = trayIndex;
      selectedTrayIndex = null;
      dragPosition = globalPosition;
      _updateGhost(globalPosition);
    });
  }

  void _updateDrag(Offset globalPosition) {
    setState(() {
      dragPosition = globalPosition;
      _updateGhost(globalPosition);
    });
  }

  void _updateGhost(Offset globalPosition) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      ghostAnchor = null;
      ghostValid = false;
      return;
    }
    final local = box.globalToLocal(globalPosition);
    final center = _boardCenter();
    final point = math.Point<double>(local.dx - center.dx, local.dy - center.dy);
    final anchor = _layout.fromPixel(point);
    final piece = draggingTrayIndex != null ? game.tray[draggingTrayIndex!] : null;
    ghostAnchor = anchor;
    ghostValid = piece != null && game.canPlace(piece, anchor);
  }

  void _endDrag() {
    final trayIndex = draggingTrayIndex;
    final anchor = ghostAnchor;
    final wasValid = ghostValid;
    setState(() {
      draggingTrayIndex = null;
      dragPosition = null;
      ghostAnchor = null;
      ghostValid = false;
    });
    if (trayIndex != null && anchor != null && wasValid) {
      _place(trayIndex, anchor);
    }
  }

  void _place(int trayIndex, Axial anchor) {
    if (game.isClearing) return;
    final cleared = game.place(trayIndex, anchor);
    setState(() {
      selectedTrayIndex = null;
      if (cleared && game.gameOver && game.score > best) best = game.score;
    });
    if (cleared && game.isClearing) {
      _playClearSound(game.clearingLines > 1);
      _clearController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 950), () {
        if (!mounted || !game.isClearing) return;
        setState(() {
          game.finishClear();
          if (game.gameOver && game.score > best) best = game.score;
        });
      });
    }
  }

  void _onBoardTap(TapUpDetails details) {
    final trayIndex = selectedTrayIndex;
    if (trayIndex == null) return;
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final center = _boardCenter();
    final point = math.Point<double>(local.dx - center.dx, local.dy - center.dy);
    final anchor = _layout.fromPixel(point);
    _place(trayIndex, anchor);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = (screenHeight - 320).clamp(200.0, double.infinity);
    _boardHexSize = math.min((screenWidth - 32) / 16, availableHeight / 15);
    _boardWidth = _boardHexSize * 16;
    final boardHeight = _boardHexSize * 15;
    final draggingPiece = draggingTrayIndex != null ? game.tray[draggingTrayIndex!] : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hex Blocks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New game',
            onPressed: () => setState(game.newGame),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _scoreBox('Score', '${game.score}'),
                  const SizedBox(width: 16),
                  _scoreBox('Best', '$best'),
                  const SizedBox(width: 16),
                  _scoreBox('Lines', '${game.linesCleared}'),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 22,
                child: Text(game.message ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              AnimatedBuilder(
                animation: _clearController,
                builder: (context, child) {
                  return GestureDetector(
                    onTapUp: _onBoardTap,
                    child: Container(
                      key: _boardKey,
                      width: _boardWidth,
                      height: boardHeight,
                      child: CustomPaint(
                        painter: _BoardPainter(game: game, layout: _layout, center: _boardCenter(), ghostAnchor: ghostAnchor, ghostPiece: draggingPiece, ghostValid: ghostValid, clearingCells: game.clearingCells, clearFlash: _clearController.value),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text('Drag a piece onto the board, tap a piece then tap a cell, or double-tap a piece to rotate it.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [for (var i = 0; i < game.tray.length; i++) _traySlot(i)],
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Fill a full line in any of the 3 hex directions to clear it.', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
          if (draggingPiece != null && dragPosition != null)
            Positioned(
              left: dragPosition!.dx - 45,
              top: dragPosition!.dy - 45,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.9,
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(painter: _PiecePainter(draggingPiece, 13, ghostValid: true)),
                  ),
                ),
              ),
            ),
          if (game.isClearing)
            IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _clearController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _clearOpacity.value,
                      child: Transform.scale(
                        scale: _clearScale.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.star, color: Colors.amber, size: 32), SizedBox(width: 4), Icon(Icons.star, color: Colors.amber, size: 40), SizedBox(width: 4), Icon(Icons.star, color: Colors.amber, size: 32)]),
                            const SizedBox(height: 4),
                            Text('+${game.clearingPoints}', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.amber.shade300, shadows: const [Shadow(blurRadius: 12, color: Colors.black87, offset: Offset(0, 3))])),
                            Text(game.clearingLines > 1 ? 'Combo! ${game.clearingLines} lines!' : 'Line cleared!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 8, color: Colors.black87, offset: Offset(0, 2))])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (game.gameOver)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No moves left!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Score: ${game.score}'),
                        Text('Lines cleared: ${game.linesCleared}'),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: () => setState(game.newGame), child: const Text('Play again')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scoreBox(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _traySlot(int index) {
    final piece = game.tray[index];
    final selected = selectedTrayIndex == index;
    final dragging = draggingTrayIndex == index;
    return GestureDetector(
      onTap: () {
        if (piece == null) return;
        setState(() { selectedTrayIndex = selected ? null : index; });
      },
      onDoubleTap: () {
        if (piece == null) return;
        setState(() { game.rotateTrayPiece(index); });
      },
      onPanStart: (details) {
        if (piece == null) return;
        _startDrag(index, details.globalPosition);
      },
      onPanUpdate: (details) => _updateDrag(details.globalPosition),
      onPanEnd: (_) => _endDrag(),
      onPanCancel: () => setState(() {
        draggingTrayIndex = null;
        dragPosition = null;
        ghostAnchor = null;
        ghostValid = false;
      }),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 2 : 1), borderRadius: BorderRadius.circular(12)),
        child: Opacity(opacity: dragging ? 0.25 : 1, child: piece == null ? const SizedBox.shrink() : CustomPaint(painter: _PiecePainter(piece, 13))),
      ),
    );
  }
}

Path _hexPath(Offset center, double size) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final angle = (60 * i - 90) * math.pi / 180;
    final point = Offset(center.dx + size * math.cos(angle), center.dy + size * math.sin(angle));
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  return path;
}

class _BoardPainter extends CustomPainter {
  final HexGame game;
  final HexLayout layout;
  final Offset center;
  final Axial? ghostAnchor;
  final Piece? ghostPiece;
  final bool ghostValid;
  final Set<Axial> clearingCells;
  final double clearFlash;
  _BoardPainter({required this.game, required this.layout, required this.center, required this.ghostAnchor, required this.ghostPiece, required this.ghostValid, this.clearingCells = const {}, this.clearFlash = 0});
  @override
  void paint(Canvas canvas, Size size) {
    final emptyFill = Paint()..color = const Color(0xFF263238);
    final emptyStroke = Paint()..color = Colors.white24..style = PaintingStyle.stroke;
    for (final cell in game.cells) {
      final p = layout.toPixel(cell);
      final cellCenter = Offset(center.dx + p.x, center.dy + p.y);
      final colorIndex = game.board[cell];
      if (colorIndex != null) {
        var color = pieceColors[colorIndex % pieceColors.length];
        var cellSize = layout.size * 0.92;
        if (clearingCells.contains(cell)) {
          final pulse = 0.5 + 0.5 * math.sin(clearFlash * math.pi * 6);
          color = Color.lerp(color, Colors.white, 0.45 + 0.4 * pulse)!;
          cellSize = layout.size * (0.92 + 0.12 * pulse);
        }
        canvas.drawPath(_hexPath(cellCenter, cellSize), Paint()..color = color);
      } else {
        canvas.drawPath(_hexPath(cellCenter, layout.size * 0.92), emptyFill);
        canvas.drawPath(_hexPath(cellCenter, layout.size * 0.92), emptyStroke);
      }
    }
    if (ghostAnchor != null && ghostPiece != null && ghostValid) {
      final ghostPaint = Paint()..color = pieceColors[ghostPiece!.color % pieceColors.length].withOpacity(0.55);
      for (final offset in ghostPiece!.cells) {
        final cell = ghostAnchor! + offset;
        final p = layout.toPixel(cell);
        final cellCenter = Offset(center.dx + p.x, center.dy + p.y);
        canvas.drawPath(_hexPath(cellCenter, layout.size * 0.92), ghostPaint);
      }
    }
  }
  @override
  bool shouldRepaint(_BoardPainter old) => true;
}

class _PiecePainter extends CustomPainter {
  final Piece piece;
  final double hexSize;
  final bool ghostValid;
  _PiecePainter(this.piece, this.hexSize, {this.ghostValid = false});
  @override
  void paint(Canvas canvas, Size size) {
    final layout = HexLayout(hexSize);
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final cell in piece.cells) {
      final p = layout.toPixel(cell);
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final offset = Offset(size.width / 2 - (minX + maxX) / 2, size.height / 2 - (minY + maxY) / 2);
    final paint = Paint()..color = pieceColors[piece.color % pieceColors.length];
    for (final cell in piece.cells) {
      final p = layout.toPixel(cell);
      final cellCenter = Offset(offset.dx + p.x, offset.dy + p.y);
      canvas.drawPath(_hexPath(cellCenter, hexSize * 0.92), paint);
    }
  }
  @override
  bool shouldRepaint(_PiecePainter old) => true;
}
