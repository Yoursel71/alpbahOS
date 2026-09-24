// KATMAN 1 (ARAF) düşmanları: Drone, Streetcleaner, Hideous Mass ve boss V2.
// Modeller enemies.js'teki eklem/kutu yardımcılarıyla kurulur; ENEMY_TYPES kaydına eklenirler.
import * as THREE from 'three';
import { Enemy, ENEMY_TYPES, Shockwave, buildHumanoid, bgeo, cgeo, joint, limb, part } from './enemies.js';
import { Projectile } from './projectiles.js';
import { clamp, rand, chance, wrapAngle, yawTo } from './util.js';
import { difficulty } from './settings.js';

const _v = new THREE.Vector3();
const _w = new THREE.Vector3();

// Oyuncuya doğru (hafif öngörülü) atış yönü
function aimAt(game, from, speed, lead = 0.4, yOff = 0.6) {
  const p = game.player;
  const target = new THREE.Vector3(p.pos.x, p.pos.y + p.h * yOff, p.pos.z);
  const t = from.distanceTo(target) / speed;
  target.addScaledVector(p.vel, t * lead);
  return target.sub(from).normalize();
}

// ---------------------------------------------------------------------------
// DRONE: havada dolanan küçük makine. Gözü parlayınca iki mavi küre atar (savuşturulabilir).
// Ölünce oyuncuya doğru düşer ve çarptığı yerde patlar — yumrukla geri yollanabilir.
export class Drone extends Enemy {
  init() {
    const T = this.game.tex;
    this.type = 'drone';
    this.name = 'DRONE';
    this.maxHp = 1.2;
    this.r = 0.5;
    this.h = 0.9;
    this.flying = true;
    this.killPts = 60;
    this.knockMul = 1.4;
    this.firstState = 'fly';
    this.speed = 7 * difficulty().speed;
    this.orbitDir = chance(0.5) ? 1 : -1;
    this.orbitT = rand(2, 4);
    this.atkCd = rand(1.2, 2.6);
    this.dodgeCd = rand(1, 2);
    this.alt = rand(3, 5);
    this.tint = 1;
    const shell = this.mat(T.metal, 0xb8c0cc, 0.12);
    const dark = this.mat(T.machine, 0x3a3e48, 0.08);
    const g = new THREE.Group();
    g.position.y = 0.45;
    this.root.add(g);
    this.body = g;
    part(g, bgeo(0.72, 0.5, 0.72), shell, 0, 0, 0);
    part(g, bgeo(0.5, 0.18, 0.5), dark, 0, 0.32, 0);
    part(g, bgeo(0.42, 0.14, 0.42), dark, 0, -0.3, 0);
    // yan kanatçıklar
    this.fins = [];
    for (const [x, z] of [[-0.5, 0], [0.5, 0], [0, 0.5]]) {
      const f = joint(g, x, 0, z);
      part(f, bgeo(x ? 0.3 : 0.5, 0.05, x ? 0.5 : 0.3), dark, x * 0.25, 0, z * 0.25);
      this.fins.push(f);
    }
    // anten
    part(g, cgeo(0.02, 0.4, 4), dark, 0.15, 0.55, 0.1);
    // göz
    this.eyeMat = new THREE.MeshBasicMaterial({ color: 0x40a0ff });
    const eye = part(g, bgeo(0.3, 0.2, 0.06), this.eyeMat, 0, 0.02, -0.38, 0, 0, 0, true);
    eye.userData.noGib = true;
    this.eyeGlow = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.glow, color: 0x3a8aff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    this.eyeGlow.position.set(0, 0.02, -0.45);
    this.eyeGlow.scale.setScalar(0.5);
    g.add(this.eyeGlow);
    this.muzzle = joint(g, 0, 0, -0.5);
    this.addSphere(g, [0, 0, 0], 0.5, 'body');
    this.addSphere(g, [0, 0.02, -0.36], 0.2, 'head');
  }

  think(dt) {
    const i = this.playerInfo();
    const p = this.game.player;
    const aggro = difficulty().aggro;
    this.atkCd -= dt;
    this.dodgeCd -= dt;
    const wantY = p.pos.y + this.alt + Math.sin(this.time * 2.1) * 0.5;
    this.vel.y = clamp((wantY - this.pos.y) * 2.5, -7, 7);
    switch (this.state) {
      case 'fly': {
        this.faceYaw(yawTo(i.dx, i.dz), 5, dt);
        this.orbitT -= dt;
        if (this.orbitT <= 0) { this.orbitT = rand(2, 4); this.orbitDir *= -1; this.alt = rand(2.5, 5.5); }
        const want = i.dist > 18 ? 1 : i.dist < 9 ? -1 : 0;
        const sp = this.speed;
        this.accelTo(i.dx * want * sp - i.dz * this.orbitDir * sp * 0.8, i.dz * want * sp + i.dx * this.orbitDir * sp * 0.8, 10, dt);
        if (this.blocked > 0.3) { this.orbitDir *= -1; this.blocked = 0; }
        // oyuncu nişan alınca yana kaçış
        if (this.dodgeCd <= 0 && i.dist < 40) {
          const a = p.aimDir(_v);
          const to = this.center(_w).sub(p.eyePos()).normalize();
          if (a.dot(to) > 0.985) {
            this.dodgeCd = rand(1.6, 3) / aggro;
            const s = chance(0.5) ? 1 : -1;
            this.vel.x += -i.dz * s * 13;
            this.vel.z += i.dx * s * 13;
            this.game.audio.play('dash', this.pos, { vol: 0.5, rate: 1.4 });
          }
        }
        if (this.atkCd <= 0 && this.canSee && i.dist < 45) {
          this.setState('charge');
          this.game.audio.play('orbCharge', this.pos, { rate: 1.6, exactRate: true });
        }
        break;
      }
      case 'charge': {
        this.faceYaw(yawTo(i.dx, i.dz), 8, dt);
        this.accelTo(0, 0, 12, dt);
        const dur = 0.6 / aggro;
        this.eyeGlow.scale.setScalar(0.5 + 1.2 * clamp(this.st / dur, 0, 1));
        if (this.st >= dur) { this.state = 'shoot'; this.st = 0; this.shots = 0; }
        break;
      }
      case 'shoot': {
        this.faceYaw(yawTo(i.dx, i.dz), 8, dt);
        while (this.shots < 2 && this.st >= this.shots * 0.16) { this.fire(); this.shots++; }
        if (this.st > 0.4) { this.setState('fly'); this.atkCd = rand(2, 3.4) / aggro; this.eyeGlow.scale.setScalar(0.5); }
        break;
      }
    }
  }

