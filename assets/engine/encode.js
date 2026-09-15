


import {
  FILES, RANKS, NSQUARES, RED, BLACK, other,
  fileOf, rankOf, sq, pieceColor, pieceType, inPalace, NO_PIECE,
} from "./rules.js";
import { NUM_PIECE_PLANES, NUM_CHANNELS } from "./nn.js";

const idx = (f, r, ch) => f + FILES * (r + RANKS * ch);

export function encodeBoard(b, perspective = b.turn) {
  const x = new Float32Array(FILES * RANKS * NUM_CHANNELS);
  const flip = perspective === BLACK;

  for (let s = 0; s < NSQUARES; s++) {
    const p = b.squares[s];
    if (p === NO_PIECE) continue;
    let f = fileOf(s), r = rankOf(s);
    let pc = pieceColor(p);
    if (flip) { f = FILES - 1 - f; r = RANKS - 1 - r; pc = other(pc); }
    const pt = pieceType(p);
    const ch = (pt - 1) + pc * 7;
    x[idx(f, r, ch)] = 1;
  }

  const turnPlane = NUM_PIECE_PLANES;
  for (let f = 0; f < FILES; f++) for (let r = 0; r < RANKS; r++) x[idx(f, r, turnPlane)] = 1;

  const palacePlane = NUM_PIECE_PLANES + 1;
  const homePlane = NUM_PIECE_PLANES + 2;
  for (let f = 0; f < FILES; f++) {
    for (let r = 0; r < RANKS; r++) {
      const s = sq(f, r);
      x[idx(f, r, palacePlane)] = (inPalace(RED, s) || inPalace(BLACK, s)) ? 1 : 0;
      const homeside = flip ? r >= 5 : r <= 4;
      x[idx(f, r, homePlane)] = homeside ? 1 : 0;
    }
  }
  return x;
}


export function encodeMove(from, to, pc) {
  if (pc === RED) return [from, to];
  const flip = (s) => sq(FILES - 1 - fileOf(s), RANKS - 1 - rankOf(s));
  return [flip(from), flip(to)];
}
