









import { FILES, RANKS, NSQUARES } from "./rules.js";

function u32Array(...vals) {
  return new Uint32Array(vals);
}

function makeBuffer(device, data, usage) {
  const buf = device.createBuffer({
    size: Math.ceil(data.byteLength / 4) * 4,
    usage,
    mappedAtCreation: true,
  });
  new Uint8Array(buf.getMappedRange()).set(new Uint8Array(data.buffer ?? data, data.byteOffset ?? 0, data.byteLength));
  buf.unmap();
  return buf;
}

function storageBuffer(device, floatArray, extraUsage = 0) {
  return makeBuffer(device, floatArray, GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST | extraUsage);
}
function uniformBuffer(device, u32arr) {
  return makeBuffer(device, u32arr, GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST);
}
function emptyStorageBuffer(device, floatCount) {
  return device.createBuffer({
    size: floatCount * 4,
    usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST,
  });
}

export async function createGpuBackend(device, shaderSource) {
  const module = device.createShaderModule({ code: shaderSource });
  const convPipeline = device.createComputePipeline({ layout: "auto", compute: { module, entryPoint: "conv2d_main" } });
  const addReluPipeline = device.createComputePipeline({ layout: "auto", compute: { module, entryPoint: "add_relu_main" } });
  const densePipeline = device.createComputePipeline({ layout: "auto", compute: { module, entryPoint: "dense_main" } });

  function dispatchConv(inputBuf, cin, cout, kw, kh, pad, weightBuf, biasBuf, applyRelu) {
    const outBuf = emptyStorageBuffer(device, FILES * RANKS * cout);
    const dims = uniformBuffer(device, u32Array(FILES, RANKS, cin, cout, kw, kh, pad, applyRelu ? 1 : 0));
    const bindGroup = device.createBindGroup({
      layout: convPipeline.getBindGroupLayout(0),
      entries: [
        { binding: 0, resource: { buffer: inputBuf } },
        { binding: 1, resource: { buffer: weightBuf } },
        { binding: 2, resource: { buffer: biasBuf } },
        { binding: 3, resource: { buffer: outBuf } },
        { binding: 4, resource: { buffer: dims } },
      ],
    });
    const encoder = device.createCommandEncoder();
    const pass = encoder.beginComputePass();
    pass.setPipeline(convPipeline);
    pass.setBindGroup(0, bindGroup);
    pass.dispatchWorkgroups(Math.ceil((FILES * RANKS * cout) / 64));
    pass.end();
    device.queue.submit([encoder.finish()]);
    return outBuf;
  }

  function dispatchAddRelu(aBuf, bBuf, n) {
    const outBuf = emptyStorageBuffer(device, n);
    const dims = uniformBuffer(device, u32Array(n));
    const bindGroup = device.createBindGroup({
      layout: addReluPipeline.getBindGroupLayout(0),
      entries: [
        { binding: 0, resource: { buffer: aBuf } },
        { binding: 1, resource: { buffer: bBuf } },
        { binding: 2, resource: { buffer: outBuf } },
        { binding: 3, resource: { buffer: dims } },
      ],
    });
    const encoder = device.createCommandEncoder();
    const pass = encoder.beginComputePass();
    pass.setPipeline(addReluPipeline);
    pass.setBindGroup(0, bindGroup);
    pass.dispatchWorkgroups(Math.ceil(n / 64));
    pass.end();
    device.queue.submit([encoder.finish()]);
    return outBuf;
  }

  function dispatchDense(inputBuf, inN, outN, weightBuf, biasBuf, applyRelu) {
    const outBuf = emptyStorageBuffer(device, outN);
    const dims = uniformBuffer(device, u32Array(inN, outN, applyRelu ? 1 : 0));
    const bindGroup = device.createBindGroup({
      layout: densePipeline.getBindGroupLayout(0),
      entries: [
        { binding: 0, resource: { buffer: inputBuf } },
        { binding: 1, resource: { buffer: weightBuf } },
        { binding: 2, resource: { buffer: biasBuf } },
        { binding: 3, resource: { buffer: outBuf } },
        { binding: 4, resource: { buffer: dims } },
      ],
    });
    const encoder = device.createCommandEncoder();
    const pass = encoder.beginComputePass();
    pass.setPipeline(densePipeline);
    pass.setBindGroup(0, bindGroup);
    pass.dispatchWorkgroups(Math.ceil(outN / 64));
    pass.end();
    device.queue.submit([encoder.finish()]);
    return outBuf;
  }

  async function readBuffer(buf, floatCount) {
    const staging = device.createBuffer({ size: floatCount * 4, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
    const encoder = device.createCommandEncoder();
    encoder.copyBufferToBuffer(buf, 0, staging, 0, floatCount * 4);
    device.queue.submit([encoder.finish()]);
    await staging.mapAsync(GPUMapMode.READ);
    const out = new Float32Array(staging.getMappedRange().slice(0, floatCount * 4));
    staging.unmap();
    return out;
  }

  return { device, dispatchConv, dispatchAddRelu, dispatchDense, readBuffer };
}


export async function forwardGPU(backend, weights, x) {
  const m = weights.manifest;
  const channels = m.channels, embDim = m.emb_dim, blocks = m.num_blocks;
  const T = weights.tensors;
  const { device, dispatchConv, dispatchAddRelu, dispatchDense, readBuffer } = backend;

  const bufFor = (arr) => storageBuffer(device, arr);
  const inputBuf = bufFor(x);

  let feat = dispatchConv(inputBuf, m.num_input_channels, channels, 3, 3, 1, bufFor(T["stem.weight"]), bufFor(T["stem.bias"]), true);

  for (let i = 1; i <= blocks; i++) {
    const p = `block${i}`;
    const h1 = dispatchConv(feat, channels, channels, 3, 3, 1, bufFor(T[`${p}.conv1.weight`]), bufFor(T[`${p}.conv1.bias`]), true);
    const h2 = dispatchConv(h1, channels, channels, 3, 3, 1, bufFor(T[`${p}.conv2.weight`]), bufFor(T[`${p}.conv2.bias`]), false);
    feat = dispatchAddRelu(h2, feat, FILES * RANKS * channels);
  }

  const vConv = dispatchConv(feat, channels, 8, 1, 1, 0, bufFor(T["value.conv.weight"]), bufFor(T["value.conv.bias"]), true);
  const h1 = dispatchDense(vConv, 8 * NSQUARES, 32, bufFor(T["value.fc1.weight"]), bufFor(T["value.fc1.bias"]), true);
  const h2 = dispatchDense(h1, 32, 1, bufFor(T["value.fc2.weight"]), bufFor(T["value.fc2.bias"]), false);

  const fembRaw = dispatchConv(feat, channels, embDim, 1, 1, 0, bufFor(T["from.weight"]), bufFor(T["from.bias"]), false);
  const tembRaw = dispatchConv(feat, channels, embDim, 1, 1, 0, bufFor(T["to.weight"]), bufFor(T["to.bias"]), false);
  const fbiasRaw = dispatchConv(feat, channels, 1, 1, 1, 0, bufFor(T["from_bias.weight"]), bufFor(T["from_bias.bias"]), false);
  const tbiasRaw = dispatchConv(feat, channels, 1, 1, 1, 0, bufFor(T["to_bias.weight"]), bufFor(T["to_bias.bias"]), false);

  const [vRaw, fembFlat, tembFlat, fbiasFlat, tbiasFlat] = await Promise.all([
    readBuffer(h2, 1),
    readBuffer(fembRaw, FILES * RANKS * embDim),
    readBuffer(tembRaw, FILES * RANKS * embDim),
    readBuffer(fbiasRaw, FILES * RANKS),
    readBuffer(tbiasRaw, FILES * RANKS),
  ]);

  const actIdx = (f, r, ch) => f + FILES * (r + RANKS * ch);
  const femb = new Float32Array(NSQUARES * embDim);
  const temb = new Float32Array(NSQUARES * embDim);
  const fbias = new Float32Array(NSQUARES);
  const tbias = new Float32Array(NSQUARES);
  for (let r = 0; r < RANKS; r++) {
    for (let f = 0; f < FILES; f++) {
      const s = r * FILES + f;
      fbias[s] = fbiasFlat[actIdx(f, r, 0)];
      tbias[s] = tbiasFlat[actIdx(f, r, 0)];
      for (let k = 0; k < embDim; k++) {
        femb[s * embDim + k] = fembFlat[actIdx(f, r, k)];
        temb[s * embDim + k] = tembFlat[actIdx(f, r, k)];
      }
    }
  }

  return { v: Math.tanh(vRaw[0]), femb, temb, fbias, tbias, embDim };
}