  fire() {
    const game = this.game;
    const from = this.muzzle.getWorldPosition(new THREE.Vector3());
    const speed = 30 * difficulty().speed;
    const dir = aimAt(game, from, speed, 0.3);
    game.addProjectile(new Projectile(game, { pos: from, vel: dir.multiplyScalar(speed), radius: 0.28, damage: 15 * difficulty().dmg, color: 0x3a8aff, source: this }));
    game.audio.play('schismShot', from, { rate: 1.5 });
  }

  // Ölünce: parçalanmak yerine oyuncuya doğru dalış, çarpınca patlama
  deathMode(info) {
    if (info.explosion || info.dmg >= 99 || info.weapon === 'rail' || info.fromDive) return 'gib';
    return 'dive';
  }

  die(info, wasFull, dmg) {
    if (this.dead) return;
    if (this.deathMode(info) === 'gib') {
      super.die(info, wasFull, dmg);
      this.game.explode(this.center(), 3.2, 2, { owner: 'player', playerDmg: info.fromDive ? 22 : 0, knock: 10, weapon: 'explosion' });
      return;
    }
    // dalış: öldü sayılır ama model bir süre daha düşer
    super.die({ ...info, silent: false }, wasFull, dmg);
    const game = this.game;
    const p = game.player;
    const from = this.center();
    const to = new THREE.Vector3(p.pos.x, p.pos.y + 0.8, p.pos.z);
    const dir = to.sub(from).normalize();
    // yığılan ceset yerine düşen gövde mermisi
    const corpseIdx = game.corpses.indexOf(this);
    if (corpseIdx >= 0) game.corpses.splice(corpseIdx, 1);
    game.scene.remove(this.root);
    const mesh = this.body;
    mesh.position.set(0, 0, 0);
    const pr = new Projectile(game, { kind: 'sword', mesh, pos: from, vel: dir.multiplyScalar(16), radius: 0.5, damage: 0, source: null });
    pr.kind = 'drone';
    pr.parryable = true;
    pr.gravity = 9;
    pr.life = 3;
    pr.update = (dt2) => {
      pr.age += dt2;
      pr.life -= dt2;
      pr.prev.copy(pr.pos);
      if (pr.homeTarget && !pr.homeTarget.dead) {
        const sp = pr.vel.length();
        _w.subVectors(pr.homeTarget.center(_v), pr.pos).normalize().multiplyScalar(sp);
        pr.vel.lerp(_w, Math.min(1, dt2 * (pr.homeRate || 4)));
      }
      pr.vel.y -= pr.gravity * dt2;
      pr.pos.addScaledVector(pr.vel, dt2);
      pr.group.position.copy(pr.pos);
      mesh.rotation.x += dt2 * 9;
      mesh.rotation.z += dt2 * 6;
      if (Math.random() < dt2 * 30) game.fx.smoke(pr.pos, 1, 0x302a28, 0.4, 0.7, 0.8);
      let boom = pr.life <= 0;
      const sp = pr.vel.length() || 1;
      const hit = game.world.raycast(pr.prev.x, pr.prev.y, pr.prev.z, pr.vel.x / sp, pr.vel.y / sp, pr.vel.z / sp, sp * dt2 + 0.4);
      if (hit) boom = true;
      if (pr.owner === 'player') {
        for (const e of game.enemies) if (!e.dead && e.segmentHit(pr.prev, pr.pos, 0.5)) boom = true;
      } else if (pr.pos.distanceTo(_v.set(p.pos.x, p.pos.y + 0.8, p.pos.z)) < 1.2) boom = true;
      if (boom) {
        const parried = pr.owner === 'player';
        game.explode(pr.pos, parried ? 5 : 3.6, parried ? 4 : 2, { owner: 'player', playerDmg: parried ? 0 : 24, knock: 14, weapon: parried ? 'parry' : 'explosion' });
        pr.remove();
      }
    };
    pr.parry = (d, speed) => {
      game.stats.droneParries = (game.stats.droneParries || 0) + 1;
      pr.owner = 'player';
      pr.parried = true;
      pr.vel.copy(d).multiplyScalar(speed * 1.2);
      pr.gravity = 0;
      pr.life = 3;
    };
    game.addProjectile(pr);
  }

  animate(dt) {
    const g = this.body;
    const hsp = Math.hypot(this.vel.x, this.vel.z);
    g.rotation.z = clamp(-this.vel.x * 0.02, -0.3, 0.3) + Math.sin(this.time * 3) * 0.05;
    g.rotation.x = clamp(hsp * 0.02, 0, 0.3);
    this.fins.forEach((f, k) => { f.rotation.z = Math.sin(this.time * 20 + k) * 0.25; });
    const charging = this.state === 'charge' || this.state === 'shoot';
    this.eyeMat.color.setHex(charging && Math.sin(this.time * 40) > 0 ? 0xffffff : 0x40a0ff);
  }
}

