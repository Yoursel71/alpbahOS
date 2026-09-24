// Mermiler: düşman küreleri (savuşturulabilir), boss saçma taneleri, fırlatılan kılıç,
// oyuncunun çekirdek bombası (Core Eject) ve Marksman bozuk paraları.
import * as THREE from 'three';
import { rand } from './util.js';

const _a = new THREE.Vector3();
const _b = new THREE.Vector3();
const _d = new THREE.Vector3();

// Nokta ile doğru parçası arası uzaklığın karesi
function segDist2(p, a, b) {
  _d.subVectors(b, a);
  const l2 = _d.lengthSq();
  let t = l2 > 0 ? _a.subVectors(p, a).dot(_d) / l2 : 0;
  t = Math.max(0, Math.min(1, t));
  _b.copy(a).addScaledVector(_d, t);
  return { d2: _b.distanceToSquared(p), t };
}

let coreGeo = null, orbGeo = null, pelletGeo = null;

export class Projectile {
  constructor(game, o) {
    this.game = game;
    this.kind = o.kind || 'orb';
    this.pos = o.pos.clone();
    this.prev = o.pos.clone();
    this.vel = o.vel.clone();
    this.radius = o.radius ?? 0.3;
    this.damage = o.damage ?? 20;
    this.owner = o.owner || 'enemy';
    this.parryable = o.parryable ?? true;
    this.gravity = o.gravity ?? 0;
    this.life = o.life ?? 6;
    this.source = o.source || null;
    this.color = o.color ?? 0xff8a20;
    this.dead = false;
    this.parried = false;
    this.age = 0;
    this.hitPlayerOnce = false;
    this.group = new THREE.Group();
    this.group.position.copy(this.pos);
    this.buildMesh(o);
    game.scene.add(this.group);
  }

