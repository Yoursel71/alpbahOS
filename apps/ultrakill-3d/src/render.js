// Renderer, düşük çözünürlüklü hedef, renk sıkıştırma + dither ve PSX köşe titremesi
import * as THREE from 'three';
import { settings } from './settings.js';

export const psxUniforms = {
  uSnap: { value: new THREE.Vector2(320, 180) },
  uJitter: { value: 1 },
};

// Malzemeye PSX tarzı köşe yakalama ekler
export function psx(mat) {
  mat.onBeforeCompile = (sh) => {
    sh.uniforms.uSnap = psxUniforms.uSnap;
    sh.uniforms.uJitter = psxUniforms.uJitter;
    sh.vertexShader = 'uniform vec2 uSnap;\nuniform float uJitter;\n' + sh.vertexShader.replace(
      '#include <project_vertex>',
      `#include <project_vertex>
      if (uJitter > 0.5) {
        vec4 psxp = gl_Position;
        psxp.xy = floor(psxp.xy / psxp.w * uSnap + 0.5) / uSnap * psxp.w;
        gl_Position = psxp;
      }`
    );
  };
  mat.customProgramCacheKey = () => 'psx1';
  return mat;
}

const POST_VS = `varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`;
const POST_FS = `
uniform sampler2D tDiffuse;
uniform sampler2D tGlyph;
uniform float uAscii;   // 0: kapalı · 1: renkli ASCII · 2: yeşil fosfor ASCII
uniform float uGlyphN;
uniform vec2 uScreen;
uniform vec2 uCell;
uniform vec2 uRes;
uniform float uLevels;
uniform float uVignette;
uniform vec3 uTint;
uniform float uTintAmt;
uniform float uGray;
varying vec2 vUv;
float bayer(vec2 p){
  vec2 q = mod(floor(p), 4.0);
  float i = q.x + q.y * 4.0;
  // 4x4 Bayer matrisi
  float m[16];
  m[0]=0.;m[1]=8.;m[2]=2.;m[3]=10.;m[4]=12.;m[5]=4.;m[6]=14.;m[7]=6.;
  m[8]=3.;m[9]=11.;m[10]=1.;m[11]=9.;m[12]=15.;m[13]=7.;m[14]=13.;m[15]=5.;
  float v = 0.0;
  for (int k = 0; k < 16; k++) { if (float(k) == i) v = m[k]; }
  return v / 16.0;
}
vec3 toSRGB(vec3 c){
  c = max(c, vec3(0.0));
  vec3 lo = c * 12.92;
  vec3 hi = 1.055 * pow(c, vec3(1.0/2.4)) - 0.055;
  return mix(lo, hi, step(vec3(0.0031308), c));
}
vec3 grade(vec3 c){
  c = toSRGB(c);
  float g = dot(c, vec3(0.299, 0.587, 0.114));
  c = mix(c, vec3(g), uGray);
  return mix(c, uTint, uTintAmt);
}
void main(){
  if (uAscii > 0.5) {
    // Terminal görünümü: her hücre sahnenin o bölgesinin parlaklığına göre bir karakter
    vec2 px = vUv * uScreen;
    vec2 cell = floor(px / uCell);
    vec2 cs = uCell / uScreen;
    vec2 cuv = (cell + 0.5) * cs;
    vec3 c = grade(texture2D(tDiffuse, cuv).rgb);
    vec3 W = vec3(0.299, 0.587, 0.114);
    float lum = dot(c, W);
    // komşu hücrelerle fark: siluetler belirgin karakterlerle çizilsin
    float ln = (dot(grade(texture2D(tDiffuse, cuv + vec2(cs.x, 0.0)).rgb), W) + dot(grade(texture2D(tDiffuse, cuv - vec2(cs.x, 0.0)).rgb), W)
      + dot(grade(texture2D(tDiffuse, cuv + vec2(0.0, cs.y)).rgb), W) + dot(grade(texture2D(tDiffuse, cuv - vec2(0.0, cs.y)).rgb), W)) * 0.25;
    float edge = clamp(abs(lum - ln) * 3.0, 0.0, 0.55);
    float l = clamp(pow(lum * 1.5, 0.62) + edge, 0.0, 0.999);
    vec2 f = fract(px / uCell);
    float m = texture2D(tGlyph, vec2((floor(l * uGlyphN) + f.x) / uGlyphN, f.y)).r;
    vec3 col;
    if (uAscii < 1.5) {
      vec3 hue = c / max(max(c.r, max(c.g, c.b)), 0.06);
      col = mix(c, hue * (0.55 + l * 0.75), 0.65) * m * 1.2 + c * 0.16;
    } else {
      vec3 ph = vec3(0.26, 1.0, 0.46);
      col = ph * m * (0.4 + l * 0.95) + ph * 0.03 + c * 0.05;
    }
    col *= 0.88 + 0.12 * step(0.5, fract(px.y * 0.5));
    vec2 v = vUv - 0.5;
    col *= 1.0 - dot(v, v) * uVignette;
    gl_FragColor = vec4(col, 1.0);
    return;
  }
  vec3 c = grade(texture2D(tDiffuse, vUv).rgb);
  if (uLevels > 0.5) {
    float d = bayer(vUv * uRes) - 0.5;
    c = floor(c * uLevels + 0.5 + d * 0.9) / uLevels;
  }
  vec2 v = vUv - 0.5;
  c *= 1.0 - dot(v, v) * uVignette;
  gl_FragColor = vec4(c, 1.0);
}`;