// ---------------------------------------------------------------------------
// STREETCLEANER: gaz maskeli, sırt tanklı alev makinesi taşıyıcı. Koşarak yaklaşır, yakından
// alev püskürtür, üzerine nişan alınca yana kaçar. Sırttaki tank zayıf nokta: vurulursa patlar.
export class Streetcleaner extends Enemy {
  init() {
    const T = this.game.tex;
    this.type = 'streetcleaner';
    this.name = 'STREETCLEANER';
    this.maxHp = 3;
    this.r = 0.45;
    this.h = 2.0;
    this.speed = 8.5 * difficulty().speed;
    this.killPts = 90;
    this.firstState = 'chase';
    this.dodgeCd = rand(1, 2);
    this.flameT = 0;
    const suit = this.mat(T.clothW, 0xd8b030);
    const dark = this.mat(T.machine, 0x2e3036);
    const rubber = this.mat(T.skinW, 0x24262a);
    const tankM = this.mat(T.metal, 0xc83a20, 0.2);
    this.H = buildHumanoid({ skin: suit, dark: rubber, hunch: 0.12, torsoW: 0.46, torsoH: 0.6, torsoD: 0.3, headS: 0.3, armL: 1.02, legL: 1.05, scale: 1.05, taper: 0.9 });
    const J = this.H.J, d = this.H.dims;
    // gaz maskesi
    part(J.head, bgeo(0.32, 0.3, 0.32), rubber, 0, 0.16, 0);
    const lens = new THREE.MeshBasicMaterial({ color: 0xffd060 });
    for (const x of [-0.08, 0.08]) part(J.head, cgeo(0.06, 0.04, 8), lens, x, 0.2, -0.17, Math.PI / 2, 0, 0, true);
    part(J.head, cgeo(0.07, 0.16, 6), dark, 0, 0.05, -0.2, Math.PI / 2 + 0.4);
    // sırt tankı (zayıf nokta)
    this.tank = joint(J.spine, 0, d.torsoH * 0.55, d.torsoD / 2 + 0.14);
    for (const x of [-0.1, 0.1]) part(this.tank, cgeo(0.1, 0.55, 8), tankM, x, 0, 0);
    part(this.tank, bgeo(0.3, 0.08, 0.14), dark, 0, 0.3, 0);
    // alev makinesi (sağ el) ve hortum
    const gun = new THREE.Group();
    part(gun, bgeo(0.1, 0.1, 0.62), dark, 0, 0, -0.26);
    part(gun, cgeo(0.06, 0.18, 6), tankM, 0, -0.08, -0.12, Math.PI / 2);
    this.nozzle = joint(gun, 0, 0, -0.6);
    this.pilot = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.glow, color: 0x40a0ff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    this.pilot.scale.setScalar(0.25);
    this.nozzle.add(this.pilot);
    gun.position.set(0, -0.06, 0);
    gun.rotation.x = Math.PI / 2;
    J.haR.add(gun);
    this.gun = gun;
    this.flameSpr = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.glow, color: 0xff7a20, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    this.flameSpr.visible = false;
    this.game.scene.add(this.flameSpr);
    this.root.add(this.H.root);
    this.humanoidSpheres(this.H, 1.05);
    // tank: "head" türü → kritik vuruş; ölümde patlama
    this.addSphere(this.tank, [0, 0, 0], 0.24, 'head');
  }

  think(dt) {
    const i = this.playerInfo();
    const p = this.game.player;
    const aggro = difficulty().aggro;
    this.dodgeCd -= dt;
    switch (this.state) {
      case 'chase': {
        this.faceYaw(yawTo(i.dx, i.dz), 9, dt);
        let tx = i.dx * this.speed, tz = i.dz * this.speed;
        if (i.dist < 4) { tx *= 0.2; tz *= 0.2; }
        if (this.grounded && !this.groundAhead(i.dx, i.dz)) { tx = 0; tz = 0; }
        this.accelTo(tx, tz, 34, dt);
        if (this.grounded && this.blocked > 0.4) { this.vel.y = 10; this.grounded = false; this.blocked = 0; }
        if (this.dodgeCd <= 0 && i.dist > 5 && i.dist < 30 && this.grounded) {
          const to = this.center(_w).sub(p.eyePos()).normalize();
          if (p.aimDir(_v).dot(to) > 0.99) {
            this.dodgeCd = rand(1.4, 2.6) / aggro;
            const s = chance(0.5) ? 1 : -1;
            this.vel.x = -i.dz * s * 15;
            this.vel.z = i.dx * s * 15;
            this.setState('dodge');
            this.game.audio.play('dash', this.pos, { vol: 0.6, rate: 1.2 });
            break;
          }
        }
        if (i.dist < 7.5 && this.canSee && Math.abs(i.dy) < 3) {
          this.setState('flame');
          this.game.audio.play('windup', this.pos, { rate: 1.6, exactRate: true });
        }
        break;
      }
      case 'dodge': {
        this.accelTo(0, 0, 30, dt);
        if (this.st > 0.35) this.setState('chase');
        break;
      }
      case 'flame': {
        this.faceYaw(yawTo(i.dx, i.dz), 4, dt);
        this.accelTo(i.dx * this.speed * 0.25, i.dz * this.speed * 0.25, 20, dt);
        const on = this.st > 0.2;
        if (on) this.spray(dt);
        if (this.st > 1.9 || (i.dist > 11 && this.st > 0.6)) { this.setState('chase'); this.dodgeCd = Math.max(this.dodgeCd, 0.6); }
        break;
      }
    }
    if (this.state !== 'flame') this.flameOff();
  }

  spray(dt) {
    const game = this.game;
    const p = game.player;
    const from = this.nozzle.getWorldPosition(new THREE.Vector3());
    const f = this.forward();
    this.flameSpr.visible = true;
    this.flameSpr.position.copy(from).addScaledVector(f, 2.2);
    this.flameSpr.scale.setScalar(3 + Math.random() * 1.2);
    this.flameSpr.material.rotation += dt * 6;
    for (let k = 0; k < 2; k++) game.fx.sparkDir(from, _v.set(f.x, rand(-0.05, 0.12), f.z), 3, rand(12, 17), Math.random() < 0.5 ? 0xff7a20 : 0xffc040, 0.45, 0.14, 0.25);
    if (Math.random() < dt * 12) game.fx.smoke(from.clone().addScaledVector(f, 4), 1, 0x3a3230, 0.7, 0.9, 1.4);
    game.audio.loop('flame' + this.uid(), true, { buffer: 'flame', vol: 0.25 });
    this.flameT -= dt;
    if (this.flameT <= 0) {
      this.flameT = 0.2;
      const dx = p.pos.x - from.x, dz = p.pos.z - from.z;
      const dist = Math.hypot(dx, dz);
      if (dist < 7.2 && Math.abs(p.pos.y + 0.8 - from.y) < 2.4 && (dx * f.x + dz * f.z) / (dist || 1) > 0.88) {
        game.damagePlayer(5 * difficulty().dmg, from, true);
      }
      // yakındaki diğer düşmanları da yakar
      for (const e of game.enemies) {
        if (e === this || e.dead) continue;
        const ex = e.pos.x - from.x, ez = e.pos.z - from.z, ed = Math.hypot(ex, ez);
        if (ed < 6 && (ex * f.x + ez * f.z) / (ed || 1) > 0.85) e.burn = Math.max(e.burn || 0, 1.5);
      }
    }
  }

