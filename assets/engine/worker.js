import { createEngine, Rules } from "./tinyfih.js";

let engine = null;
let enginePromise = null;

async function loadEngine() {
  if (engine) return engine;

  if (!enginePromise) {
    enginePromise = createEngine(
      new URL("./model/tinyfih_final.json", import.meta.url),
      new URL("./model/tinyfih_final.bin", import.meta.url),
    ).catch((error) => {
      enginePromise = null;
      throw error;
    });
  }

  engine = await enginePromise;
  return engine;
}

self.addEventListener("message", async ({ data }) => {
  try {
    if (data.type === "load") {
      const loadedEngine = await loadEngine();
      self.postMessage({ type: "loaded", backend: loadedEngine.backend });
      return;
    }

    if (data.type === "move") {
      const loadedEngine = await loadEngine();
      const board = Rules.setFen(new Rules.Board(), data.payload.fen);
      const legalMoves = data.payload.legalMoves.map(({ from, to }) => [from, to]);
      const best = await loadedEngine.bestMove(board, legalMoves);

      if (!best) {
        self.postMessage({
          type: "error",
          requestId: data.payload.requestId,
          message: "no legal moves (game over)",
        });
      } else {
        self.postMessage({
          type: "move",
          requestId: data.payload.requestId,
          from: best.from,
          to: best.to,
          value: best.q,
        });
      }
    }
  } catch (error) {
    self.postMessage({
      type: "error",
      requestId: data.payload?.requestId,
      message: String(error),
    });
  }
});
