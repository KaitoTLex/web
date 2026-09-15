















struct ConvDims {
  files: u32,
  ranks: u32,
  cin: u32,
  cout: u32,
  kw: u32,
  kh: u32,
  pad: u32,
  apply_relu: u32,
};

@group(0) @binding(0) var<storage, read> conv_input: array<f32>;
@group(0) @binding(1) var<storage, read> conv_weight: array<f32>;
@group(0) @binding(2) var<storage, read> conv_bias: array<f32>;
@group(0) @binding(3) var<storage, read_write> conv_output: array<f32>;
@group(0) @binding(4) var<uniform> conv_dims: ConvDims;

fn act_idx(f: u32, r: u32, ch: u32, files: u32, ranks: u32) -> u32 {
  return f + files * (r + ranks * ch);
}
fn w_idx(kw: u32, kh: u32, ci: u32, co: u32, kW: u32, kH: u32, cin: u32) -> u32 {
  return kw + kW * (kh + kH * (ci + cin * co));
}

@compute @workgroup_size(64)
fn conv2d_main(@builtin(global_invocation_id) gid: vec3<u32>) {
  let files = conv_dims.files;
  let ranks = conv_dims.ranks;
  let cout = conv_dims.cout;
  let total = files * ranks * cout;
  let idx = gid.x;
  if (idx >= total) { return; }

  let co = idx / (files * ranks);
  let rem = idx % (files * ranks);
  let r = rem / files;
  let f = rem % files;

  let cin = conv_dims.cin;
  let kW = conv_dims.kw;
  let kH = conv_dims.kh;
  let pad = conv_dims.pad;

  var acc: f32 = conv_bias[co];
  for (var ci: u32 = 0u; ci < cin; ci = ci + 1u) {
    for (var kh: u32 = 0u; kh < kH; kh = kh + 1u) {
      let ir = i32(r) + i32(pad) - i32(kh);
      if (ir < 0 || ir >= i32(ranks)) { continue; }
      for (var kw: u32 = 0u; kw < kW; kw = kw + 1u) {
        let ifi = i32(f) + i32(pad) - i32(kw);
        if (ifi < 0 || ifi >= i32(files)) { continue; }
        acc = acc + conv_input[act_idx(u32(ifi), u32(ir), ci, files, ranks)]
                   * conv_weight[w_idx(kw, kh, ci, co, kW, kH, cin)];
      }
    }
  }
  if (conv_dims.apply_relu == 1u) {
    acc = max(acc, 0.0);
  }
  conv_output[act_idx(f, r, co, files, ranks)] = acc;
}

struct AddReluDims { n: u32 };

@group(0) @binding(0) var<storage, read> ar_a: array<f32>;
@group(0) @binding(1) var<storage, read> ar_b: array<f32>;
@group(0) @binding(2) var<storage, read_write> ar_out: array<f32>;
@group(0) @binding(3) var<uniform> ar_dims: AddReluDims;

@compute @workgroup_size(64)
fn add_relu_main(@builtin(global_invocation_id) gid: vec3<u32>) {
  let idx = gid.x;
  if (idx >= ar_dims.n) { return; }
  ar_out[idx] = max(ar_a[idx] + ar_b[idx], 0.0);
}

struct DenseDims { inn: u32, outn: u32, apply_relu: u32 };

@group(0) @binding(0) var<storage, read> d_input: array<f32>;
@group(0) @binding(1) var<storage, read> d_weight: array<f32>;
@group(0) @binding(2) var<storage, read> d_bias: array<f32>;
@group(0) @binding(3) var<storage, read_write> d_output: array<f32>;
@group(0) @binding(4) var<uniform> d_dims: DenseDims;

@compute @workgroup_size(64)
fn dense_main(@builtin(global_invocation_id) gid: vec3<u32>) {
  let o = gid.x;
  if (o >= d_dims.outn) { return; }
  var acc: f32 = d_bias[o];
  for (var i: u32 = 0u; i < d_dims.inn; i = i + 1u) {
    acc = acc + d_input[i] * d_weight[o + d_dims.outn * i];
  }
  if (d_dims.apply_relu == 1u) { acc = max(acc, 0.0); }
  d_output[o] = acc;
}