  uid() { return this._uid || (this._uid = Math.floor(Math.random() * 1e9)); }

  flameOff() {
    if (this.flameSpr.visible) {
      this.flameSpr.visible = false;
      this.game.audio.loop('flame' + this.uid(), false);
    }
  }

  onHurt() { if (this.state === 'flame' && chance(0.3)) this.setState('chase'); }

  die(info, wasFull, dmg) {
    this.flameOff();
    this.game.scene.remove(this.flameSpr);
    const tankShot = info.part === 'head' && !this.dead;
    super.die(info, wasFull, dmg);
    if (tankShot) {
      this.game.explode(this.center(), 4.5, 3, { owner: 'player', playerDmg: 18, knock: 16, weapon: info.weapon || 'explosion' });
      this.game.style.add('TANK PATLADI', 80, null);
      this.game.stats.tanks = (this.game.stats.tanks || 0) + 1;
    }
  }

  removeSilently() {
    this.flameOff();
    this.game.scene.remove(this.flameSpr);
    super.removeSilently();
  }

  deathMode(info, dmg) {
    if (info.part === 'head') return 'gib';
    return super.deathMode(info, dmg);
  }

  animate(dt) {
    this.k = 1 - Math.exp(-16 * dt);
    const H = this.H, J = H.J;
    const hsp = Math.hypot(this.vel.x, this.vel.z);
    this.walkPhase += hsp * dt * 1.3;
    const amt = clamp(hsp / 8, 0, 1);
    this.walkPose(H, amt, 0.3, 0);
    // silahı iki elle ileri tutar
    this.rot(J.shR, -1.25, 0, 0.15);
    this.rot(J.elR, 0.25);
    this.rot(J.shL, -1.0, 0.4, -0.2);
    this.rot(J.elL, 0.9);
    if (this.state === 'flame') {
      this.rot(J.spine, 0.12, Math.sin(this.time * 7) * 0.12);
    } else if (this.state === 'dodge') {
      this.rot(J.spine, 0.2, 0, 0.3);
    } else {
      this.rot(J.spine, -0.06 - amt * 0.12, 0);
      if (!this.grounded && this.state !== 'spawn') this.airPose(H);
    }
    this.pilot.material.color.setHex(this.state === 'flame' ? 0xffa040 : 0x40a0ff);
  }
}

// ---------------------------------------------------------------------------
// HIDEOUS MASS (mini boss): yerde sürünen dev et kütlesi. Yukarı havan küreleri (patlar),
// hızlı zıpkın (savuşturulabilir) ve yakındaysa kuyruk darbesi (halka dalga).
export class HideousMass extends Enemy {
  init() {
    const T = this.game.tex;
    this.type = 'hideousmass';
    this.name = 'HIDEOUS MASS';
    this.maxHp = 28;
    this.r = 1.6;
    this.h = 2.6;
    this.big = true;
    this.boss = true;
    this.killPts = 450;
    this.knockMul = 0.04;
    this.parryDmg = 4;
    this.parryStun = 1.1;
    this.firstState = 'crawl';
    this.spawnDur = 1.0;
    this.speed = 2.6 * difficulty().speed;
    this.atkCd = 1.6;
    this.tint = 1;
    this.lastAtk = '';
    const flesh = this.mat(T.flesh, 0xe8a8a0, 0.16);
    const skin = this.mat(T.skinW, 0xc89080, 0.12);
    const bone = this.mat(T.bone, 0xf4e6c4, 0.12);
    const dark = this.mat(T.rock, 0x5a2a28, 0.1);
    const body = new THREE.Group();
    this.root.add(body);
    this.bodyG = body;
    // gövde: arkaya doğru incelen yığın
    this.segs = [];
    for (let k = 0; k < 5; k++) {
      const s = joint(body, 0, 0, k * 1.1 - 0.4);
      const w = 2.6 - k * 0.38, hh = 2.1 - k * 0.3;
      part(s, bgeo(w, hh, 1.3), k % 2 ? skin : flesh, 0, hh / 2, 0);
      if (k < 4) for (const x of [-w / 2 + 0.2, w / 2 - 0.2]) part(s, cgeo(0.08, 0.5, 4), bone, x, hh + 0.1, 0, 0.3, 0, x > 0 ? -0.4 : 0.4);
      this.segs.push(s);
    }
    // kuyruk
    this.tail = joint(this.segs[4], 0, 0.6, 0.6);
    limb(this.tail, 0.7, 2.4, 0.7, dark, 1.1);
    part(this.tail, cgeo(0.35, 0.8, 5), bone, 0, 2.6, 0);
    // yüz: iç içe açılan çene
    this.head = joint(body, 0, 1.2, -1.2);
    part(this.head, bgeo(1.6, 1.2, 0.6), flesh, 0, 0.1, 0);
    const black = new THREE.MeshBasicMaterial({ color: 0x0a0204 });
    part(this.head, bgeo(1.0, 0.5, 0.1), black, 0, 0.05, -0.31, 0, 0, 0, true);
    this.eyeMat = new THREE.MeshBasicMaterial({ color: 0xff5020 });
    for (const x of [-0.45, 0.45]) part(this.head, bgeo(0.2, 0.14, 0.05), this.eyeMat, x, 0.5, -0.32, 0, 0, 0, true);
    this.mouth = joint(this.head, 0, 0.05, -0.4);
    this.mouthGlow = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.glow, color: 0xff6020, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    this.mouthGlow.scale.setScalar(0.1);
    this.mouth.add(this.mouthGlow);
    // sırttaki havan delikleri
    this.vents = [];
    for (const [x, z] of [[-0.6, 0], [0.6, 0.2], [0, 1.1]]) {
      const v = joint(body, x, 2.0, z);
      part(v, cgeo(0.22, 0.3, 6), dark, 0, 0, 0);
      this.vents.push(v);
    }
    this.addSphere(body, [0, 1.1, 0.2], 1.35, 'body');
    this.addSphere(body, [0, 0.9, 2.0], 1.0, 'body');
    this.addSphere(this.head, [0, 0.2, -0.2], 0.62, 'head');
  }

