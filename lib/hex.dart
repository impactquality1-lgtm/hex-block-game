import 'dart:math' as math;

import 'words.dart';

/// Axial coordinates for a pointy-top hex grid (see redblobgames.com).
/// The third cube coordinate is always s = -q - r.
class Axial {
  final int q;
  final int r;
  const Axial(this.q, this.r);

  int get s => -q - r;

  Axial operator +(Axial other) => Axial(q + other.q, r + other.r);

  @override
  bool operator ==(Object other) =>
      other is Axial && other.q == q && other.r == r;

  @override
  int get hashCode => Object.hash(q, r);

  @override
  String toString() => '($q,$r)';
}

/// All cells of a hexagon-shaped board of the given radius.
/// Radius 4 gives 61 cells (a hexagon 9 cells across at its widest).
List<Axial> boardCells(int radius) {
  final cells = <Axial>[];
  for (var q = -radius; q <= radius; q++) {
    final rMin = math.max(-radius, -q - radius);
    final rMax = math.min(radius, -q + radius);
    for (var r = rMin; r <= rMax; r++) {
      cells.add(Axial(q, r));
    }
  }
  return cells;
}

/// Lines on the board: every full row in each of the three hex directions.
/// A line is a group of board cells sharing q, r, or s.
List<List<Axial>> boardLines(List<Axial> cells) {
  final byQ = <int, List<Axial>>{};
  final byR = <int, List<Axial>>{};
  final byS = <int, List<Axial>>{};
  for (final cell in cells) {
    byQ.putIfAbsent(cell.q, () => []).add(cell);
    byR.putIfAbsent(cell.r, () => []).add(cell);
    byS.putIfAbsent(cell.s, () => []).add(cell);
  }
  return [...byQ.values, ...byR.values, ...byS.values];
}

/// A piece: a set of cells relative to an anchor cell, plus a colour index.
class Piece {
  final List<Axial> cells;
  final int color;
  final List<String> letters;
  const Piece(this.cells, this.color, [this.letters = const []]);
  Piece rotate60() {
    return Piece(cells.map((c) => Axial(-c.r, c.q + c.r)).toList(), color, letters);
  }
}

Piece _shape(List<List<int>> offsets, int color) {
  return Piece(
    offsets.map((o) => Axial(o[0], o[1])).toList(),
    color,
  );
}

