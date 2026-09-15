












export const FILES = 9;
export const RANKS = 10;
export const NSQUARES = FILES * RANKS;

export const RED = 0;
export const BLACK = 1;
export const other = (c) => 1 - c;


export const NO_PIECE_TYPE = 0;
export const ROOK = 1;
export const ADVISOR = 2;
export const CANNON = 3;
export const PAWN = 4;
export const KNIGHT = 5;
export const BISHOP = 6;
export const KING = 7;

export const NO_PIECE = 0;
export const piece = (color, pt) => pt + color * 8;
export const pieceType = (p) => p & 7;
export const pieceColor = (p) => (p >> 3) & 1;

export const sq = (file, rank) => rank * FILES + file;
export const fileOf = (s) => s % FILES;
export const rankOf = (s) => Math.floor(s / FILES);
export const onBoard = (f, r) => f >= 0 && f < FILES && r >= 0 && r < RANKS;

export function inPalace(color, s) {
  const f = fileOf(s), r = rankOf(s);
  if (f < 3 || f > 5) return false;
  return color === RED ? r >= 0 && r <= 2 : r >= 7 && r <= 9;
}
export const ownSide = (color, r) => (color === RED ? r <= 4 : r >= 5);

export function squareName(s) {
  return String.fromCharCode(97 + fileOf(s)) + rankOf(s);
}

const ORTHO_DIRS = [[0, 1], [0, -1], [1, 0], [-1, 0]];
const DIAG_DIRS = [[1, 1], [1, -1], [-1, 1], [-1, -1]];
const KNIGHT_OFFSETS = [[1, 2], [1, -2], [-1, 2], [-1, -2], [2, 1], [2, -1], [-2, 1], [-2, -1]];

export class Board {
  constructor() {
    this.squares = new Int8Array(NSQUARES);
    this.turn = RED;
    this.kingSq = [-1, -1];
    this.halfmove = 0;
    this.fullmove = 1;
    this.history = [];
  }

  clone() {
    const b = new Board();
    b.squares = this.squares.slice();
    b.turn = this.turn;
    b.kingSq = this.kingSq.slice();
    b.halfmove = this.halfmove;
    b.fullmove = this.fullmove;
    b.history = this.history.slice();
    return b;
  }
}

const FEN_CHAR_TO_PT = { r: ROOK, n: KNIGHT, b: BISHOP, a: ADVISOR, k: KING, c: CANNON, p: PAWN };
const PT_TO_FEN_CHAR = { [ROOK]: "r", [KNIGHT]: "n", [BISHOP]: "b", [ADVISOR]: "a", [KING]: "k", [CANNON]: "c", [PAWN]: "p" };

export const START_FEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1";

export function setFen(board, fen) {
  board.squares.fill(NO_PIECE);
  board.history = [];
  board.kingSq = [-1, -1];
  const parts = fen.trim().split(/\s+/);
  const ranks = parts[0].split("/");
  if (ranks.length !== RANKS) throw new Error(`FEN must have ${RANKS} ranks, got ${ranks.length}`);
  for (let i = 0; i < ranks.length; i++) {
    const r = RANKS - 1 - i;
    let f = 0;
    for (const ch of ranks[i]) {
      if (ch >= "0" && ch <= "9") {
        f += Number(ch);
      } else {
        const color = ch === ch.toUpperCase() ? RED : BLACK;
        const pt = FEN_CHAR_TO_PT[ch.toLowerCase()];
        const s = sq(f, r);
        board.squares[s] = piece(color, pt);
        if (pt === KING) board.kingSq[color] = s;
        f += 1;
      }
    }
  }
  board.turn = parts[1] === "b" ? BLACK : RED;
  board.halfmove = parts.length >= 5 ? Number(parts[4]) : 0;
  board.fullmove = parts.length >= 6 ? Number(parts[5]) : 1;
  return board;
}

export function toFen(board) {
  const rows = [];
  for (let i = 0; i < RANKS; i++) {
    const r = RANKS - 1 - i;
    let row = "", empties = 0;
    for (let f = 0; f < FILES; f++) {
      const p = board.squares[sq(f, r)];
      if (p === NO_PIECE) {
        empties += 1;
      } else {
        if (empties > 0) { row += empties; empties = 0; }
        const ch = PT_TO_FEN_CHAR[pieceType(p)];
        row += pieceColor(p) === RED ? ch.toUpperCase() : ch;
      }
    }
    if (empties > 0) row += empties;
    rows.push(row);
  }
  const side = board.turn === RED ? "w" : "b";
  return `${rows.join("/")} ${side} - - ${board.halfmove} ${board.fullmove}`;
}

export function startpos() {
  return setFen(new Board(), START_FEN);
}



function rookTargets(b, s) {
  const targets = [];
  const f0 = fileOf(s), r0 = rankOf(s);
  const mycolor = pieceColor(b.squares[s]);
  for (const [df, dr] of ORTHO_DIRS) {
    let f = f0 + df, r = r0 + dr;
    while (onBoard(f, r)) {
      const t = sq(f, r);
      const p = b.squares[t];
      if (p === NO_PIECE) {
        targets.push(t);
      } else {
        if (pieceColor(p) !== mycolor) targets.push(t);
        break;
      }
      f += df; r += dr;
    }
  }
  return targets;
}

