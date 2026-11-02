import 'dart:math' as math;

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
  const Piece(this.cells, this.color);
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
class HexGame {
  static const int radius = 4;
  final List<Axial> cells = boardCells(radius);
  final List<List<Axial>> lines = boardLines(boardCells(radius));

  /// Board contents: cell -> colour index, or absent when empty.
  final Map<Axial, int> board = {};
  List<Piece?> tray = [null, null, null];
  int score = 0;
  int linesCleared = 0;
  bool gameOver = false;
  String? message;

  final math.Random _random = math.Random();

  HexGame() {
    refillTray();
  }

  void newGame() {
    board.clear();
    score = 0;
    linesCleared = 0;
    gameOver = false;
    message = null;
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
      tray[i] = Piece(shape.cells, _random.nextInt(6));
    }
    _checkGameOver();
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
  bool place(int trayIndex, Axial anchor) {
    final piece = tray[trayIndex];
    if (piece == null || gameOver || !canPlace(piece, anchor)) {
      return false;
    }
    for (final offset in piece.cells) {
      board[anchor + offset] = piece.color;
    }
    score += piece.cells.length;
    tray[trayIndex] = null;
    final cleared = <Axial>{};
    var linesHit = 0;
    for (final line in lines) {
      if (line.every(board.containsKey)) {
        linesHit++;
        cleared.addAll(line);
      }
    }
    if (cleared.isNotEmpty) {
      for (final cell in cleared) {
        board.remove(cell);
      }
      linesCleared += linesHit;
      score += 100 * linesHit + (linesHit > 1 ? 50 * (linesHit - 1) : 0);
      message = linesHit > 1 ? 'Combo! $linesHit lines!' : 'Line cleared!';
    } else {
      message = null;
    }
    if (tray.every((p) => p == null)) {
      refillTray();
    } else {
      _checkGameOver();
    }
    return true;
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