  think(dt) {
    const i = this.playerInfo();
    const aggro = difficulty().aggro * (this.enraged ? 1.3 : 1);
    const p = this.game.player;
    this.atkCd -= dt;
    if (!this.enraged && this.hp < this.maxHp * 0.5) {
      this.enraged = true;
      this.game.audio.play('bossRoar', this.pos, { rate: 0.7, exactRate: true });
      this.game.hud.message('HIDEOUS MASS ÖFKELENDİ', 1.4);
    }
    switch (this.state) {
      case 'crawl': {
        this.faceYaw(yawTo(i.dx, i.dz), 1.4, dt);
        const f = this.forward();
        const want = i.dist > 9 ? 1 : 0;
        this.accelTo(f.x * this.speed * want, f.z * this.speed * want, 6, dt);
        if (this.atkCd <= 0) {
          let next;
          if (i.dist < 7 && this.lastAtk !== 'tail') next = 'tailWind';
          else if (this.lastAtk === 'mortar' || (this.canSee && chance(0.5))) next = 'harpoonWind';
          else next = 'mortarWind';
          this.lastAtk = next === 'tailWind' ? 'tail' : next === 'harpoonWind' ? 'harpoon' : 'mortar';
          this.setState(next);
          this.game.audio.play(next === 'harpoonWind' ? 'windup' : 'orbCharge', this.pos, { rate: 0.6, exactRate: true, range: 80 });
        }
        break;
      }
      case 'mortarWind': {
        this.accelTo(0, 0, 10, dt);
        if (this.st > 0.7 / aggro) { this.state = 'mortar'; this.st = 0; this.shots = 0; }
        break;
      }
      case 'mortar': {
        const n = this.enraged ? 5 : 3;
        while (this.shots < n && this.st >= this.shots * 0.22) { this.fireMortar(this.shots, n); this.shots++; }
        if (this.st > n * 0.22 + 0.5) { this.setState('crawl'); this.atkCd = rand(1.6, 2.4) / aggro; }
        break;
      }
      case 'harpoonWind': {
        this.faceYaw(yawTo(i.dx, i.dz), 3, dt);
        this.accelTo(0, 0, 10, dt);
        const dur = 0.9 / aggro;
        this.mouthGlow.scale.setScalar(0.3 + 2 * clamp(this.st / dur, 0, 1));
        if (this.st > dur - 0.3) this.setParryable(false);
        if (this.st >= dur) { this.fireHarpoon(); this.state = 'harpoon'; this.st = 0; }
        break;
      }
      case 'harpoon': {
        this.mouthGlow.scale.setScalar(Math.max(0.1, 2.3 - this.st * 6));
        if (this.st > 0.6) { this.setState('crawl'); this.atkCd = rand(1.4, 2.2) / aggro; }
        break;
      }
      case 'tailWind': {
        this.accelTo(0, 0, 10, dt);
        if (this.st > 0.85 / aggro) {
          this.state = 'tail'; this.st = 0;
          const pos = this.pos.clone();
          this.game.shocks.push(new Shockwave(this.game, pos, { dmg: 20, speed: 15, max: 20, color: 0xff6030 }));
          if (this.enraged) this.game.schedule(0.35, () => { if (!this.dead) this.game.shocks.push(new Shockwave(this.game, pos, { dmg: 20, speed: 19, max: 22, color: 0xff3020 })); });
          this.game.fx.explosionFX(this.tail.getWorldPosition(new THREE.Vector3()), 2);
          this.game.audio.play('slam', this.pos, { range: 60 });
          this.game.shake(0.5);
        }
        break;
      }
      case 'tail': {
        if (this.st > 0.7) { this.setState('crawl'); this.atkCd = rand(1.5, 2.3) / aggro; }
        break;
      }
    }
    void p;
  }

  fireMortar(k, n) {
    const game = this.game;
    const p = game.player;
    const v = this.vents[k % this.vents.length];
    const from = v.getWorldPosition(new THREE.Vector3()).add(new THREE.Vector3(0, 0.3, 0));
    // oyuncunun etrafına dağılan hedef, sabit uçuş süresi
    const T = 1.35;
    const ang = (k / n) * Math.PI * 2 + rand(-0.3, 0.3);
    const spread = k === 0 ? 0 : rand(2, 4.5);
    const tx = p.pos.x + Math.cos(ang) * spread + p.vel.x * 0.4, tz = p.pos.z + Math.sin(ang) * spread + p.vel.z * 0.4;
    const g = 22;
    const vel = new THREE.Vector3((tx - from.x) / T, (p.pos.y - from.y + 0.5 * g * T * T) / T, (tz - from.z) / T);
    const pr = new Projectile(game, { pos: from, vel, radius: 0.5, damage: 18 * difficulty().dmg, color: 0xff5020, gravity: g, source: this, life: 5 });
    pr.explosive = true;
    game.addProjectile(pr);
    game.audio.play('orbThrow', from, { rate: 0.7 });
    game.fx.smoke(from, 3, 0x6a3028, 0.6, 0.8, 1.5);
  }