function cannonTargets(b, s) {
  const targets = [];
  const f0 = fileOf(s), r0 = rankOf(s);
  const mycolor = pieceColor(b.squares[s]);
  for (const [df, dr] of ORTHO_DIRS) {
    let f = f0 + df, r = r0 + dr;
    let screen = false;
    while (onBoard(f, r)) {
      const t = sq(f, r);
      const p = b.squares[t];
      if (!screen) {
        if (p === NO_PIECE) targets.push(t);
        else screen = true;
      } else if (p !== NO_PIECE) {
        if (pieceColor(p) !== mycolor) targets.push(t);
        break;
      }
      f += df; r += dr;
    }
  }
  return targets;
}

function knightTargets(b, s) {
  const targets = [];
  const f0 = fileOf(s), r0 = rankOf(s);
  const mycolor = pieceColor(b.squares[s]);
  for (const [df, dr] of KNIGHT_OFFSETS) {
    const f = f0 + df, r = r0 + dr;
    if (!onBoard(f, r)) continue;
    const legf = Math.abs(df) === 2 ? f0 + (df / 2) : f0;
    const legr = Math.abs(df) === 2 ? r0 : r0 + (dr / 2);
    if (b.squares[sq(legf, legr)] !== NO_PIECE) continue;
    const t = sq(f, r);
    const p = b.squares[t];
    if (p === NO_PIECE || pieceColor(p) !== mycolor) targets.push(t);
  }
  return targets;
}

function bishopTargets(b, s) {
  const targets = [];
  const f0 = fileOf(s), r0 = rankOf(s);
  const mycolor = pieceColor(b.squares[s]);
  for (const [df, dr] of DIAG_DIRS) {
    const f = f0 + 2 * df, r = r0 + 2 * dr;
    if (!onBoard(f, r)) continue;
    if (!ownSide(mycolor, r)) continue;
    if (b.squares[sq(f0 + df, r0 + dr)] !== NO_PIECE) continue;
    const t = sq(f, r);
    const p = b.squares[t];
    if (p === NO_PIECE || pieceColor(p) !== mycolor) targets.push(t);
  }
  return targets;
}

function advisorTargets(b, s) {
  const targets = [];
  const f0 = fileOf(s), r0 = rankOf(s);
  const mycolor = pieceColor(b.squares[s]);
  for (const [df, dr] of DIAG_DIRS) {
    const f = f0 + df, r = r0 + dr;
    if (!onBoard(f, r)) continue;
    const t = sq(f, r);
    if (!inPalace(mycolor, t)) continue;
    const p = b.squares[t];
    if (p === NO_PIECE || pieceColor(p) !== mycolor) targets.push(t);
  }
  return targets;
}

function kingTargets(b, s) {
  const targets = [];
  const f0 = fileOf(s), r0 = rankOf(s);
  const mycolor = pieceColor(b.squares[s]);
  for (const [df, dr] of ORTHO_DIRS) {
    const f = f0 + df, r = r0 + dr;
    if (!onBoard(f, r)) continue;
    const t = sq(f, r);
    if (!inPalace(mycolor, t)) continue;
    const p = b.squares[t];
    if (p === NO_PIECE || pieceColor(p) !== mycolor) targets.push(t);
  }
  return targets;
}

function pawnTargets(b, s) {
  const targets = [];
  const f0 = fileOf(s), r0 = rankOf(s);
  const mycolor = pieceColor(b.squares[s]);
  const fwd = mycolor === RED ? 1 : -1;
  const offsets = ownSide(mycolor, r0) ? [[0, fwd]] : [[0, fwd], [1, 0], [-1, 0]];
  for (const [df, dr] of offsets) {
    const f = f0 + df, r = r0 + dr;
    if (!onBoard(f, r)) continue;
    const t = sq(f, r);
    const p = b.squares[t];
    if (p === NO_PIECE || pieceColor(p) !== mycolor) targets.push(t);
  }
  return targets;
}

function pieceTargets(b, s) {
  switch (pieceType(b.squares[s])) {
    case ROOK: return rookTargets(b, s);
    case CANNON: return cannonTargets(b, s);
    case KNIGHT: return knightTargets(b, s);
    case BISHOP: return bishopTargets(b, s);
    case ADVISOR: return advisorTargets(b, s);
    case KING: return kingTargets(b, s);
    case PAWN: return pawnTargets(b, s);
    default: return [];
  }
}


