// Mermiler: düşman küreleri/saçmaları (savuşturulabilir), boss kılıcı, oyuncu mermileri
// (çekirdek bombası, roket, gülle, çivi, testere diski, zincirli testere, mıknatıs) ve
// Marksman bozuk paraları.
import * as THREE from 'three';
import { rand } from './util.js';

const _a = new THREE.Vector3();
const _b = new THREE.Vector3();
const _d = new THREE.Vector3();

// İki doğru parçası arası en kısa uzaklığın karesi (yaklaşık, örnekleyerek)
function segSegDist2(a0, a1, b0, b1) {
  let best = Infinity;
  for (let i = 0; i <= 4; i++) {
    _a.copy(a0).lerp(a1, i / 4);
    _d.subVectors(b1, b0);
    const l2 = _d.lengthSq();
    let t = l2 > 0 ? _b.subVectors(_a, b0).dot(_d) / l2 : 0;
    t = Math.max(0, Math.min(1, t));
    _b.copy(b0).addScaledVector(_d, t);
    best = Math.min(best, _b.distanceToSquared(_a));
  }
  return best;
}

const GEO = {};
function geo(name, make) {
  if (!GEO[name]) GEO[name] = make();
  return GEO[name];
}

const PLAYER_KINDS = new Set(['core', 'rocket', 'cannonball', 'nail', 'saw', 'chainsaw', 'magnet']);

export class Projectile {
  constructor(game, o) {
    this.game = game;
    this.kind = o.kind || 'orb';
    this.pos = o.pos.clone();
    this.prev = o.pos.clone();
    this.vel = o.vel.clone();
    this.radius = o.radius ?? 0.3;
    this.damage = o.damage ?? 20;
    this.owner = o.owner || (PLAYER_KINDS.has(this.kind) ? 'player' : 'enemy');
    this.parryable = o.parryable ?? true;
    this.gravity = o.gravity ?? 0;
    this.life = o.life ?? 6;
    this.source = o.source || null;
    this.color = o.color ?? 0xff8a20;
    this.weapon = o.weapon || null;
    this.heated = !!o.heated;
    this.dead = false;
    this.parried = false;
    this.age = 0;
    this.hitPlayerOnce = false;
    this.bounces = o.bounces ?? 0;
    this.hitCd = new Map();
    this.group = new THREE.Group();
    this.group.position.copy(this.pos);
    this.buildMesh(o);
    game.scene.add(this.group);
  }