  fireHarpoon() {
    const game = this.game;
    const from = this.mouth.getWorldPosition(new THREE.Vector3());
    const speed = 48 * difficulty().speed;
    const dir = aimAt(game, from, speed, 0.25, 0.55);
    game.addProjectile(new Projectile(game, { kind: 'pellet', pos: from, vel: dir.multiplyScalar(speed), radius: 0.4, damage: 30 * difficulty().dmg, color: 0xffd0a0, source: this }));
    game.audio.play('bossShotgun', from, { rate: 0.7 });
  }

  animate(dt) {
    const t = this.time;
    const hsp = Math.hypot(this.vel.x, this.vel.z);
    this.segs.forEach((s, k) => {
      s.position.y = Math.max(0, Math.sin(t * 3 - k * 0.9)) * 0.12 * (0.3 + hsp);
      s.scale.x = 1 + Math.sin(t * 2 - k) * 0.03;
    });
    let tailX = -0.3 + Math.sin(t * 1.3) * 0.1;
    if (this.state === 'tailWind') tailX = -0.3 - 1.2 * clamp(this.st / 0.6, 0, 1);
    else if (this.state === 'tail') tailX = -1.5 + 2.4 * clamp(this.st / 0.12, 0, 1);
    this.tail.rotation.x += (tailX - this.tail.rotation.x) * Math.min(1, dt * (this.state === 'tail' ? 30 : 8));
    const rear = this.state === 'mortarWind' || this.state === 'mortar';
    this.head.rotation.x += ((rear ? -0.5 : 0) - this.head.rotation.x) * Math.min(1, dt * 6);
    this.eyeMat.color.setHex(this.enraged ? (Math.sin(t * 12) > 0 ? 0xff2010 : 0xffa040) : 0xff5020);
  }
}

// ---------------------------------------------------------------------------
// V2 (boss): V1'in kırmızı rakibi. Hızla çevrende döner, kayar ve zıplar. Uzaktan işaretli
// revolver atışı (işaret görünür, kilitlendikten sonra kaç), orta mesafede çivi yağmuru,
// yakında pompalı; ara sıra parlayarak Knuckleblaster hücumu yapar — PARRY ile bozulur.
export class V2 extends Enemy {
  init() {
    const T = this.game.tex;
    this.type = 'v2';
    this.name = 'V2';
    this.maxHp = 42;
    this.r = 0.45;
    this.h = 2.0;
    this.big = true;
    this.boss = true;
    this.killPts = 600;
    this.knockMul = 0.35;
    this.parryDmg = 5;
    this.parryStun = 1.4;
    this.firstState = 'strafe';
    this.spawnDur = 0.9;
    this.baseSpeed = 12.5 * difficulty().speed;
    this.orbitDir = chance(0.5) ? 1 : -1;
    this.orbitT = rand(1.5, 3);
    this.atkCd = 1.2;
    this.dashCd = 6;
    this.jumpCd = rand(1, 3);
    this.sliding = false;
    this.tint = 1;
    const red = this.mat(T.metal, 0xd8342a, 0.2);
    const metal = this.mat(T.machine, 0xc0c6d2, 0.1);
    const dark = this.mat(T.machine, 0x2c2e36, 0.06);
    const H = (this.H = buildHumanoid({ skin: metal, dark, hunch: 0.05, torsoW: 0.44, torsoH: 0.58, torsoD: 0.28, headS: 0.28, armL: 1.02, legL: 1.08, scale: 1.1, taper: 0.72 }));
    const J = H.J, d = H.dims;
    // kafa: V şeklinde vizör
    part(J.head, bgeo(0.3, 0.3, 0.32), red, 0, 0.16, 0);
    this.visorMat = new THREE.MeshBasicMaterial({ color: 0xffe0a0 });
    part(J.head, bgeo(0.11, 0.04, 0.02), this.visorMat, -0.06, 0.2, -0.165, 0, 0, -0.35, true);
    part(J.head, bgeo(0.11, 0.04, 0.02), this.visorMat, 0.06, 0.2, -0.165, 0, 0, 0.35, true);
    // göğüs ve omuz zırhı
    part(J.spine, bgeo(d.torsoW + 0.04, 0.3, d.torsoD + 0.04), red, 0, d.torsoH * 0.72, 0);
    part(J.spine, bgeo(0.16, 0.16, 0.04), this.visorMat, 0, d.torsoH * 0.62, -d.torsoD / 2 - 0.03, 0, 0, 0, true);
    for (const s of ['L', 'R']) part(J['sh' + s], bgeo(0.2, 0.14, 0.24), red, 0, 0.04, 0);
    // kanatlar: sırtta dört ince plaka, hareketle parlar
    this.wingMat = new THREE.MeshBasicMaterial({ color: 0xffb040 });
    this.wings = [];
    for (const [x, y, rz] of [[-0.2, 0.62, 0.7], [0.2, 0.62, -0.7], [-0.18, 0.4, 1.1], [0.18, 0.4, -1.1]]) {
      const w = joint(J.spine, x, y, d.torsoD / 2 + 0.05);
      w.rotation.z = rz;
      part(w, bgeo(0.05, 0.55, 0.03), this.wingMat, 0, 0.28, 0, 0, 0, 0, true);
      this.wings.push(w);
    }
    // sağ elde revolver (tüm silahlar tek modelden)
    const gun = new THREE.Group();
    part(gun, bgeo(0.08, 0.12, 0.34), dark, 0, 0, -0.14);
    part(gun, cgeo(0.06, 0.1, 6), red, 0, 0.02, -0.08, Math.PI / 2);
    part(gun, bgeo(0.05, 0.14, 0.06), dark, 0, -0.1, 0.02);
    this.muzzle = joint(gun, 0, 0.02, -0.34);
    gun.position.set(0, -0.1, 0);
    gun.rotation.x = Math.PI / 2;
    J.haR.add(gun);
    // sol kol: Knuckleblaster
    part(J.haL, bgeo(0.17, 0.17, 0.17), red, 0, -0.06, 0);
    this.fistGlow = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.glow, color: 0x9fe0ff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    this.fistGlow.scale.setScalar(0.01);
    J.haL.add(this.fistGlow);
    // nişan çizgisi
    this.laserMat = new THREE.MeshBasicMaterial({ color: 0xff3020, transparent: true, opacity: 0.5, blending: THREE.AdditiveBlending, depthWrite: false });
    this.laser = new THREE.Mesh(new THREE.BoxGeometry(1, 1, 1).translate(0, 0, 0.5), this.laserMat);
    this.laser.visible = false;
    this.game.scene.add(this.laser);
    this.aimPt = new THREE.Vector3();
    this.root.add(H.root);
    this.humanoidSpheres(H, 1.1);
  }

