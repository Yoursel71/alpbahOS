// V1 hareket denetleyicisi: koşu, zıplama, duvar sıçraması, atılma (dash, hasarsızlık),
// kayma, yere çakma (slam) ve çakış sıçrayışı, can/sert hasar/stamina.
import * as THREE from 'three';
import { clamp, damp, approach } from './util.js';
import { settings } from './settings.js';

export const P = {
  RUN: 13.5,
  GROUND_ACCEL: 130,
  OVERSPEED_FRIC: 45,
  AIR_ACCEL: 42,
  G: 38,
  JUMP: 15,
  WJ_V: 13.5,
  WJ_H: 11,
  DASH_SPEED: 44,
  DASH_TIME: 0.18,
  DASHJUMP_H: 30,
  DASHJUMP_V: 10.5,
  SLIDE_SPEED: 22,
  SLAM_SPEED: 85,
  WALL_SLIDE: 5,
  STAND_H: 1.8,
  SLIDE_H: 0.85,
  EYE_STAND: 1.55,
  EYE_SLIDE: 0.62,
  STAMINA_REGEN: 1.3,
};

const tmp = new THREE.Vector3();

export class Player {
  constructor(game) {
    this.game = game;
    this.pos = new THREE.Vector3();
    this.vel = new THREE.Vector3();
    this.r = 0.4;
    this.h = P.STAND_H;
    this.isEnemy = false;
    this.yaw = 0;
    this.pitch = 0;
    this.reset(new THREE.Vector3(), 0);
  }

  reset(pos, yaw) {
    this.pos.copy(pos);
    this.vel.set(0, 0, 0);
    this.yaw = yaw;
    this.pitch = 0;
    this.h = P.STAND_H;
    this.grounded = false;
    this.groundTime = 0;
    this.airTime = 0;
    this.hp = 100;
    this.hard = 0;
    this.hardDelay = 0;
    this.dead = false;
    this.stamina = 3;
    this.wallJumps = 3;
    this.dashT = 0;
    this.dashDir = new THREE.Vector3(0, 0, -1);
    this.iframes = 0;
    this.sliding = false;
    this.slideDir = new THREE.Vector3(0, 0, -1);
    this.slideSpeed = 0;
    this.slideLock = false;
    this.slamming = false;
    this.slamStartY = 0;
    this.slamLandT = 99;
    this.slamStored = 0;
    this.jumpBuffer = 0;
    this.coyote = 0;
    this.eye = P.EYE_STAND;
    this.bobT = 0;
    this.bob = 0;
    this.tilt = 0;
    this.landDip = 0;
    this.landVel = 0;
    this.fovKick = 0;
    this.stepT = 0;
    this.hurtCd = 0;
    this.lastSafe = pos.clone();
    this.safeT = 0;
    this.frozen = false;
    this.wish = new THREE.Vector3();
    this.strafe = 0;
    this.lastWall = null;
  }

