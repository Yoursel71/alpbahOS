// Görsel efektler: kan parçacıkları, kan lekeleri, et parçaları (gib), iz mermileri,
// halkalar, parlamalar, patlama küreleri, kıvılcımlar.
import * as THREE from 'three';
import { rand } from './util.js';
import { psx } from './render.js';

const _m = new THREE.Matrix4();
const _q = new THREE.Quaternion();
const _s = new THREE.Vector3();
const _p = new THREE.Vector3();
const _up = new THREE.Vector3(0, 1, 0);
const _n = new THREE.Vector3();
const _c = new THREE.Color();

class ParticlePool {
  constructor(scene, max, material, geo) {
    this.max = max;
    this.mesh = new THREE.InstancedMesh(geo, material, max);
    this.mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.mesh.frustumCulled = false;
    this.mesh.count = 0;
    this.mesh.setColorAt(0, new THREE.Color(1, 1, 1));
    scene.add(this.mesh);
    this.parts = [];
  }
}

export class FX {
  constructor(game) {
    this.game = game;
    const scene = game.scene;
    const T = game.tex;
    this.scene = scene;

    // Kan damlaları (dünya çarpışmalı)
    this.blood = new ParticlePool(scene, 900, new THREE.MeshBasicMaterial({ color: 0xffffff }), new THREE.BoxGeometry(1, 1, 1));
    // Kıvılcım / enerji (eklemeli)
    this.sparks = new ParticlePool(scene, 500, new THREE.MeshBasicMaterial({ color: 0xffffff, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true }), new THREE.BoxGeometry(1, 1, 1));

    // Kan lekeleri
    this.decalMax = 450;
    const dMat = new THREE.MeshBasicMaterial({ map: T.blood, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -4, alphaTest: 0.3 });
    this.decals = new THREE.InstancedMesh(new THREE.PlaneGeometry(1, 1), dMat, this.decalMax);
    this.decals.frustumCulled = false;
    this.decals.count = 0;
    this.decals.setColorAt(0, new THREE.Color(1, 1, 1));
    this.decalIdx = 0;
    scene.add(this.decals);

    this.gibs = [];
    this.tracers = [];
    this.rings = [];
    this.sprites = [];
    this.shells = [];

    this.tracerGeo = new THREE.BoxGeometry(1, 1, 1);
    this.tracerGeo.translate(0, 0, -0.5);
    this.ringGeo = new THREE.RingGeometry(0.85, 1, 32);
    this.ringGeo.rotateX(-Math.PI / 2);
    this.shellGeo = new THREE.SphereGeometry(1, 16, 10);
    this.spriteMatCache = new Map();
    this.gibCountMax = 160;
  }

  // ---- kan ----
  bloodBurst(pos, count = 20, speed = 8, dir = null, big = false) {
    const pool = this.blood;
    for (let i = 0; i < count; i++) {
      if (pool.parts.length >= pool.max) pool.parts.shift();
      const v = new THREE.Vector3(rand(-1, 1), rand(-0.2, 1.2), rand(-1, 1)).normalize().multiplyScalar(speed * rand(0.3, 1));
      if (dir) v.addScaledVector(dir, speed * 0.6);
      const dark = rand(0.35, 0.8);
      pool.parts.push({
        p: pos.clone().add(new THREE.Vector3(rand(-0.15, 0.15), rand(-0.15, 0.15), rand(-0.15, 0.15))),
        v,
        life: rand(0.6, 1.4),
        size: big ? rand(0.08, 0.2) : rand(0.05, 0.13),
        col: [dark, 0.02, 0.02],
        g: 22,
        decal: Math.random() < 0.35,
      });
    }
  }

  sparkBurst(pos, count = 8, speed = 8, color = 0xffc040, life = 0.35, size = 0.06, g = 10) {
    const pool = this.sparks;
    _c.set(color);
    for (let i = 0; i < count; i++) {
      if (pool.parts.length >= pool.max) pool.parts.shift();
      const v = new THREE.Vector3(rand(-1, 1), rand(-1, 1), rand(-1, 1)).normalize().multiplyScalar(speed * rand(0.3, 1));
      pool.parts.push({ p: pos.clone(), v, life: life * rand(0.5, 1), maxLife: life, size: size * rand(0.6, 1.4), col: [_c.r, _c.g, _c.b], g, spark: true });
    }
  }