/// The piece pool. Straight lines in all three directions, small clusters,
/// and one big 7-cell hexagon (rare, high value).
List<Piece> allPieces(int color) {
  return [
    _shape([[0, 0]], color),
    _shape([[0, 0], [1, 0]], color),
    _shape([[0, 0], [0, 1]], color),
    _shape([[0, 0], [1, -1]], color),
    _shape([[0, 0], [1, 0], [2, 0]], color),
    _shape([[0, 0], [0, 1], [0, 2]], color),
    _shape([[0, 0], [1, -1], [2, -2]], color),
    _shape([[0, 0], [1, 0], [2, 0], [3, 0]], color),
    _shape([[0, 0], [0, 1], [0, 2], [0, 3]], color),
    _shape([[0, 0], [1, 0], [0, 1]], color),
    _shape([[0, 0], [1, 0], [1, 1]], color),
    _shape([[0, 0], [1, 0], [0, 1], [1, 1]], color),
    _shape([[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [0, 2]], color),
    _shape([[0, 0], [1, 0], [0, 1], [-1, 1], [0, -1], [1, -1], [-1, 0]], color),
  ];
}

/// Game state: board contents, tray, score, and the rules for placing.
class WordScore {
  final String word;
  final int points;
  final List<Axial> cells;
  const WordScore(this.word, this.points, this.cells);
}
class HexGame {
  static const int radius = 4;
  final List<Axial> cells = boardCells(radius);
  final List<List<Axial>> lines = boardLines(boardCells(radius));

  /// Board contents: cell -> colour index, or absent when empty.
  final Map<Axial, int> board = {};
  final Map<Axial, String> letters = {};
  List<WordScore> foundWords = [];
  int wordsCreated = 0;
  final Set<String> scoredWordKeys = {};
  List<Piece?> tray = [null, null, null];
  int score = 0;
  int linesCleared = 0;
  bool gameOver = false;
  String? message;

  /// Cells currently playing their clear animation. They stay on the board
  /// (flashing) until [finishClear] removes them, so the UI can celebrate
  /// the clear before the cells disappear.
  Set<Axial> clearingCells = {};
  int clearingPoints = 0;
  int clearingLines = 0;
  bool get isClearing => clearingCells.isNotEmpty;

  final math.Random _random = math.Random();

  HexGame() {
    refillTray();
  }

  void newGame() {
    board.clear();
    letters.clear();
    foundWords = [];
    scoredWordKeys.clear();
    wordsCreated = 0;
    score = 0;
    linesCleared = 0;
    gameOver = false;
    message = null;
    clearingCells = {};
    clearingPoints = 0;
    clearingLines = 0;
    refillTray();
  }

  void refillTray() {
    final pool = allPieces(0);
    for (var i = 0; i < tray.length; i++) {
      Piece shape;
      if (_random.nextDouble() < 0.06) {
        shape = pool.last;
      } else {
        shape = pool[_random.nextInt(pool.length - 1)];
      }
      tray[i] = Piece(shape.cells, _random.nextInt(6), List.generate(shape.cells.length, (_) => _randomLetter()));
    }
    _checkGameOver();
  }

  void rotateTrayPiece(int trayIndex) {
    final piece = tray[trayIndex];
    if (piece == null || isClearing) return;
    tray[trayIndex] = piece.rotate60();
    final remaining = tray.whereType<Piece>().toList();
    if (remaining.isNotEmpty && remaining.every((p) => !fitsAnywhere(p))) {
      gameOver = true;
      message = 'No moves left!';
    } else {
      gameOver = false;
      if (message == 'No moves left!') message = null;
    }
  }
  String _randomLetter() {
    const pool = 'EEEEEEEEEEEEAAAAAAAAAIIIIIIIIOOOOOOOOONNNNNNRRRRRRTTTTTTLLLLSSSSUUUUDDDDGGGBBCCMMPPFFHHVVWWYYKJXQZ';
    return pool[_random.nextInt(pool.length)];
  }
  int _wordPoints(int length) {
    switch (length) {
      case 3: return 30;
      case 4: return 50;
      case 5: return 80;
      case 6: return 120;
      default: return 150;
    }
  }
  List<WordScore> _findWords(List<Axial> newCells) {
    const dirs = [Axial(0, 1), Axial(1, 0), Axial(1, -1)];
    final newSet = newCells.toSet();
    final seenSegments = <String>{};
    final results = <WordScore>[];
    final scoredThisCall = <String>{};
    for (var d = 0; d < dirs.length; d++) {
      final step = dirs[d];
      final back = Axial(-step.q, -step.r);
      for (final newCell in newCells) {
        var start = newCell;
        while (board.containsKey(start + back)) start = start + back;
        if (!seenSegments.add('$d:${start.q},${start.r}')) continue;
        final segCells = <Axial>[];
        var cur = start;
        while (board.containsKey(cur)) { segCells.add(cur); cur = cur + step; }
        if (segCells.length < 3) continue;
        final segStr = segCells.map((c) => letters[c] ?? '').join();
        final views = [(segCells, segStr), (segCells.reversed.toList(), segStr.split('').reversed.join())];
        for (final view in views) {
          final viewCells = view.$1;
          final viewStr = view.$2;
          for (var len = viewStr.length; len >= 3; len--) {
            var found = false;
            for (var i = 0; i + len <= viewStr.length; i++) {
              final subCells = viewCells.sublist(i, i + len);
              if (!subCells.any(newSet.contains)) continue;
              final word = viewStr.substring(i, i + len).toLowerCase();
              if (!englishWords.contains(word)) continue;
              final cellKey = subCells.map((c) => '${c.q},${c.r}').join(';') + ':$word';
              if (scoredThisCall.contains(cellKey)) { found = true; break; }
              final key = '${subCells[i].q},${subCells[i].r}:$d:$len:$word';
              if (scoredWordKeys.contains(key)) continue;
              scoredWordKeys.add(key);
              scoredThisCall.add(cellKey);
              results.add(WordScore(word, _wordPoints(len), subCells));
              found = true;
              break;
            }
            if (found) break;
          }
        }
      }
    }
    return results;
  }
  bool canPlace(Piece piece, Axial anchor) {
    for (final offset in piece.cells) {
      final cell = anchor + offset;
      if (!cells.contains(cell) || board.containsKey(cell)) {
        return false;
      }
    }
    return true;
  }

  bool fitsAnywhere(Piece piece) {
    for (final anchor in cells) {
      if (canPlace(piece, anchor)) return true;
    }
    return false;
  }

  /// Place a tray piece. Returns false if the placement is illegal.
  ///
  /// When a placement completes one or more lines, the cleared cells are
  /// NOT removed immediately: they are kept in [clearingCells] so the UI
  /// can animate them, and the caller must call [finishClear] when the
  /// animation ends. Input should be ignored while [isClearing] is true.
  bool place(int trayIndex, Axial anchor) {
    foundWords = [];
    final piece = tray[trayIndex];
    if (piece == null || gameOver || isClearing || !canPlace(piece, anchor)) {
      return false;
    }
    final placedCells = <Axial>[];
    for (var i = 0; i < piece.cells.length; i++) {
      final cell = anchor + piece.cells[i];
      placedCells.add(cell);
      board[cell] = piece.color;
      letters[cell] = piece.letters.length == piece.cells.length ? piece.letters[i] : '?';
    }
    score += piece.cells.length;
    tray[trayIndex] = null;
    foundWords = _findWords(placedCells);
    for (final word in foundWords) score += word.points;
    wordsCreated += foundWords.length;
    final cleared = <Axial>{};
    var linesHit = 0;
    for (final line in lines) {
      if (line.every(board.containsKey)) {
        linesHit++;
        cleared.addAll(line);
      }
    }
    if (cleared.isNotEmpty) {
      clearingCells = cleared;
      clearingLines = linesHit;
      clearingPoints = 100 * linesHit + (linesHit > 1 ? 50 * (linesHit - 1) : 0);
      score += clearingPoints;
      message = linesHit > 1 ? 'Combo! $linesHit lines!' : 'Line cleared!';
      return true;
    }
    message = null;
    if (tray.every((p) => p == null)) {
      refillTray();
    } else {
      _checkGameOver();
    }
    return true;
  }

  /// End a line-clear animation: remove the flashing cells, count the
  /// lines, then refill the tray / check for game over as usual.
  void finishClear() {
    if (clearingCells.isEmpty) return;
    for (final cell in clearingCells) {
      board.remove(cell);
      letters.remove(cell);
    }
    linesCleared += clearingLines;
    clearingCells = {};
    clearingPoints = 0;
    clearingLines = 0;
    if (tray.every((p) => p == null)) {
      refillTray();
    } else {
      _checkGameOver();
    }
  }

  void _checkGameOver() {
    final remaining = tray.whereType<Piece>().toList();
    if (remaining.isNotEmpty && remaining.every((p) => !fitsAnywhere(p))) {
      gameOver = true;
      message = 'No moves left!';
    }
  }
}

/// Pixel geometry for pointy-top hexes of a given size (centre to vertex).
class HexLayout {
  final double size;
  const HexLayout(this.size);

  /// Centre of a cell, relative to the board centre.
  math.Point<double> toPixel(Axial cell) {
    final x = size * math.sqrt(3) * (cell.q + cell.r / 2);
    final y = size * 1.5 * cell.r;
    return math.Point<double>(x, y);
  }

  /// Nearest cell to a point relative to the board centre.
  Axial fromPixel(math.Point<double> point) {
    final q = (math.sqrt(3) / 3 * point.x - 1 / 3 * point.y) / size;
    final r = (2 / 3 * point.y) / size;
    var rx = q.round();
    var ry = r.round();
    var rz = (-q - r).round();
    final dx = (rx - q).abs();
    final dy = (ry - r).abs();
    final dz = (rz - (-q - r)).abs();
    if (dx > dy && dx > dz) {
      rx = -ry - rz;
    } else if (dy > dz) {
      ry = -rx - rz;
    }
    return Axial(rx, ry);
  }
}