  forward(out = new THREE.Vector3()) {
    return out.set(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
  }

  aimDir(out = new THREE.Vector3()) {
    const cp = Math.cos(this.pitch);
    return out.set(-Math.sin(this.yaw) * cp, Math.sin(this.pitch), -Math.cos(this.yaw) * cp);
  }

  eyePos(out = new THREE.Vector3()) {
    return out.set(this.pos.x, this.pos.y + this.eye, this.pos.z);
  }

  canStand() {
    const oh = this.h;
    this.h = P.STAND_H;
    const blocked = this.game.world.overlapBody(this);
    this.h = oh;
    return !blocked;
  }

  look(input, dt) {
    const s = settings.sens * 0.0021;
    this.yaw -= input.mdx * s;
    this.pitch -= input.mdy * s * (settings.invertY ? -1 : 1);
    // Ok tuşlarıyla bakış (fare kilidi yoksa)
    const kl = 2.6 * dt;
    if (input.is('lookLeft')) this.yaw += kl;
    if (input.is('lookRight')) this.yaw -= kl;
    if (input.is('lookUp')) this.pitch += kl * 0.8;
    if (input.is('lookDown')) this.pitch -= kl * 0.8;
    this.pitch = clamp(this.pitch, -1.55, 1.55);
  }

  update(dt, input) {
    const game = this.game;
    const world = game.world;
    const audio = game.audio;
    if (this.dead) return;

    // Zamanlayıcılar
    this.iframes = Math.max(0, this.iframes - dt);
    this.jumpBuffer = Math.max(0, this.jumpBuffer - dt);
    this.coyote = Math.max(0, this.coyote - dt);
    this.hurtCd = Math.max(0, this.hurtCd - dt);
    this.slamLandT += dt;
    if (this.dashT <= 0) this.stamina = Math.min(3, this.stamina + P.STAMINA_REGEN * dt);
    if (this.hardDelay > 0) this.hardDelay -= dt;
    else this.hard = Math.max(0, this.hard - 14 * dt);
    this.hp = Math.min(this.hp, 100);

    // İstek yönü
    const fwd = this.forward(tmp);
    const fx = fwd.x, fz = fwd.z;
    const rx = -fz, rz = fx; // sağ
    let mf = 0, ms = 0;
    if (!this.frozen) {
      if (input.is('forward')) mf += 1;
      if (input.is('back')) mf -= 1;
      if (input.is('right')) ms += 1;
      if (input.is('left')) ms -= 1;
    }
    // Dokunmatik joystick (analog → yön)
    const ax = input.axisX || 0, ay = input.axisY || 0;
    if (!this.frozen && Math.hypot(ax, ay) > 0.22) {
      mf = -ay;
      ms = ax;
    }
    this.strafe = Math.max(-1, Math.min(1, ms));
    let wx = fx * mf + rx * ms, wz = fz * mf + rz * ms;
    const wl = Math.hypot(wx, wz);
    if (wl > 0) { wx /= wl; wz /= wl; }
    this.wish.set(wx, 0, wz);
    const hasWish = wl > 0;

    if (!this.frozen) {
      if (input.pressed('jump')) this.jumpBuffer = 0.14;

      // ATILMA
      if (input.pressed('dash') && this.stamina >= 1 && this.dashT <= 0) {
        const dx = hasWish ? wx : fx, dz = hasWish ? wz : fz;
        this.dashDir.set(dx, 0, dz);
        this.dashT = P.DASH_TIME;
        this.iframes = P.DASH_TIME + 0.05;
        this.stamina -= 1;
        this.slamming = false;
        this.endSlide(true);
        this.vel.set(dx * P.DASH_SPEED, 0, dz * P.DASH_SPEED);
        this.fovKick = 8;
        audio.play('dash');
        game.fx.sparkDir(this.pos.clone().add(new THREE.Vector3(0, 0.8, 0)), new THREE.Vector3(-dx, 0, -dz), 8, 10, 0x9fd0ff, 0.25, 0.05, 0.4);
      }

      // KAYMA / ÇAKMA
      const slideHeld = input.is('slide');
      if (!slideHeld) this.slideLock = false;
      if (input.pressed('slide') && !this.grounded && this.coyote <= 0 && !this.slamming && this.dashT <= 0) {
        this.slamming = true;
        this.slamStartY = this.pos.y;
        this.endSlide(true);
        this.vel.set(0, -P.SLAM_SPEED, 0);
        audio.play('slamStart');
      }
      if (slideHeld && this.grounded && !this.sliding && !this.slideLock && this.dashT <= 0) {
        this.startSlide(hasWish ? wx : fx, hasWish ? wz : fz);
      }
      if (this.sliding && !slideHeld && this.canStand()) this.endSlide();
    }

    // Fizik
    if (this.dashT > 0) {
      this.dashT -= dt;
      this.vel.x = this.dashDir.x * P.DASH_SPEED;
      this.vel.z = this.dashDir.z * P.DASH_SPEED;
      this.vel.y = this.grounded ? -2 : 0;
      if (this.dashT <= 0) {
        this.vel.x = this.dashDir.x * P.RUN * 1.1;
        this.vel.z = this.dashDir.z * P.RUN * 1.1;
      }
    } else if (this.slamming) {
      this.vel.set(0, -P.SLAM_SPEED, 0);
    } else if (this.sliding) {
      // hafif yön kontrolü
      if (hasWish) {
        const k = Math.min(1, dt * 1.5);
        this.slideDir.x += (wx - this.slideDir.x) * k;
        this.slideDir.z += (wz - this.slideDir.z) * k;
        this.slideDir.normalize();
      }
      this.vel.x = this.slideDir.x * this.slideSpeed;
      this.vel.z = this.slideDir.z * this.slideSpeed;
      this.vel.y -= P.G * dt;
      if (Math.random() < dt * 25) game.fx.sparkDir(this.pos.clone().add(new THREE.Vector3(0, 0.05, 0)), new THREE.Vector3(-this.slideDir.x, 0.4, -this.slideDir.z), 1, 5, 0xffb060, 0.25, 0.04, 0.5);
    } else if (this.grounded) {
      const tx = wx * P.RUN, tz = wz * P.RUN;
      const sp = Math.hypot(this.vel.x, this.vel.z);
      if (sp > P.RUN + 0.5) {
        // Fazla hızı yavaşça sönümle (kayma-zıplama sonrası)
        const ns = Math.max(P.RUN, sp - P.OVERSPEED_FRIC * dt);
        const k = ns / sp;
        this.vel.x = this.vel.x * k + (tx - this.vel.x * k) * Math.min(1, dt * 4);
        this.vel.z = this.vel.z * k + (tz - this.vel.z * k) * Math.min(1, dt * 4);
      } else {
        const step = P.GROUND_ACCEL * dt;
        const dvx = tx - this.vel.x, dvz = tz - this.vel.z;
        const dl = Math.hypot(dvx, dvz);
        if (dl <= step) { this.vel.x = tx; this.vel.z = tz; } else { this.vel.x += (dvx / dl) * step; this.vel.z += (dvz / dl) * step; }
      }
      this.vel.y -= P.G * dt;
    } else {
      // Hava kontrolü (Quake tarzı: hız sınırını yalnızca istek yönünde uygular)
      if (hasWish) {
        const cur = this.vel.x * wx + this.vel.z * wz;
        const add = Math.min(P.AIR_ACCEL * dt, Math.max(0, P.RUN - cur));
        this.vel.x += wx * add;
        this.vel.z += wz * add;
      }
      this.vel.y -= P.G * dt;
      // Duvarda kayma: düşüşü yavaşlat
      const wall = world.wallCheck(this, 0.3);
      if (wall && this.vel.y < -P.WALL_SLIDE && hasWish && (wx * wall.x + wz * wall.z) < -0.2) {
        this.vel.y = approach(this.vel.y, -P.WALL_SLIDE, 90 * dt);
        if (Math.random() < dt * 20) game.fx.sparkBurst(this.pos.clone().add(new THREE.Vector3(-wall.x * 0.4, 1, -wall.z * 0.4)), 1, 3, 0xffc070, 0.3, 0.04);
      }
    }
    this.vel.y = Math.max(this.vel.y, -120);

    // ZIPLAMA
    if (this.jumpBuffer > 0 && !this.frozen) {
      if (this.grounded || this.coyote > 0) {
        this.doJump();
      } else if (this.dashT <= 0 && !this.slamming && this.wallJumps > 0) {
        const wall = world.wallCheck(this, 0.4);
        if (wall) {
          this.wallJumps--;
          this.jumpBuffer = 0;
          const hx = wall.x * P.WJ_H + wx * 3, hz = wall.z * P.WJ_H + wz * 3;
          this.vel.set(hx, P.WJ_V, hz);
          audio.play('walljump');
          game.fx.sparkBurst(this.pos.clone().add(new THREE.Vector3(-wall.x * 0.4, 0.8, -wall.z * 0.4)), 8, 6, 0xffd080, 0.3, 0.05);
          game.hud.wallJumps(this.wallJumps);
        }
      }
    }

    // Yükseklik (kayarken alçal)
    const targetH = this.sliding ? P.SLIDE_H : P.STAND_H;
    if (targetH > this.h) {
      if (this.canStand()) this.h = targetH;
    } else this.h = targetH;

    // Hareket
    const wasGrounded = this.grounded;
    const fallSpeed = -this.vel.y;
    const res = world.moveBody(this, this.vel.x * dt, this.vel.y * dt, this.vel.z * dt, wasGrounded && !this.sliding ? 0.6 : wasGrounded ? 0.3 : 0);
    if (res.stepped > 0) this.landDip -= res.stepped * 0.6;
    if (res.hitX) { if (this.dashT <= 0 && !this.sliding) this.vel.x = 0; else this.vel.x = 0; }
    if (res.hitZ) this.vel.z = 0;
    if (res.ceil && this.vel.y > 0) this.vel.y = 0;

    let grounded = res.ground && this.vel.y <= 0.01;
    // Aşağı basamak yapıştırma
    if (!grounded && wasGrounded && this.vel.y <= 0 && this.jumpBuffer <= 0 && this.dashT <= 0) {
      const oy = this.pos.y;
      const r2 = world.moveBody(this, 0, -0.65, 0);
      if (r2.ground) grounded = true;
      else this.pos.y = oy;
    }

    if (grounded) {
      if (!wasGrounded) this.onLand(fallSpeed);
      this.grounded = true;
      this.vel.y = 0;
      this.coyote = 0.1;
      this.wallJumps = 3;
      this.airTime = 0;
      this.groundTime += dt;
      this.groundSolid = res.groundSolid;
    } else {
      if (wasGrounded && this.vel.y <= 0) this.coyote = 0.1;
      this.grounded = false;
      this.groundTime = 0;
      this.airTime += dt;
      if (this.sliding && this.airTime > 0.15) this.endSlide();
    }

    // Kayma sesi
    audio.loop('slide', this.sliding && this.grounded, { f: 700, vol: 0.1 });

    // Adım sesleri
    const hsp = Math.hypot(this.vel.x, this.vel.z);
    if (this.grounded && !this.sliding && hsp > 3) {
      this.stepT += dt * hsp / P.RUN;
      if (this.stepT > 0.3) { this.stepT = 0; audio.play('step'); }
      this.bobT += dt * hsp * 0.9;
    }

    this.checkHazards(dt);

    // Güvenli nokta
    if (this.grounded && this.groundSolid && this.groundSolid.tag === 'static' && this.hurtCd <= 0) {
      this.safeT += dt;
      if (this.safeT > 0.25) { this.lastSafe.copy(this.pos); this.safeT = 0; }
    }

    // Kamera etkileri
    const eyeT = this.sliding ? P.EYE_SLIDE : P.EYE_STAND;
    this.eye = damp(this.eye, eyeT, 14, dt);
    const tiltT = settings.tilt ? (-this.strafe * 0.035 + (this.sliding ? 0.04 : 0)) : 0;
    this.tilt = damp(this.tilt, tiltT, 8, dt);
    // yaylı iniş çökmesi
    this.landVel += (-this.landDip * 120 - this.landVel * 16) * dt;
    this.landDip += this.landVel * dt;
    this.fovKick = damp(this.fovKick, 0, 6, dt);
    const bobAmp = this.grounded && !this.sliding ? Math.min(1, hsp / P.RUN) : 0;
    this.bob = damp(this.bob, bobAmp, 10, dt);
  }

  startSlide(dx, dz) {
    this.sliding = true;
    this.slideDir.set(dx, 0, dz).normalize();
    const sp = Math.hypot(this.vel.x, this.vel.z);
    this.slideSpeed = Math.max(P.SLIDE_SPEED, Math.min(sp, 40));
    this.game.audio.play('dash', null, { vol: 0.4 });
  }

  endSlide(force = false) {
    if (!this.sliding) return;
    if (!force && !this.canStand()) return;
    this.sliding = false;
  }

  doJump() {
    const audio = this.game.audio;
    this.jumpBuffer = 0;
    this.coyote = 0;
    if (this.dashT > 0) {
      // ATILMA ZIPLAMASI: uzun menzil
      const extra = this.stamina >= 1 ? 1 : 0;
      this.stamina -= extra;
      const k = extra ? 1 : 0.7;
      this.vel.set(this.dashDir.x * P.DASHJUMP_H * k, P.DASHJUMP_V, this.dashDir.z * P.DASHJUMP_H * k);
      this.dashT = 0;
      audio.play('walljump');
    } else if (this.sliding) {
      // Kayma zıplaması: hızı korur
      this.vel.x = this.slideDir.x * this.slideSpeed;
      this.vel.z = this.slideDir.z * this.slideSpeed;
      this.vel.y = P.JUMP * 0.92;
      this.endSlide(true);
      this.slideLock = true;
      audio.play('jump');
    } else if (this.slamLandT < 0.18) {
      // ÇAKIŞ SIÇRAYIŞI
      this.vel.y = P.JUMP + this.slamStored;
      this.game.fx.ring(this.pos.clone(), 0xffd080, 2, 0.3);
      audio.play('walljump');
      this.slamLandT = 99;
    } else {
      this.vel.y = P.JUMP;
      audio.play('jump');
    }
    this.grounded = false;
  }

  onLand(fallSpeed) {
    const game = this.game;
    if (this.slamming) {
      this.slamming = false;
      this.slamLandT = 0;
      const fall = Math.max(0, this.slamStartY - this.pos.y);
      this.slamStored = Math.min(4 + fall * 0.9, 20);
      this.slideLock = true;
      game.shake(0.55);
      game.audio.play('slam');
      game.fx.ring(this.pos.clone(), 0xffe0b0, 4 + Math.min(fall * 0.3, 4), 0.4);
      game.fx.sparkBurst(this.pos.clone().add(new THREE.Vector3(0, 0.1, 0)), 20, 10, 0xffc080, 0.4, 0.06);
      game.onSlamLand(this.pos, fall);
      this.landDip = -0.35;
    } else if (fallSpeed > 38) {
      // yüksekten düşüş (bölüm girişi): sert iniş
      this.landDip = -0.4;
      game.shake(0.6);
      game.audio.play('slam');
      game.fx.ring(this.pos.clone(), 0xffc080, 6, 0.5);
      game.fx.sparkBurst(this.pos.clone().add(new THREE.Vector3(0, 0.1, 0)), 30, 12, 0xffa060, 0.5, 0.07);
    } else if (fallSpeed > 12) {
      this.landDip = -Math.min(0.3, fallSpeed * 0.008);
      game.audio.play('land');
    }
  }

  checkHazards(dt) {
    const game = this.game;
    const L = game.level;
    const px = this.pos.x, py = this.pos.y + 0.1, pz = this.pos.z;
    for (const z of L.hurtZones) {
      const b = z.box;
      if (px > b[0] && px < b[3] && py > b[1] && py < b[4] && pz > b[2] && pz < b[5]) {
        if (z.kind === 'pit') { this.outOfBounds(z.dps); return; }
        if (this.hurtCd <= 0) {
          this.hurtCd = 0.45;
          this.vel.y = 17;
          this.grounded = false;
          this.slamming = false;
          game.damagePlayer(z.dps, null, true);
          game.audio.play('lava', this.pos);
          game.fx.sparkBurst(this.pos.clone(), 16, 8, 0xff8020, 0.5, 0.08);
        }
      }
    }
    if (this.pos.y < L.killY) this.outOfBounds(35);
  }

  outOfBounds(dmg) {
    const game = this.game;
    this.pos.copy(this.lastSafe);
    this.vel.set(0, 0, 0);
    this.slamming = false;
    this.endSlide(true);
    this.hurtCd = 0.5;
    if (dmg > 0) game.damagePlayer(dmg, null, true);
    game.hud.flash('rgba(255,90,0,0.5)', 0.4);
    game.hud.message('SINIR DIŞI', 1.2);
  }

  damage(dmg) {
    this.hp -= dmg;
    this.hard = Math.min(100, this.hard + dmg * 0.35);
    this.hardDelay = 1.2;
  }

  heal(amount) {
    const cap = 100 - this.hard;
    if (this.hp >= cap) return 0;
    const before = this.hp;
    this.hp = Math.min(cap, this.hp + amount);
    return this.hp - before;
  }
}