  sparkDir(pos, dir, count, speed, color, life = 0.3, size = 0.05, spread = 0.5) {
    const pool = this.sparks;
    _c.set(color);
    for (let i = 0; i < count; i++) {
      if (pool.parts.length >= pool.max) pool.parts.shift();
      const v = dir.clone().add(new THREE.Vector3(rand(-spread, spread), rand(-spread, spread), rand(-spread, spread))).normalize().multiplyScalar(speed * rand(0.4, 1));
      pool.parts.push({ p: pos.clone(), v, life: life * rand(0.5, 1), maxLife: life, size: size * rand(0.6, 1.4), col: [_c.r, _c.g, _c.b], g: 6, spark: true });
    }
  }

  addDecal(x, y, z, nx, ny, nz, size) {
    const i = this.decalIdx;
    this.decalIdx = (this.decalIdx + 1) % this.decalMax;
    _n.set(nx, ny, nz);
    _q.setFromUnitVectors(new THREE.Vector3(0, 0, 1), _n);
    const rot = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 0, 1), rand(0, Math.PI * 2));
    _q.multiply(rot);
    _p.set(x + nx * 0.02, y + ny * 0.02, z + nz * 0.02);
    _s.set(size, size, size);
    _m.compose(_p, _q, _s);
    this.decals.setMatrixAt(i, _m);
    const k = rand(0.6, 1.1);
    this.decals.setColorAt(i, _c.setRGB(k, k * 0.9, k * 0.9));
    this.decals.count = Math.max(this.decals.count, i + 1);
    this.decals.instanceMatrix.needsUpdate = true;
    if (this.decals.instanceColor) this.decals.instanceColor.needsUpdate = true;
  }

  clearDecals() {
    this.decals.count = 0;
    this.decalIdx = 0;
  }

  // ---- et parçaları: düşman modelinin parçalarını fiziksel nesnelere dönüştür ----
  gibFromMesh(mesh, vel, spin = 8) {
    mesh.updateWorldMatrix(true, false);
    const m = new THREE.Mesh(mesh.geometry, mesh.material);
    mesh.matrixWorld.decompose(m.position, m.quaternion, m.scale);
    this.scene.add(m);
    const size = new THREE.Box3().setFromObject(m).getSize(new THREE.Vector3());
    const r = Math.max(0.05, Math.min(0.25, Math.min(size.x, size.y, size.z) * 0.5));
    this.pushGib({ mesh: m, v: vel.clone(), w: new THREE.Vector3(rand(-spin, spin), rand(-spin, spin), rand(-spin, spin)), life: rand(5, 7), r, bleed: rand(0.3, 1.0) });
  }

  gibChunk(pos, vel, size, material) {
    const geo = new THREE.BoxGeometry(size, size * rand(0.6, 1.2), size * rand(0.6, 1.2));
    const m = new THREE.Mesh(geo, material);
    m.position.copy(pos);
    this.scene.add(m);
    this.pushGib({ mesh: m, v: vel.clone(), w: new THREE.Vector3(rand(-10, 10), rand(-10, 10), rand(-10, 10)), life: rand(3, 5), r: size * 0.5, bleed: 0.6, ownGeo: true });
  }

  pushGib(g) {
    if (this.gibs.length >= this.gibCountMax) {
      const old = this.gibs.shift();
      this.removeGib(old);
    }
    g.body = { pos: g.mesh.position, r: g.r, h: g.r * 2, isEnemy: true };
    g.mesh.position.y -= g.r; // gövde: ayak tabanı
    g.offsetY = g.r;
    g.mesh.position.y += g.r;
    this.gibs.push(g);
  }

  removeGib(g) {
    this.scene.remove(g.mesh);
    if (g.ownGeo) g.mesh.geometry.dispose();
  }

  // ---- iz mermisi ----
  tracer(from, to, color = 0xfff0a0, width = 0.05, life = 0.12) {
    const key = 't' + color;
    let mat = this.spriteMatCache.get(key);
    if (!mat) {
      mat = new THREE.MeshBasicMaterial({ color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
      this.spriteMatCache.set(key, mat);
    }
    const m = new THREE.Mesh(this.tracerGeo, mat.clone());
    const len = from.distanceTo(to);
    m.position.copy(from);
    m.lookAt(to);
    m.scale.set(width, width, len);
    this.scene.add(m);
    this.tracers.push({ mesh: m, life, max: life, w: width });
  }

  ring(pos, color = 0x80c0ff, radius = 4, life = 0.4, y = 0.05) {
    const mat = new THREE.MeshBasicMaterial({ color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
    const m = new THREE.Mesh(this.ringGeo, mat);
    m.position.copy(pos);
    m.position.y += y;
    m.scale.setScalar(0.1);
    this.scene.add(m);
    this.rings.push({ mesh: m, life, max: life, radius });
  }

  shell(pos, color = 0xff8020, radius = 5, life = 0.45) {
    const mat = new THREE.MeshBasicMaterial({ color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
    const m = new THREE.Mesh(this.shellGeo, mat);
    m.position.copy(pos);
    m.scale.setScalar(0.2);
    this.scene.add(m);
    this.shells.push({ mesh: m, life, max: life, radius });
  }

  sprite(pos, color = 0xffffff, size = 1, life = 0.2, tex = 'star', grow = 1.5) {
    const T = this.game.tex;
    const mat = new THREE.SpriteMaterial({ map: T[tex], color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, depthTest: tex !== 'star' });
    const s = new THREE.Sprite(mat);
    s.position.copy(pos);
    s.scale.setScalar(size);
    s.renderOrder = 10;
    this.scene.add(s);
    this.sprites.push({ s, life, max: life, size, grow });
    return s;
  }

  spawnFX(pos, h = 2) {
    this.ring(pos, 0x9fd8ff, 2.5, 0.6);
    this.sparkBurst(pos.clone().add(new THREE.Vector3(0, h * 0.5, 0)), 20, 6, 0xa0e0ff, 0.6, 0.07, -2);
    const beam = this.shell(pos.clone().add(new THREE.Vector3(0, h * 0.5, 0)), 0x80c8ff, 1.6, 0.5);
    this.game.audio.play('spawn', pos);
  }

  explosionFX(pos, radius) {
    this.shell(pos, 0xff7a1a, radius, 0.5);
    this.shell(pos, 0xffe0a0, radius * 0.55, 0.3);
    this.sparkBurst(pos, 40, radius * 3, 0xffa030, 0.7, 0.12, 12);
    this.ring(pos, 0xff8030, radius * 1.4, 0.5, 0);
    this.game.flashLight(pos, 0xff8030, 12, radius * 5, 0.25);
  }

  update(dt) {
    const world = this.game.world;
    // Parçacık havuzları
    for (const pool of [this.blood, this.sparks]) {
      const parts = pool.parts;
      let n = 0;
      for (let i = 0; i < parts.length; i++) {
        const q = parts[i];
        q.life -= dt;
        if (q.life <= 0) continue;
        q.v.y -= q.g * dt;
        const nx = q.p.x + q.v.x * dt, ny = q.p.y + q.v.y * dt, nz = q.p.z + q.v.z * dt;
        if (!q.spark || q.g > 5) {
          const s = world.pointInSolid(nx, ny, nz);
          if (s) {
            if (q.decal && !q.spark) {
              // en yakın yüzey normalini bul
              const hit = world.raycast(q.p.x, q.p.y, q.p.z, ...norm3(q.v), q.v.length() * dt + 0.2);
              if (hit) this.addDecal(hit.x, hit.y, hit.z, hit.nx, hit.ny, hit.nz, rand(0.5, 1.4));
            }
            if (!q.spark) continue;
            q.v.multiplyScalar(-0.3);
            parts[n++] = q;
            continue;
          }
        }
        q.p.set(nx, ny, nz);
        parts[n++] = q;
      }
      parts.length = n;
      const mesh = pool.mesh;
      for (let i = 0; i < n; i++) {
        const q = parts[i];
        let sz = q.size;
        if (q.spark) sz *= Math.max(0.1, q.life / q.maxLife);
        _s.set(sz, sz, q.spark ? sz * 3 : sz);
        if (q.spark) {
          _n.copy(q.v).normalize();
          _q.setFromUnitVectors(new THREE.Vector3(0, 0, 1), _n.lengthSq() > 0 ? _n : _up);
        } else _q.identity();
        _m.compose(q.p, _q, _s);
        mesh.setMatrixAt(i, _m);
        mesh.setColorAt(i, _c.setRGB(q.col[0], q.col[1], q.col[2]));
      }
      mesh.count = n;
      mesh.instanceMatrix.needsUpdate = true;
      if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
    }

    // Et parçaları
    for (let i = this.gibs.length - 1; i >= 0; i--) {
      const g = this.gibs[i];
      g.life -= dt;
      if (g.life <= 0) {
        this.removeGib(g);
        this.gibs.splice(i, 1);
        continue;
      }
      if (!g.sleep) {
        g.v.y -= 28 * dt;
        const b = g.body;
        b.pos.y -= g.offsetY;
        const r = world.moveBody(b, g.v.x * dt, g.v.y * dt, g.v.z * dt);
        b.pos.y += g.offsetY;
        if (r.hitX) g.v.x *= -0.4;
        if (r.hitZ) g.v.z *= -0.4;
        if (r.ground) {
          if (Math.abs(g.v.y) > 3 && g.bleed > 0 && Math.random() < 0.5) {
            this.addDecal(b.pos.x, b.pos.y - g.offsetY, b.pos.z, 0, 1, 0, rand(0.4, 1.0));
          }
          g.v.y *= -0.35;
          g.v.x *= 0.7;
          g.v.z *= 0.7;
          g.w.multiplyScalar(0.7);
          if (Math.abs(g.v.y) < 1 && g.v.x * g.v.x + g.v.z * g.v.z < 0.3) g.sleep = true;
        }
        if (r.ceil) g.v.y = -Math.abs(g.v.y) * 0.3;
        g.mesh.rotation.x += g.w.x * dt;
        g.mesh.rotation.y += g.w.y * dt;
        g.mesh.rotation.z += g.w.z * dt;
        if (g.bleed > 0 && Math.random() < dt * 20) {
          g.bleed -= dt;
          this.bloodBurst(g.mesh.position, 1, 1.5);
        }
      }
      if (g.life < 1) g.mesh.scale.multiplyScalar(Math.max(0.0, 1 - dt * 2.5));
    }

    for (let i = this.tracers.length - 1; i >= 0; i--) {
      const t = this.tracers[i];
      t.life -= dt;
      if (t.life <= 0) {
        this.scene.remove(t.mesh);
        t.mesh.material.dispose();
        this.tracers.splice(i, 1);
        continue;
      }
      const k = t.life / t.max;
      t.mesh.material.opacity = k;
      t.mesh.scale.x = t.mesh.scale.y = t.w * (0.3 + k * 0.7);
    }
    for (let i = this.rings.length - 1; i >= 0; i--) {
      const t = this.rings[i];
      t.life -= dt;
      if (t.life <= 0) {
        this.scene.remove(t.mesh);
        t.mesh.material.dispose();
        this.rings.splice(i, 1);
        continue;
      }
      const k = 1 - t.life / t.max;
      t.mesh.scale.setScalar(0.1 + t.radius * (1 - (1 - k) * (1 - k)));
      t.mesh.material.opacity = 1 - k;
    }
    for (let i = this.shells.length - 1; i >= 0; i--) {
      const t = this.shells[i];
      t.life -= dt;
      if (t.life <= 0) {
        this.scene.remove(t.mesh);
        t.mesh.material.dispose();
        this.shells.splice(i, 1);
        continue;
      }
      const k = 1 - t.life / t.max;
      t.mesh.scale.setScalar(0.2 + t.radius * (1 - (1 - k) * (1 - k)));
      t.mesh.material.opacity = (1 - k) * 0.9;
    }
    for (let i = this.sprites.length - 1; i >= 0; i--) {
      const t = this.sprites[i];
      t.life -= dt;
      if (t.life <= 0) {
        this.scene.remove(t.s);
        t.s.material.dispose();
        this.sprites.splice(i, 1);
        continue;
      }
      const k = 1 - t.life / t.max;
      t.s.scale.setScalar(t.size * (1 + k * (t.grow - 1)));
      t.s.material.opacity = 1 - k;
      if (t.follow) t.s.position.copy(t.follow);
    }
  }

  clearAll() {
    for (const g of this.gibs) this.removeGib(g);
    this.gibs.length = 0;
    this.blood.parts.length = 0;
    this.sparks.parts.length = 0;
    for (const t of this.tracers) this.scene.remove(t.mesh);
    for (const t of this.rings) this.scene.remove(t.mesh);
    for (const t of this.shells) this.scene.remove(t.mesh);
    for (const t of this.sprites) this.scene.remove(t.s);
    this.tracers.length = this.rings.length = this.shells.length = this.sprites.length = 0;
  }
}

function norm3(v) {
  const l = v.length() || 1;
  return [v.x / l, v.y / l, v.z / l];
}

export { psx };