  buildMesh(o) {
    const T = this.game.tex;
    const k = this.kind;
    const add = (m) => { this.group.add(m); return m; };
    const glow = (color, size) => {
      this.glowMat = new THREE.SpriteMaterial({ map: T.glow, color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
      this.glow = add(new THREE.Sprite(this.glowMat));
      this.glow.scale.setScalar(size);
    };
    if (k === 'sword' || k === 'chainsaw') {
      this.mesh = add(o.mesh);
      return;
    }
    if (k === 'rocket') {
      this.mesh = new THREE.Group();
      const body = new THREE.Mesh(geo('rb', () => new THREE.CylinderGeometry(0.07, 0.07, 0.45, 8).rotateX(Math.PI / 2)), new THREE.MeshLambertMaterial({ color: 0xc0c4cc }));
      const tip = new THREE.Mesh(geo('rt', () => new THREE.ConeGeometry(0.07, 0.16, 8).rotateX(-Math.PI / 2).translate(0, 0, -0.3)), new THREE.MeshLambertMaterial({ color: 0xd02020 }));
      this.mesh.add(body, tip);
      add(this.mesh);
      glow(0xff8a30, 0.9);
      this.glow.position.z = 0.3;
      return;
    }
    if (k === 'cannonball') {
      this.mesh = add(new THREE.Mesh(geo('cb', () => new THREE.IcosahedronGeometry(0.35, 1)), new THREE.MeshLambertMaterial({ color: 0x2a2a30 })));
      glow(0x60ff80, 1.2);
      return;
    }
    if (k === 'nail') {
      this.coreMat = new THREE.MeshBasicMaterial({ color: this.heated ? 0xffa040 : 0xc8ccd4 });
      this.mesh = add(new THREE.Mesh(geo('nl', () => new THREE.BoxGeometry(0.03, 0.03, 0.3)), this.coreMat));
      if (this.heated) glow(0xff6020, 0.5);
      return;
    }
    if (k === 'saw') {
      this.mesh = add(new THREE.Mesh(geo('sw', () => new THREE.CylinderGeometry(0.28, 0.28, 0.03, 12)), new THREE.MeshLambertMaterial({ color: 0xd8dce4, emissive: 0x401010 })));
      glow(0xff4030, 0.9);
      return;
    }
    if (k === 'magnet') {
      this.mesh = add(new THREE.Mesh(geo('mg', () => new THREE.BoxGeometry(0.18, 0.18, 0.18)), new THREE.MeshLambertMaterial({ color: 0x3a60ff, emissive: 0x102060 })));
      glow(0x3a8aff, 1.4);
      return;
    }
    const g = k === 'pellet' ? geo('pl', () => new THREE.BoxGeometry(1, 1, 1)) : k === 'core' ? geo('co', () => new THREE.IcosahedronGeometry(1, 0)) : geo('or', () => new THREE.IcosahedronGeometry(1, 1));
    this.coreMat = new THREE.MeshBasicMaterial({ color: k === 'core' ? 0x9ad8ff : 0xfff2c0 });
    this.mesh = add(new THREE.Mesh(g, this.coreMat));
    const s = k === 'pellet' ? 0.12 : this.radius * 0.7;
    this.mesh.scale.set(s, s, k === 'pellet' ? 0.5 : s);
    glow(this.color, k === 'pellet' ? 0.6 : this.radius * 5);
  }

  setColor(c) {
    this.color = c;
    if (this.glowMat) this.glowMat.color.setHex(c);
  }

  parry(dir, speed) {
    this.owner = 'player';
    this.parried = true;
    this.vel.copy(dir).multiplyScalar(speed);
    this.damage = this.kind === 'orb' ? 4.5 : 3;
    this.life = 4;
    this.gravity = 0;
    this.setColor(0x9fd8ff);
    if (this.coreMat) this.coreMat.color.setHex(0xffffff);
    if (this.glow) this.glow.scale.multiplyScalar(1.4);
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
    if (this.kind === 'chainsaw') return this.updateChainsaw(dt);
    if (this.kind === 'magnet') return this.updateMagnet(dt);
    if (this.life <= 0) {
      if (this.kind === 'core' || this.kind === 'rocket') this.explode();
      return this.remove();
    }
    // Freezeframe: donmuş roketler hareket etmez
    if (this.kind === 'rocket' && game.weapons.freezeActive) {
      this.life += dt;
      this.glow.material.color.setHex(0x80d0ff);
      this.group.position.copy(this.pos);
      return;
    } else if (this.kind === 'rocket') this.glow.material.color.setHex(this.boosted ? 0xffffff : 0xff8a30);
    // Attractor mıknatısları çivileri çeker
    if (this.kind === 'nail' && game.weapons.magnets.length) {
      let best = null, bd = 196;
      for (const m of game.weapons.magnets) {
        if (m.dead) continue;
        const d2 = m.pos.distanceToSquared(this.pos);
        if (d2 < bd) { bd = d2; best = m; }
      }
      if (best) {
        const sp = this.vel.length();
        _d.subVectors(best.pos, this.pos).normalize().multiplyScalar(sp);
        this.vel.lerp(_d, Math.min(1, dt * 10));
      }
    }
    this.prev.copy(this.pos);
    this.vel.y -= this.gravity * dt;
    const sp = this.vel.length();
    const step = sp * dt;
    if (step > 0) {
      const inv = 1 / (sp || 1);
      const hit = game.world.raycast(this.pos.x, this.pos.y, this.pos.z, this.vel.x * inv, this.vel.y * inv, this.vel.z * inv, step + this.radius * 0.5);
      if (hit) {
        this.pos.set(hit.x, hit.y, hit.z);
        if (this.onWorldHit(hit)) return;
      } else this.pos.addScaledVector(this.vel, dt);
    }
    this.group.position.copy(this.pos);
    this.animateMesh(dt);

    if (this.owner === 'enemy') {
      const p = game.player;
      if (!p.dead) {
        // mermi yolu ile oyuncu gövde ekseni arası (tünelleme olmasın diye doğru parçası testi)
        _a.set(p.pos.x, p.pos.y + 0.35, p.pos.z);
        _b.set(p.pos.x, p.pos.y + Math.max(0.5, p.h - 0.3), p.pos.z);
        const rr = this.radius + p.r;
        if (segSegDist2(this.prev, this.pos, _a.clone(), _b.clone()) < rr * rr) {
          if (game.damagePlayer(this.damage, this.pos)) {
            game.fx.sparkBurst(this.pos, 10, 6, this.color, 0.3, 0.06);
            game.audio.play('projHit', this.pos);
            return this.remove();
          }
        }
      }
    } else {
      for (const e of game.enemies) {
        if (e.dead || e.state === 'spawn') continue;
        const hit = e.segmentHit(this.prev, this.pos, this.radius);
        if (!hit) continue;
        if (this.onEnemyHit(e, hit)) return;
      }
    }
  }

  animateMesh(dt) {
    const k = this.kind;
    if (k === 'core') {
      this.mesh.rotation.x += dt * 8;
      this.mesh.rotation.y += dt * 6;
      this.glow.scale.setScalar(this.radius * 5 * (1 + Math.sin(this.age * 30) * 0.2));
    } else if (k === 'rocket' || k === 'nail' || k === 'pellet') {
      this.group.lookAt(this.pos.x + this.vel.x, this.pos.y + this.vel.y, this.pos.z + this.vel.z);
      if (k === 'rocket' && Math.random() < dt * 40) this.game.fx.smoke(this.pos.clone().addScaledVector(this.vel, -0.012), 1, 0x8a8480, 0.35, 0.6, 0.3);
    } else if (k === 'saw') {
      this.mesh.rotation.y += dt * 40;
    } else if (k === 'cannonball') {
      this.mesh.rotation.x += dt * 10;
    } else if (this.glow) this.glow.material.rotation += dt * 4;
  }

  // true dönerse mermi yok oldu
  onEnemyHit(e, hit) {
    const game = this.game;
    const dir = this.vel.clone().normalize();
    const k = this.kind;
    if (k === 'core' || k === 'rocket') {
      this.pos.copy(hit.point);
      this.explode();
      this.remove();
      return true;
    }
    if (k === 'nail') {
      e.hit({ dmg: this.damage, part: hit.part, point: hit.point, dir, weapon: 'nailgun', knock: 0.6, headMult: 1.5, quiet: true });
      if (this.heated) e.burn = Math.max(e.burn || 0, 2.5);
      this.remove();
      return true;
    }
    if (k === 'saw' || k === 'cannonball') {
      const last = this.hitCd.get(e) || -1;
      if (this.age - last < (k === 'saw' ? 0.18 : 1)) return false;
      this.hitCd.set(e, this.age);
      if (k === 'saw') {
        e.hit({ dmg: this.damage, part: hit.part, point: hit.point, dir, weapon: 'nailgun', knock: 1, headMult: 1.5 });
        game.audio.play('enemyHit', hit.point);
      } else {
        const sp = this.vel.length();
        e.hit({ dmg: this.damage * Math.min(1.5, sp / 35), part: hit.part, point: hit.point, dir: dir.clone().setY(0.6), weapon: 'rocket', knock: 28, headMult: 1.5 });
        game.audio.play('punchHit', hit.point);
        game.shake(0.3);
        this.vel.multiplyScalar(0.6);
      }
      return false;
    }
    // parry edilmiş düşman mermisi
    e.hit({ dmg: this.damage, part: hit.part, point: hit.point, dir, weapon: this.parried ? 'parry' : 'revolver', knock: 10, parried: this.parried, headMult: 1.5 });
    game.fx.sparkBurst(this.pos, 16, 8, 0xbfe6ff, 0.35, 0.07);
    game.audio.play('projHit', this.pos);
    if (this.parried && this.kind === 'orb') game.explode(this.pos, 2.5, 1.5, { owner: 'player', playerDmg: 0, fromParry: true, small: true });
    this.remove();
    return true;
  }

  // true dönerse işlem bitti
  onWorldHit(hit) {
    const game = this.game;
    const n = new THREE.Vector3(hit.nx, hit.ny, hit.nz);
    const k = this.kind;
    if (k === 'core' || k === 'rocket') {
      this.pos.addScaledVector(n, 0.2);
      this.explode();
      this.remove();
      return true;
    }
    if (k === 'saw' && this.bounces > 0) {
      this.bounces--;
      const v = this.vel;
      const dot = v.dot(n);
      v.addScaledVector(n, -2 * dot);
      this.pos.addScaledVector(n, 0.05);
      game.fx.sparkDir(this.pos, n, 8, 7, 0xffc060, 0.3, 0.05, 0.6);
      game.audio.play('walljump', this.pos, { vol: 0.6 });
      this.group.position.copy(this.pos);
      return true;
    }
    if (k === 'cannonball') {
      game.explode(this.pos, 3, 1.5, { owner: 'player', playerDmg: 10, knock: 12, weapon: 'rocket' });
      this.remove();
      return true;
    }
    if (k === 'nail') {
      if (Math.random() < 0.3) game.fx.bulletHole(hit.x, hit.y, hit.z, hit.nx, hit.ny, hit.nz, 0.08);
      if (Math.random() < 0.5) game.fx.sparkDir(this.pos, n, 2, 4, 0xffd080, 0.15, 0.03, 0.8);
      this.remove();
      return true;
    }
    game.fx.sparkDir(this.pos, n, 8, 6, this.color, 0.3, 0.06, 0.8);
    if (this.parried) game.explode(this.pos, 2.5, 1.5, { owner: 'player', playerDmg: 0, fromParry: true, small: true });
    this.remove();
    return true;
  }

  explode() {
    const game = this.game;
    if (this.kind === 'core') {
      const b = !!this.boosted;
      game.explode(this.pos, b ? 7.5 : 5.5, b ? 5 : 3.5, { owner: 'player', playerDmg: 30, knock: 18, weapon: 'shotgun' });
    } else if (this.kind === 'rocket') {
      const b = !!this.boosted;
      game.explode(this.pos, b ? 6.5 : 5, b ? 5 : 3.5, { owner: 'player', playerDmg: 28, knock: 22, weapon: 'rocket' });
    }
  }

  // eski ad (silahlar hâlâ çağırıyor)
  explodeCore() {
    this.explode();
  }

  // ---- Mıknatıs (Attractor): yüzeye ya da düşmana yapışır ----
  updateMagnet(dt) {
    const game = this.game;
    if (this.life <= 0) return this.remove();
    if (this.stuckTo) {
      if (this.stuckTo.dead) { this.stuckTo = null; this.vel.set(0, 0, 0); this.gravity = 12; }
      else this.pos.copy(this.stuckTo.center()).add(this.stuckOff);
    } else if (!this.stuck) {
      this.prev.copy(this.pos);
      this.vel.y -= 12 * dt;
      const sp = this.vel.length();
      const inv = 1 / (sp || 1);
      const hit = game.world.raycast(this.pos.x, this.pos.y, this.pos.z, this.vel.x * inv, this.vel.y * inv, this.vel.z * inv, sp * dt + 0.1);
      if (hit) { this.pos.set(hit.x + hit.nx * 0.1, hit.y + hit.ny * 0.1, hit.z + hit.nz * 0.1); this.stuck = true; game.audio.play('empty', this.pos); }
      else {
        this.pos.addScaledVector(this.vel, dt);
        for (const e of game.enemies) {
          if (e.dead) continue;
          if (e.segmentHit(this.prev, this.pos, 0.2)) { this.stuckTo = e; this.stuckOff = this.pos.clone().sub(e.center()); break; }
        }
      }
    }
    this.group.position.copy(this.pos);
    this.mesh.rotation.y += dt * 3;
    this.glow.scale.setScalar(1.2 + Math.sin(this.age * 8) * 0.3);
  }

  // ---- Oyuncunun zincirli testeresi (Sawed-On): gider, düşmanları biçer, geri döner ----
  updateChainsaw(dt) {
    const game = this.game;
    const p = game.player;
    this.mesh.rotation.y += dt * 25;
    if (this.phase === undefined) { this.phase = 'out'; this.outT = 0; }
    if (this.phase === 'out') {
      this.outT += dt;
      const sp = this.vel.length(), inv = 1 / (sp || 1);
      const hit = game.world.raycast(this.pos.x, this.pos.y, this.pos.z, this.vel.x * inv, this.vel.y * inv, this.vel.z * inv, sp * dt + 0.4);
      if (hit || this.outT > 0.65) {
        if (hit) { game.fx.sparkBurst(new THREE.Vector3(hit.x, hit.y, hit.z), 12, 8, 0xffc040, 0.3, 0.06); game.audio.play('projHit', this.pos); }
        this.phase = 'back';
      } else { this.prev.copy(this.pos); this.pos.addScaledVector(this.vel, dt); }
    } else {
      const target = p.eyePos();
      _d.subVectors(target, this.pos);
      const d = _d.length();
      if (d < 1.4 || this.age > 5) { game.weapons.sawReturned(); return this.remove(); }
      _d.multiplyScalar(40 / d);
      this.vel.lerp(_d, Math.min(1, dt * 6));
      this.prev.copy(this.pos);
      this.pos.addScaledVector(this.vel, dt);
    }
    this.group.position.copy(this.pos);
    if (Math.random() < dt * 30) game.fx.sparkBurst(this.pos, 1, 3, 0xffa030, 0.25, 0.05);
    for (const e of game.enemies) {
      if (e.dead || e.state === 'spawn') continue;
      if (e.center().distanceToSquared(this.pos) > (e.r + 1.1) ** 2) continue;
      const last = this.hitCd.get(e) ?? -1;
      if (this.age - last < 0.12) continue;
      this.hitCd.set(e, this.age);
      e.hit({ dmg: 0.4, part: 'body', point: this.pos.clone(), dir: this.vel.clone().normalize(), weapon: 'shotgun', knock: 2 });
      game.audio.play('chainsaw', this.pos, { vol: 0.5 });
    }
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
      this.vel.lerp(_d.multiplyScalar(34), Math.min(1, dt * 6));
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
    const apex = Math.abs(this.vel.y) < 3;
    this.glow.scale.setScalar(apex ? 1.5 + Math.sin(this.age * 40) * 0.2 : 0.9);
  }

  kill() {
    if (!this.alive) return;
    this.alive = false;
    this.game.scene.remove(this.group);
  }
}
