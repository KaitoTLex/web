

















import * as Rules from "./rules.js";
import { encodeBoard, encodeMove } from "./encode.js";
import { buildWeights, forward as forwardCPU, qValues, advantage } from "./nn.js";

export { Rules };

async function detectWebGpu() {
  if (typeof navigator === "undefined" || !navigator.gpu) return null;
  try {
    const adapter = await navigator.gpu.requestAdapter();
    if (!adapter) return null;
    const device = await adapter.requestDevice();
    return device;
  } catch {
    return null;
  }
}


export async function createEngine(manifestUrl, binUrl, opts = {}) {
  const weights = await buildWeights(
    await (await fetch(manifestUrl)).json(),
    await (await fetch(binUrl)).arrayBuffer(),
  );

  let gpuBackend = null;
  let backendName = "cpu";
  if (!opts.forceCpu) {
    const device = await detectWebGpu();
    if (device) {
      try {
        const { createGpuBackend } = await import("./webgpu.js");
        const shaderSource = await (await fetch(opts.wgslUrl ?? new URL("./wgsl/ops.wgsl", import.meta.url))).text();
        gpuBackend = await createGpuBackend(device, shaderSource);
        backendName = "webgpu";
      } catch (e) {
        console.warn("tinyfih: WebGPU backend failed to initialize, falling back to CPU", e);
        gpuBackend = null;
      }
    }
  }

  async function rawForward(x) {
    if (gpuBackend) {
      const { forwardGPU } = await import("./webgpu.js");
      return forwardGPU(gpuBackend, weights, x);
    }
    return forwardCPU(weights, x);
  }

  return {
    backend: backendName,
    weights,


    async evaluate(board, legalMoves) {
      if (legalMoves.length === 0) {
        return { value: -1, moves: [] };
      }
      const x = encodeBoard(board, board.turn);
      const pairs = legalMoves.map(([from, to]) => encodeMove(from, to, board.turn));
      const out = await rawForward(x);
      const qs = qValues(out, pairs);
      const moves = legalMoves
        .map(([from, to], i) => ({ from, to, q: qs[i] }))
        .sort((a, b) => b.q - a.q);
      return { value: out.v, moves };
    },


    async bestMove(board, legalMoves) {
      const { moves } = await this.evaluate(board, legalMoves);
      return moves.length > 0 ? moves[0] : null;
    },
  };
}
