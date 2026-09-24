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
void main(){
  vec3 c = texture2D(tDiffuse, vUv).rgb;
  c = toSRGB(c);
  float g = dot(c, vec3(0.299, 0.587, 0.114));
  c = mix(c, vec3(g), uGray);
  c = mix(c, uTint, uTintAmt);
  if (uLevels > 0.5) {
    float d = bayer(vUv * uRes) - 0.5;
    c = floor(c * uLevels + 0.5 + d * 0.9) / uLevels;
  }
  vec2 v = vUv - 0.5;
  c *= 1.0 - dot(v, v) * uVignette;
  gl_FragColor = vec4(c, 1.0);
}`;

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
    this.postMat = new THREE.ShaderMaterial({
      uniforms: {
        tDiffuse: { value: this.target.texture },
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
