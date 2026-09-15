











import { FILES, RANKS, NSQUARES } from "./rules.js";

export const NUM_PIECE_PLANES = 14;
export const NUM_EXTRA_PLANES = 3;
export const NUM_CHANNELS = NUM_PIECE_PLANES + NUM_EXTRA_PLANES;



export async function loadWeights(manifestUrl, binUrl) {
  const manifest = await (await fetch(manifestUrl)).json();
  const binBuf = await (await fetch(binUrl)).arrayBuffer();
  return buildWeights(manifest, binBuf);
}


export function buildWeights(manifest, binArrayBuffer) {
  const byName = {};
  for (const l of manifest.layers) {
    byName[l.name] = new Float32Array(binArrayBuffer, l.byte_offset, l.length);
  }
  return { manifest, tensors: byName };
}

function W(weights, name) {
  const t = weights.tensors[name];
  if (!t) throw new Error(`missing weight tensor: ${name}`);
  return t;
}






const actIdx = (f, r, ch) => f + FILES * (r + RANKS * ch);


function widxConv(kw, kh, ci, co, kW, kH, Cin) {
  return kw + kW * (kh + kH * (ci + Cin * co));
}

function widxDense(o, i, Out) {
  return o + Out * i;
}

function relu(x) {
  for (let i = 0; i < x.length; i++) if (x[i] < 0) x[i] = 0;
  return x;
}


export function conv2d(input, Cin, Cout, kW, kH, pad, weight, bias) {
  const out = new Float32Array(FILES * RANKS * Cout);
  for (let co = 0; co < Cout; co++) {
    const b = bias[co];
    for (let r = 0; r < RANKS; r++) {
      for (let f = 0; f < FILES; f++) {
        let acc = b;
        for (let ci = 0; ci < Cin; ci++) {
          for (let kh = 0; kh < kH; kh++) {
            const ir = r + pad - kh;
            if (ir < 0 || ir >= RANKS) continue;
            for (let kw = 0; kw < kW; kw++) {
              const iff = f + pad - kw;
              if (iff < 0 || iff >= FILES) continue;
              acc += input[actIdx(iff, ir, ci)] * weight[widxConv(kw, kh, ci, co, kW, kH, Cin)];
            }
          }
        }
        out[actIdx(f, r, co)] = acc;
      }
    }
  }
  return out;
}

function conv1x1(input, Cin, Cout, weight, bias) {
  return conv2d(input, Cin, Cout, 1, 1, 0, weight, bias);
}

function dense(input, In, Out, weight, bias) {
  const out = new Float32Array(Out);
  for (let o = 0; o < Out; o++) {
    let acc = bias[o];
    for (let i = 0; i < In; i++) acc += input[i] * weight[widxDense(o, i, Out)];
    out[o] = acc;
  }
  return out;
}

function resBlock(x, channels, weights, prefix) {
  const w1 = W(weights, `${prefix}.conv1.weight`), b1 = W(weights, `${prefix}.conv1.bias`);
  const w2 = W(weights, `${prefix}.conv2.weight`), b2 = W(weights, `${prefix}.conv2.bias`);
  let h = relu(conv2d(x, channels, channels, 3, 3, 1, w1, b1));
  h = conv2d(h, channels, channels, 3, 3, 1, w2, b2);
  const out = new Float32Array(h.length);
  for (let i = 0; i < h.length; i++) out[i] = Math.max(0, h[i] + x[i]);
  return out;
}


export function forward(weights, x) {
  const m = weights.manifest;
  const channels = m.channels, embDim = m.emb_dim, blocks = m.num_blocks;

  let feat = relu(conv2d(x, m.num_input_channels, channels, 3, 3, 1, W(weights, "stem.weight"), W(weights, "stem.bias")));
  for (let i = 1; i <= blocks; i++) feat = resBlock(feat, channels, weights, `block${i}`);


  const vConv = relu(conv1x1(feat, channels, 8, W(weights, "value.conv.weight"), W(weights, "value.conv.bias")));



  const h1 = relu(dense(vConv, 8 * NSQUARES, 32, W(weights, "value.fc1.weight"), W(weights, "value.fc1.bias")));
  const h2 = dense(h1, 32, 1, W(weights, "value.fc2.weight"), W(weights, "value.fc2.bias"));
  const v = Math.tanh(h2[0]);

  const fembRaw = conv1x1(feat, channels, embDim, W(weights, "from.weight"), W(weights, "from.bias"));
  const tembRaw = conv1x1(feat, channels, embDim, W(weights, "to.weight"), W(weights, "to.bias"));
  const fbiasRaw = conv1x1(feat, channels, 1, W(weights, "from_bias.weight"), W(weights, "from_bias.bias"));
  const tbiasRaw = conv1x1(feat, channels, 1, W(weights, "to_bias.weight"), W(weights, "to_bias.bias"));


  const femb = new Float32Array(NSQUARES * embDim);
  const temb = new Float32Array(NSQUARES * embDim);
  const fbias = new Float32Array(NSQUARES);
  const tbias = new Float32Array(NSQUARES);
  for (let r = 0; r < RANKS; r++) {
    for (let f = 0; f < FILES; f++) {
      const s = r * FILES + f;
      fbias[s] = fbiasRaw[actIdx(f, r, 0)];
      tbias[s] = tbiasRaw[actIdx(f, r, 0)];
      for (let k = 0; k < embDim; k++) {
        femb[s * embDim + k] = fembRaw[actIdx(f, r, k)];
        temb[s * embDim + k] = tembRaw[actIdx(f, r, k)];
      }
    }
  }

  return { v, femb, temb, fbias, tbias, embDim };
}

export function advantage(out, from, to) {
  let a = 0;
  const { femb, temb, embDim } = out;
  for (let k = 0; k < embDim; k++) a += femb[from * embDim + k] * temb[to * embDim + k];
  return a + out.fbias[from] + out.tbias[to];
}


export function qValues(out, pairs) {
  const adv = new Float32Array(pairs.length);
  let sum = 0;
  for (let i = 0; i < pairs.length; i++) {
    adv[i] = advantage(out, pairs[i][0], pairs[i][1]);
    sum += adv[i];
  }
  const base = sum / pairs.length;
  const q = new Float32Array(pairs.length);
  for (let i = 0; i < pairs.length; i++) q[i] = out.v + adv[i] - base;
  return q;
}