export function isSquareAttacked(b, s, by) {
  const f0 = fileOf(s), r0 = rankOf(s);

  for (const [df, dr] of ORTHO_DIRS) {
    let f = f0 + df, r = r0 + dr, dist = 0, screenPiece = NO_PIECE;
    while (onBoard(f, r)) {
      dist += 1;
      const p = b.squares[sq(f, r)];
      if (p !== NO_PIECE) {
        if (screenPiece === NO_PIECE) {
          if (pieceColor(p) === by) {
            const pt = pieceType(p);
            if (pt === ROOK) return true;
            if (pt === KING && dist === 1 && inPalace(by, s)) return true;
          }
          screenPiece = p;
        } else {
          if (pieceColor(p) === by && pieceType(p) === CANNON) return true;
          break;
        }
      }
      f += df; r += dr;
    }
  }

  for (const [df, dr] of KNIGHT_OFFSETS) {
    const f = f0 - df, r = r0 - dr;
    if (!onBoard(f, r)) continue;
    const p = b.squares[sq(f, r)];
    if (p === NO_PIECE || pieceColor(p) !== by || pieceType(p) !== KNIGHT) continue;
    const legf = Math.abs(df) === 2 ? f + (df / 2) : f;
    const legr = Math.abs(df) === 2 ? r : r + (dr / 2);
    if (b.squares[sq(legf, legr)] === NO_PIECE) return true;
  }

  for (const [df, dr] of DIAG_DIRS) {
    const f = f0 - 2 * df, r = r0 - 2 * dr;
    if (!onBoard(f, r)) continue;
    if (!ownSide(by, r0)) continue;
    const p = b.squares[sq(f, r)];
    if (p === NO_PIECE || pieceColor(p) !== by || pieceType(p) !== BISHOP) continue;
    if (b.squares[sq(f + df, r + dr)] === NO_PIECE) return true;
  }

  for (const [df, dr] of DIAG_DIRS) {
    const f = f0 - df, r = r0 - dr;
    if (!onBoard(f, r)) continue;
    if (!inPalace(by, s)) continue;
    const p = b.squares[sq(f, r)];
    if (p !== NO_PIECE && pieceColor(p) === by && pieceType(p) === ADVISOR) return true;
  }

  const fwd = by === RED ? 1 : -1;
  if (onBoard(f0, r0 - fwd)) {
    const p = b.squares[sq(f0, r0 - fwd)];
    if (p !== NO_PIECE && pieceColor(p) === by && pieceType(p) === PAWN) return true;
  }
  for (const df of [-1, 1]) {
    if (!onBoard(f0 + df, r0)) continue;
    const p = b.squares[sq(f0 + df, r0)];
    if (p === NO_PIECE || pieceColor(p) !== by || pieceType(p) !== PAWN) continue;
    if (ownSide(by, r0)) continue;
    return true;
  }

  const ks = b.kingSq[by];
  if (ks !== -1 && ks !== s && fileOf(ks) === f0) {
    const lo = Math.min(rankOf(ks), r0), hi = Math.max(rankOf(ks), r0);
    let clear = true;
    for (let r = lo + 1; r < hi; r++) {
      if (b.squares[sq(f0, r)] !== NO_PIECE) { clear = false; break; }
    }
    if (clear) return true;
  }
  return false;
}

export const inCheck = (b, c) => isSquareAttacked(b, b.kingSq[c], other(c));

export function doMove(b, from, to) {
  const p = b.squares[from];
  const captured = b.squares[to];
  b.squares[to] = p;
  b.squares[from] = NO_PIECE;
  if (pieceType(p) === KING) b.kingSq[pieceColor(p)] = to;
  b.history.push({ from, to, moved: p, captured });
  b.turn = other(b.turn);
  if (captured !== NO_PIECE) b.halfmove = 0;
  if (b.turn === RED) b.fullmove += 1;
  return captured;
}

export function undoMove(b) {
  const { from, to, moved, captured } = b.history.pop();
  b.squares[from] = moved;
  b.squares[to] = captured;
  if (pieceType(moved) === KING) b.kingSq[pieceColor(moved)] = from;
  if (b.turn === RED) b.fullmove -= 1;
  b.turn = other(b.turn);
}

export function generatePseudoMoves(b) {
  const moves = [];
  for (let s = 0; s < NSQUARES; s++) {
    const p = b.squares[s];
    if (p === NO_PIECE || pieceColor(p) !== b.turn) continue;
    for (const t of pieceTargets(b, s)) moves.push([s, t]);
  }
  return moves;
}

export function generateLegalMoves(b) {
  const mover = b.turn;
  const legal = [];
  for (const [from, to] of generatePseudoMoves(b)) {
    doMove(b, from, to);
    if (!inCheck(b, mover)) legal.push([from, to]);
    undoMove(b);
  }
  return legal;
}

export function isGameOver(b) {
  return generateLegalMoves(b).length === 0;
}

export function perft(b, depth) {
  if (depth <= 0) return 1;
  const moves = generateLegalMoves(b);
  if (depth === 1) return moves.length;
  let total = 0;
  for (const [from, to] of moves) {
    doMove(b, from, to);
    total += perft(b, depth - 1);
    undoMove(b);
  }
  return total;
}

export function moveString(from, to) {
  return squareName(from) + squareName(to);
}