// ASCII karakter atlası: parlaklığa göre sıralı 16 glif (boşluktan tam bloğa)
const GLYPHS = [' ', '.', '`', ':', '-', '~', '=', '+', '*', 'x', 'o', '%', '#', '&', '@', null];
function glyphAtlas() {
  const W = 16, H = 26, N = GLYPHS.length;
  const cv = document.createElement('canvas');
  cv.width = W * N;
  cv.height = H;
  const c = cv.getContext('2d');
  c.fillStyle = '#000';
  c.fillRect(0, 0, cv.width, cv.height);
  c.fillStyle = '#fff';
  c.font = 'bold 22px ui-monospace, "Cascadia Mono", "DejaVu Sans Mono", monospace';
  c.textAlign = 'center';
  c.textBaseline = 'middle';
  GLYPHS.forEach((g, i) => {
    if (g === null) c.fillRect(i * W + 1, 2, W - 2, H - 4);
    else c.fillText(g, i * W + W / 2, H / 2 + 1);
  });
  const t = new THREE.CanvasTexture(cv);
  t.minFilter = THREE.LinearMipmapLinearFilter;
  t.magFilter = THREE.LinearFilter;
  t.generateMipmaps = true;
  return { tex: t, n: N };
}

export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.gl = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance', preserveDrawingBuffer: false });
    this.gl.autoClear = false;
    this.gl.setPixelRatio(1);
    this.gl.outputColorSpace = THREE.SRGBColorSpace;
    this.target = new THREE.WebGLRenderTarget(4, 4, {
      type: THREE.HalfFloatType,
      minFilter: THREE.NearestFilter,
      magFilter: THREE.NearestFilter,
      depthBuffer: true,
    });
    const atlas = glyphAtlas();
    this.postMat = new THREE.ShaderMaterial({
      uniforms: {
        tDiffuse: { value: this.target.texture },
        tGlyph: { value: atlas.tex },
        uGlyphN: { value: atlas.n },
        uAscii: { value: 0 },
        uScreen: { value: new THREE.Vector2(4, 4) },
        uCell: { value: new THREE.Vector2(8, 13) },
        uRes: { value: new THREE.Vector2(4, 4) },
        uLevels: { value: 24 },
        uVignette: { value: 0.9 },
        uTint: { value: new THREE.Color(1, 0, 0) },
        uTintAmt: { value: 0 },
        uGray: { value: 0 },
      },
      vertexShader: POST_VS,
      fragmentShader: POST_FS,
      depthTest: false,
      depthWrite: false,
    });
    this.postScene = new THREE.Scene();
    const quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), this.postMat);
    quad.frustumCulled = false;
    this.postScene.add(quad);
    this.postCam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
    this.w = 0;
    this.h = 0;
    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  resize() {
    const w = Math.max(1, window.innerWidth), h = Math.max(1, window.innerHeight);
    this.w = w;
    this.h = h;
    this.gl.setSize(w, h, true);
    this.applyScale();
  }

  applyScale() {
    const s = Math.max(0.2, Math.min(1, settings.resScale));
    const tw = Math.max(64, Math.floor(this.w * s));
    const th = Math.max(48, Math.floor(this.h * s));
    this.target.setSize(tw, th);
    this.postMat.uniforms.uRes.value.set(tw, th);
    psxUniforms.uSnap.value.set(Math.min(tw, 480) / 2, Math.min(th, 270) / 2);
    psxUniforms.uJitter.value = settings.vertexJitter ? 1 : 0;
    this.postMat.uniforms.uLevels.value = settings.colorCompress ? 20 : 0;
    // ASCII (yalnız menü ve intro): ekran genişliğine göre ~100-140 sütun
    const u = this.postMat.uniforms;
    u.uScreen.value.set(this.w, this.h);
    const cw = Math.max(6, Math.round(this.w / (this.w < 900 ? 104 : 140)));
    u.uCell.value.set(cw, Math.round(cw * 1.6));
  }

  // on: bu karede terminal (ASCII) görünümü kullanılsın mı — yalnız menü/intro için çağrılır
  setAscii(on) {
    const mode = on ? settings.termRender || 'off' : 'off';
    this.postMat.uniforms.uAscii.value = mode === 'ascii' ? 1 : mode === 'mono' ? 2 : 0;
  }

  render(scene, camera, vmScene, vmCamera) {
    const gl = this.gl;
    gl.setRenderTarget(this.target);
    gl.setClearColor(0x000000, 1);
    gl.clear(true, true, true);
    gl.render(scene, camera);
    if (vmScene) {
      gl.clearDepth();
      gl.render(vmScene, vmCamera);
    }
    gl.setRenderTarget(null);
    gl.clear(true, true, true);
    gl.render(this.postScene, this.postCam);
  }
}