  buildMesh(o) {
    const T = this.game.tex;
    if (!orbGeo) {
      orbGeo = new THREE.IcosahedronGeometry(1, 1);
      coreGeo = new THREE.IcosahedronGeometry(1, 0);
      pelletGeo = new THREE.BoxGeometry(1, 1, 1);
    }
    if (this.kind === 'sword') {
      this.mesh = o.mesh;
      this.group.add(this.mesh);
      return;
    }
    const geo = this.kind === 'pellet' ? pelletGeo : this.kind === 'core' ? coreGeo : orbGeo;
    this.coreMat = new THREE.MeshBasicMaterial({ color: this.kind === 'core' ? 0x9ad8ff : 0xfff2c0 });
    this.mesh = new THREE.Mesh(geo, this.coreMat);
    const s = this.kind === 'pellet' ? 0.12 : this.radius * 0.7;
    this.mesh.scale.set(s, s, this.kind === 'pellet' ? 0.5 : s);
    this.group.add(this.mesh);
    this.glowMat = new THREE.SpriteMaterial({ map: T.glow, color: this.color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
    this.glow = new THREE.Sprite(this.glowMat);
    this.glow.scale.setScalar(this.kind === 'pellet' ? 0.6 : this.radius * 5);
    this.group.add(this.glow);
  }

  setColor(c) {
    this.color = c;
    if (this.glowMat) this.glowMat.color.setHex(c);
  }

  parry(dir, speed) {
    this.owner = 'player';
    this.parried = true;
    this.vel.copy(dir).multiplyScalar(speed);
    this.damage = this.kind === 'orb' ? 4 : 3;
    this.life = 4;
    this.gravity = 0;
    this.setColor(0x9fd8ff);
    if (this.coreMat) this.coreMat.color.setHex(0xffffff);
    this.glow.scale.multiplyScalar(1.4);
  }

  remove() {
    if (this.dead) return;
    this.dead = true;
    this.game.scene.remove(this.group);
    if (this.glowMat) this.glowMat.dispose();
    if (this.coreMat) this.coreMat.dispose();
  }

  update(dt) {
    const game = this.game;
    this.age += dt;
    this.life -= dt;
    if (this.kind === 'sword') return this.updateSword(dt);
    if (this.life <= 0) {
      if (this.kind === 'core') this.explodeCore();
      return this.remove();
    }
    this.prev.copy(this.pos);
    this.vel.y -= this.gravity * dt;
    const step = this.vel.length() * dt;
    if (step > 0) {
      const inv = 1 / (this.vel.length() || 1);
      const hit = game.world.raycast(this.pos.x, this.pos.y, this.pos.z, this.vel.x * inv, this.vel.y * inv, this.vel.z * inv, step + this.radius * 0.5);
      if (hit) {
        this.pos.set(hit.x, hit.y, hit.z);
        return this.onWorldHit(hit);
      }
      this.pos.addScaledVector(this.vel, dt);
    }
    this.group.position.copy(this.pos);
    if (this.kind === 'core') {
      this.mesh.rotation.x += dt * 8;
      this.mesh.rotation.y += dt * 6;
      const pulse = 1 + Math.sin(this.age * 30) * 0.2;
      this.glow.scale.setScalar(this.radius * 5 * pulse);
    } else {
      this.glow.material.rotation += dt * 4;
    }
    if (this.kind === 'pellet') this.mesh.lookAt(this.pos.x + this.vel.x, this.pos.y + this.vel.y, this.pos.z + this.vel.z);

    if (this.owner === 'enemy') {
      // oyuncuya çarpma
      const p = game.player;
      if (!p.dead) {
        _a.set(p.pos.x, p.pos.y + Math.min(0.4, p.h * 0.3), p.pos.z);
        _b.set(p.pos.x, p.pos.y + p.h - 0.3, p.pos.z);
        // kapsül: oyuncu ekseni ile mermi yolu arasındaki mesafe (yaklaşık: merminin konumunu eksene yansıt)
        const r = segDist2(this.pos, _a, _b);
        const rr = this.radius + p.r;
        if (r.d2 < rr * rr) {
          if (game.damagePlayer(this.damage, this.pos)) {
            game.fx.sparkBurst(this.pos, 10, 6, this.color, 0.3, 0.06);
            game.audio.play('projHit', this.pos);
            return this.remove();
          }
        }
      }
    } else {
      // oyuncu mermisi: düşmanlara çarpma
      for (const e of game.enemies) {
        if (e.dead || e.state === 'spawn') continue;
        const hit = e.segmentHit(this.prev, this.pos, this.radius);
        if (hit) {
          if (this.kind === 'core') {
            this.pos.copy(hit.point);
            this.explodeCore();
            return this.remove();
          }
          e.hit({ dmg: this.damage, part: hit.part, point: hit.point, dir: this.vel.clone().normalize(), weapon: this.parried ? 'parry' : 'revolver', knock: 10, parried: this.parried, headMult: 1.5 });
          game.fx.sparkBurst(this.pos, 16, 8, 0xbfe6ff, 0.35, 0.07);
          game.audio.play('projHit', this.pos);
          if (this.parried && this.kind === 'orb') game.explode(this.pos, 2.5, 1.5, { owner: 'player', playerDmg: 0, fromParry: true, small: true });
          return this.remove();
        }
      }
    }
  }

  onWorldHit(hit) {
    const game = this.game;
    if (this.kind === 'core') {
      this.pos.x += hit.nx * 0.2; this.pos.y += hit.ny * 0.2; this.pos.z += hit.nz * 0.2;
      this.explodeCore();
      return this.remove();
    }
    game.fx.sparkDir(this.pos, new THREE.Vector3(hit.nx, hit.ny, hit.nz), 8, 6, this.color, 0.3, 0.06, 0.8);
    if (this.parried) game.explode(this.pos, 2.5, 1.5, { owner: 'player', playerDmg: 0, fromParry: true, small: true });
    this.remove();
  }

  explodeCore() {
    const boosted = !!this.boosted;
    this.game.explode(this.pos, boosted ? 7.5 : 5.5, boosted ? 5 : 3.5, { owner: 'player', playerDmg: 30, knock: 18, weapon: 'shotgun' });
  }

  // ---- Boss kılıcı (bumerang) ----
  updateSword(dt) {
    const game = this.game;
    const boss = this.source;
    this.mesh.rotation.y += dt * 22;
    if (this.phase === undefined) { this.phase = 'out'; this.outT = 0; }
    if (this.phase === 'out') {
      this.outT += dt;
      const inv = 1 / (this.vel.length() || 1);
      const step = this.vel.length() * dt;
      const hit = game.world.raycast(this.pos.x, this.pos.y, this.pos.z, this.vel.x * inv, this.vel.y * inv, this.vel.z * inv, step + 0.5);
      if (hit || this.outT > 1.0) {
        if (hit) {
          game.fx.sparkBurst(new THREE.Vector3(hit.x, hit.y, hit.z), 16, 10, 0xffc040, 0.4, 0.07);
          game.audio.play('projHit', this.pos);
          game.shake(0.2);
        }
        this.phase = 'back';
        this.hitPlayerOnce = false;
      } else this.pos.addScaledVector(this.vel, dt);
    } else {
      const target = boss && !boss.dead ? boss.handWorld() : this.pos;
      _d.subVectors(target, this.pos);
      const d = _d.length();
      if (!boss || boss.dead || d < 1.2 || this.age > 6) {
        if (boss && !boss.dead) boss.catchSword();
        return this.remove();
      }
      _d.multiplyScalar(1 / d);
      const sp = 34;
      this.vel.lerp(_d.multiplyScalar(sp), Math.min(1, dt * 6));
      this.pos.addScaledVector(this.vel, dt);
    }
    this.group.position.copy(this.pos);
    if (Math.random() < dt * 30) game.fx.sparkBurst(this.pos, 1, 3, 0xffa030, 0.25, 0.05);
    const p = game.player;
    if (!p.dead && !this.hitPlayerOnce) {
      _a.set(p.pos.x, p.pos.y + p.h * 0.5, p.pos.z);
      if (_a.distanceToSquared(this.pos) < 1.6 * 1.6) {
        if (game.damagePlayer(this.damage, this.pos)) this.hitPlayerOnce = true;
      }
    }
  }
}

// Marksman bozuk parası
export class Coin {
  constructor(game, pos, vel) {
    this.game = game;
    this.pos = pos.clone();
    this.vel = vel.clone();
    this.alive = true;
    this.age = 0;
    const g = new THREE.Group();
    const m = new THREE.Mesh(new THREE.CylinderGeometry(0.17, 0.17, 0.035, 10), new THREE.MeshBasicMaterial({ color: 0xffd24a }));
    m.rotation.x = Math.PI / 2;
    g.add(m);
    const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: game.tex.glow, color: 0xffc030, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    glow.scale.setScalar(0.9);
    g.add(glow);
    this.coinMesh = m;
    this.glow = glow;
    this.group = g;
    g.position.copy(pos);
    game.scene.add(g);
  }

  update(dt) {
    if (!this.alive) return;
    this.age += dt;
    this.vel.y -= 24 * dt;
    const nx = this.pos.x + this.vel.x * dt, ny = this.pos.y + this.vel.y * dt, nz = this.pos.z + this.vel.z * dt;
    if (this.game.world.pointInSolid(nx, ny, nz) || this.age > 5) {
      this.game.audio.play('empty', this.pos);
      this.kill();
      return;
    }
    this.pos.set(nx, ny, nz);
    this.group.position.copy(this.pos);
    this.group.rotation.y += dt * 18;
    this.group.rotation.z += dt * 11;
    // tepe noktasında parlama
    const apex = Math.abs(this.vel.y) < 3;
    this.glow.scale.setScalar(apex ? 1.5 + Math.sin(this.age * 40) * 0.2 : 0.9);
  }

  kill() {
    if (!this.alive) return;
    this.alive = false;
    this.game.scene.remove(this.group);
  }
}