  get speed() { return this.baseSpeed * (this.enraged ? 1.25 : 1); }
  set speed(v) { this.baseSpeed = v; }

  think(dt) {
    const i = this.playerInfo();
    const p = this.game.player;
    const aggro = difficulty().aggro * (this.enraged ? 1.35 : 1);
    this.atkCd -= dt;
    this.dashCd -= dt;
    this.jumpCd -= dt;
    if (!this.enraged && this.hp < this.maxHp * 0.5 && this.state === 'strafe') {
      this.enraged = true;
      this.game.hud.message('V2 ÖFKELENDİ', 1.4);
      this.game.audio.play('bossRoar', this.pos, { rate: 1.3, exactRate: true });
    }
    if (this.state !== 'aim') this.laser.visible = false;
    switch (this.state) {
      case 'strafe': {
        this.faceYaw(yawTo(i.dx, i.dz), 10, dt);
        this.orbitT -= dt;
        if (this.orbitT <= 0) { this.orbitT = rand(1.2, 2.6); this.orbitDir *= -1; }
        const want = i.dist > 16 ? 1 : i.dist < 8 ? -0.7 : 0;
        const sp = this.speed;
        let tx = i.dx * want * sp - i.dz * this.orbitDir * sp * 0.75;
        let tz = i.dz * want * sp + i.dx * this.orbitDir * sp * 0.75;
        const l = Math.hypot(tx, tz);
        if (l > 0.1 && this.grounded && !this.groundAhead(tx / l, tz / l, 1.6)) { this.orbitDir *= -1; tx = i.dx * sp * 0.5; tz = i.dz * sp * 0.5; }
        if (this.blocked > 0.25) { this.orbitDir *= -1; this.blocked = 0; if (this.grounded) { this.vel.y = 12; this.grounded = false; } }
        this.accelTo(tx, tz, 40, dt);
        this.sliding = this.grounded && want > 0;
        if (this.jumpCd <= 0 && this.grounded) { this.jumpCd = rand(1.8, 3.5); this.vel.y = 12; this.grounded = false; this.game.audio.play('jump', this.pos, { rate: 0.8 }); }
        if (this.dashCd <= 0 && this.canSee && i.dist < 18 && i.dist > 3 && Math.abs(i.dy) < 2.5) {
          this.dashCd = rand(6, 9) / aggro;
          this.setState('dashWind');
          this.game.audio.play('windup', this.pos, { rate: 1.3, exactRate: true });
          break;
        }
        if (this.atkCd <= 0 && this.canSee) {
          if (i.dist < 6) this.setState('shotgun');
          else if (i.dist < 13 && chance(0.55)) { this.setState('nails'); this.shots = 0; }
          else {
            this.setState('aim');
            this.game.audio.play('chargeReady', this.pos, { rate: 0.8, range: 80 });
          }
        }
        break;
      }
      case 'aim': {
        // uzun işaret: son 0.2 sn kilitli, sonra hızlı atış
        this.accelTo(0, 0, 25, dt);
        this.faceYaw(yawTo(i.dx, i.dz), 12, dt);
        const dur = 0.75 / aggro, lock = dur - 0.2;
        const from = this.muzzle.getWorldPosition(_w);
        if (this.st < lock) this.aimPt.set(p.pos.x, p.pos.y + p.h * 0.55, p.pos.z);
        this.laser.visible = true;
        this.laser.position.copy(from);
        this.laser.lookAt(this.aimPt);
        const len = from.distanceTo(this.aimPt) + 30;
        const th = this.st >= lock ? 0.07 : 0.025;
        this.laser.scale.set(th, th, len);
        this.laserMat.opacity = this.st >= lock ? 0.9 : 0.35 + Math.sin(this.st * 40) * 0.1;
        if (this.st >= dur) {
          this.laser.visible = false;
          this.fireRevolver(from.clone());
          this.setState('recover');
          this.atkCd = rand(1.1, 1.8) / aggro;
        }
        break;
      }
      case 'nails': {
        this.faceYaw(yawTo(i.dx, i.dz), 10, dt);
        this.accelTo(-i.dz * this.orbitDir * this.speed * 0.5, i.dx * this.orbitDir * this.speed * 0.5, 30, dt);
        const n = this.enraged ? 14 : 10;
        while (this.shots < n && this.st >= 0.25 + this.shots * 0.06) { this.fireNail(); this.shots++; }
        if (this.st > 0.25 + n * 0.06 + 0.2) { this.setState('strafe'); this.atkCd = rand(1.2, 2) / aggro; }
        break;
      }
      case 'shotgun': {
        this.faceYaw(yawTo(i.dx, i.dz), 14, dt);
        this.accelTo(0, 0, 30, dt);
        if (!this.fired && this.st > 0.3 / aggro) { this.fired = true; this.fireShotgun(); this.vel.x -= i.dx * 8; this.vel.z -= i.dz * 8; }
        if (this.st > 0.6) { this.fired = false; this.setState('strafe'); this.atkCd = rand(1.0, 1.6) / aggro; }
        break;
      }
      case 'dashWind': {
        this.faceYaw(yawTo(i.dx, i.dz), 14, dt);
        this.accelTo(0, 0, 30, dt);
        const dur = 0.55 / aggro;
        this.fistGlow.scale.setScalar(0.3 + 1.4 * clamp(this.st / dur, 0, 1));
        if (this.st > dur - 0.3) this.setParryable(true, this.H.J.haL.getWorldPosition(new THREE.Vector3()));
        if (this.st >= dur) {
          this.state = 'dash'; this.st = 0; this.hitDone = false;
          this.vel.x = i.dx * 30; this.vel.z = i.dz * 30;
          this.game.audio.play('dash', this.pos);
        }
        break;
      }
      case 'dash': {
        if (this.st > 0.3) this.setParryable(false);
        if (!this.hitDone && i.dist < 2.2 && this.meleeHit(2.6, 25, 0)) {
          this.hitDone = true;
          p.vel.x += i.dx * 18; p.vel.z += i.dz * 18; p.vel.y = Math.max(p.vel.y, 8);
        }
        if (this.st > 0.4) { this.fistGlow.scale.setScalar(0.01); this.setState('recover'); }
        break;
      }
      case 'recover': {
        this.accelTo(0, 0, 30, dt);
        if (this.st > 0.3) this.setState('strafe');
        break;
      }
    }
    if (this.state !== 'strafe') this.sliding = false;
    if (this.state !== 'dashWind' && this.state !== 'dash') this.fistGlow.scale.setScalar(0.01);
  }

