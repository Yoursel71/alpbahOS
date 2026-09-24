// Bölüm sonu düşüşü: sonuç ekranı açıkken V1 karanlık bir kuyuda aşağı düşer. Ayrı, ışıksız küçük
// bir sahnedir (bölüm sahnesi gizlenmez, yalnız bu sahne çizilir): kayan çizgili tünel, yukarı akan
// rüzgâr çizgileri ve çok aşağıda bölüm temasının renginde parlayan ışık.
import * as THREE from 'three';

export class FallFX {
  constructor(game) {
    this.game = game;
    this.active = false;
    this.t = 0;
    const scene = (this.scene = new THREE.Scene());
    scene.background = new THREE.Color(0x020103);
    scene.fog = new THREE.Fog(0x020103, 20, 130);
    // tünel dokusu: dikey, rastgele parlaklıkta çizgiler
    const c = document.createElement('canvas');
    c.width = 64; c.height = 256;
    const x = c.getContext('2d');
    x.fillStyle = '#0a0506';
    x.fillRect(0, 0, 64, 256);
    for (let i = 0; i < 160; i++) {
      x.fillStyle = `rgba(255,255,255,${(0.04 + Math.random() * 0.3).toFixed(2)})`;
      x.fillRect(Math.floor(Math.random() * 64), Math.floor(Math.random() * 256), 1 + Math.floor(Math.random() * 2), 8 + Math.floor(Math.random() * 60));
    }
    this.tex = new THREE.CanvasTexture(c);
    this.tex.wrapS = this.tex.wrapT = THREE.RepeatWrapping;
    this.tex.repeat.set(5, 2);
    this.tex.colorSpace = THREE.SRGBColorSpace;
    this.tunnelMat = new THREE.MeshBasicMaterial({ map: this.tex, color: 0xff6040, side: THREE.BackSide });
    this.tunnel = new THREE.Mesh(new THREE.CylinderGeometry(10, 10, 260, 20, 1, true), this.tunnelMat);
    scene.add(this.tunnel);
    // dipteki ışık
    this.glowMat = new THREE.SpriteMaterial({ map: game.tex.glow, color: 0xff5020, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false });
    this.glow = new THREE.Sprite(this.glowMat);
    this.glow.position.set(0, -115, 0);
    this.glow.scale.setScalar(80);
    scene.add(this.glow);
    // rüzgâr çizgileri
    const sGeo = new THREE.BoxGeometry(0.035, 3.2, 0.035);
    this.streakMat = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false });
    this.streaks = [];
    for (let i = 0; i < 80; i++) {
      const m = new THREE.Mesh(sGeo, this.streakMat);
      const a = Math.random() * Math.PI * 2, r = 1.4 + Math.random() * 7.5;
      m.position.set(Math.cos(a) * r, -130 + Math.random() * 160, Math.sin(a) * r);
      m.userData.v = 45 + Math.random() * 40;
      scene.add(m);
      this.streaks.push(m);
    }
  }

  start(theme) {
    this.active = true;
    this.t = 0;
    const fog = new THREE.Color(theme.fog);
    const glow = new THREE.Color(...(theme.skyGlow || [0.6, 0.2, 0.05]));
    // karanlık temalarda da görünsün: rengi parlaklaştır
    const base = fog.clone().multiplyScalar(2.6).lerp(glow, 0.35);
    this.tunnelMat.color.copy(base);
    this.glowMat.color.copy(glow.clone().multiplyScalar(1.6));
    this.scene.background.copy(fog).multiplyScalar(0.25);
    this.scene.fog.color.copy(this.scene.background);
    document.getElementById('scr-results')?.classList.add('falling');
  }

  stop() {
    if (!this.active) return;
    this.active = false;
    document.getElementById('scr-results')?.classList.remove('falling');
  }

  update(dt, cam) {
    this.t += dt;
    const t = this.t;
    this.tex.offset.y -= dt * 1.6;
    for (const m of this.streaks) {
      m.position.y += m.userData.v * dt;
      if (m.position.y > 30) m.position.y -= 160;
    }
    this.glow.material.rotation = t * 0.2;
    this.glow.scale.setScalar(80 + Math.sin(t * 2.2) * 6);
    // aşağı bakan, yavaşça dönen ve hafifçe sallanan kamera
    cam.position.set(Math.sin(t * 0.7) * 0.4, 0, Math.cos(t * 0.9) * 0.4);
    cam.rotation.set(-1.28 + Math.sin(t * 1.1) * 0.05, t * 0.25, Math.sin(t * 1.3) * 0.12);
    if (Math.abs(cam.fov - 95) > 0.01) { cam.fov = 95; cam.updateProjectionMatrix(); }
  }
}