  fireRevolver(from) {
    const game = this.game;
    const dir = this.aimPt.clone().sub(from).normalize();
    const speed = 110;
    game.addProjectile(new Projectile(game, { kind: 'pellet', pos: from, vel: dir.clone().multiplyScalar(speed), radius: 0.3, damage: 22 * difficulty().dmg, color: 0xff4020, source: this, parryable: false }));
    game.fx.tracer(from, from.clone().addScaledVector(dir, 60), 0xffa060, 0.06, 0.15);
    game.audio.play('revolver', from, { rate: 0.85, range: 90 });
    game.fx.sprite(from, 0xffd080, 1, 0.08);
  }

  fireNail() {
    const game = this.game;
    const from = this.muzzle.getWorldPosition(new THREE.Vector3());
    const speed = 50 * difficulty().speed;
    const dir = aimAt(game, from, speed, 0.5);
    dir.x += rand(-0.05, 0.05); dir.y += rand(-0.04, 0.04); dir.z += rand(-0.05, 0.05);
    dir.normalize();
    game.addProjectile(new Projectile(game, { kind: 'pellet', pos: from, vel: dir.multiplyScalar(speed), radius: 0.18, damage: 5 * difficulty().dmg, color: 0xc0d0ff, source: this }));
    if (this.shots % 2 === 0) game.audio.play('schismShot', from, { rate: 2, vol: 0.6 });
  }

  fireShotgun() {
    const game = this.game;
    const from = this.muzzle.getWorldPosition(new THREE.Vector3());
    const base = aimAt(game, from, 60, 0.2);
    for (let k = 0; k < 8; k++) {
      const d = base.clone().add(new THREE.Vector3(rand(-0.13, 0.13), rand(-0.08, 0.08), rand(-0.13, 0.13))).normalize();
      game.addProjectile(new Projectile(game, { kind: 'pellet', pos: from.clone(), vel: d.multiplyScalar(60), radius: 0.2, damage: 7 * difficulty().dmg, color: 0xffb040, source: this, life: 0.6 }));
    }
    game.audio.play('bossShotgun', from);
    game.fx.sprite(from, 0xffd080, 1.4, 0.1);
  }

  die(info, wasFull, dmg) {
    this.laser.visible = false;
    this.game.scene.remove(this.laser);
    super.die(info, wasFull, dmg);
  }

  removeSilently() {
    this.game.scene.remove(this.laser);
    super.removeSilently();
  }

  animate(dt) {
    this.k = 1 - Math.exp(-18 * dt);
    const H = this.H, J = H.J;
    const hsp = Math.hypot(this.vel.x, this.vel.z);
    this.walkPhase += hsp * dt * 1.2;
    const amt = clamp(hsp / 10, 0, 1);
    // yan adım: gövde hareket yönüne eğilir
    const f = this.forward();
    const side = (f.x * this.vel.z - f.z * this.vel.x) / (this.speed || 1);
    if (this.sliding) {
      this.rot(J.hipL, 1.3); this.rot(J.hipR, 0.2); this.rot(J.knL, -0.2); this.rot(J.knR, -1.6);
      this.rot(J.spine, -0.35);
      J.hips.position.y = H.hipY - 0.35;
      if (Math.random() < dt * 30) this.game.fx.sparkDir(this.pos, _v.set(-this.vel.x, 2, -this.vel.z).normalize(), 2, 5, 0xffc060, 0.25, 0.04, 0.6);
    } else {
      this.walkPose(H, amt, 0.4, 0);
      this.rot(J.spine, -0.08, 0, clamp(side * 0.25, -0.3, 0.3));
      if (!this.grounded && this.state !== 'spawn') this.airPose(H);
    }
    // sağ kol silahı oyuncuya doğrultur
    const aiming = this.state !== 'spawn' && this.state !== 'stagger';
    if (aiming) { this.rot(J.shR, -1.45 + this.lookPitch * 0.8, 0, 0.1); this.rot(J.elR, 0.05); }
    if (this.state === 'dashWind') { this.rot(J.shL, 0.6, 0, -0.3); this.rot(J.elL, 1.6); }
    else if (this.state === 'dash') { this.rot(J.shL, -1.5, 0, -0.1); this.rot(J.elL, 0); }
    else if (this.state === 'stagger') { this.rot(J.spine, 0.35); this.rot(J.shL, -0.2, 0, -0.5); }
    // kanat parıltısı
    const glow = 0.5 + 0.5 * Math.sin(this.time * (this.enraged ? 16 : 6));
    this.wingMat.color.setRGB(1, 0.45 + glow * 0.35, 0.15 + glow * 0.2);
    this.wings.forEach((w, k) => { w.rotation.x = -0.2 - amt * 0.4 + Math.sin(this.time * 4 + k) * 0.05; });
    this.visorMat.color.setHex(this.enraged ? (Math.sin(this.time * 14) > 0 ? 0xff4020 : 0xffe0a0) : 0xffe0a0);
  }
}

Object.assign(ENEMY_TYPES, { drone: Drone, streetcleaner: Streetcleaner, hideousmass: HideousMass, v2: V2 });
void wrapAngle; void _v;
