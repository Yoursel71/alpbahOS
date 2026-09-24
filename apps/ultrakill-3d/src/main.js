// ULTRAKILL 3D (hayran yapımı) — oyun döngüsü ve durum makinesi.
import * as THREE from 'three';
import { settings, loadSettings, progress, saveProgress, difficulty } from './settings.js';
import { Input } from './input.js';
import { Audio } from './audio.js';
import { Music } from './music.js';
import { buildTextures } from './textures.js';
import { Renderer, psx } from './render.js';
import { World } from './physics.js';
import { Level, buildLevel01 } from './level.js';
import { Player } from './player.js';
import { Weapons } from './weapons.js';
import { FX } from './fx.js';
import { Style } from './style.js';
import { HUD } from './hud.js';
import { UI, rankTime, rankKills, rankStyle, finalRank, betterRank } from './ui.js';
import { ENEMY_TYPES } from './enemies.js';
import { rand, clamp, damp, yawTo } from './util.js';
import { Projectile } from './projectiles.js';
import { TouchControls } from './touch.js';

const _v = new THREE.Vector3();
const _v2 = new THREE.Vector3();

class Arenas {
  constructor(game) {
    this.game = game;
    this.list = game.level.arenas;
  }

  start(a) {
    const g = this.game;
    if (a.state !== 'idle' || g.state !== 'playing') return;
    a.state = 'active';
    a.wave = -1;
    a.enemies = [];
    a.delay = a.boss ? 2.4 : 0.35;
    for (const id of a.lock) g.level.doors[id].close();
    a.killsAtStart = g.stats.kills;
    if (a.boss) {
      g.music.setMode('boss');
      g.hud.titleCard(`<div class="tc-boss-sub">ARAF'IN BEKÇİSİ</div><div class="tc-boss">${a.name}</div>`, 3.2);
      g.audio.play('bossRoar');
    } else g.music.setMode('combat');
    if (a.onStart) a.onStart(g);
  }

  update(dt) {
    const g = this.game;
    for (const a of this.list) {
      if (a.state !== 'active') continue;
      a.enemies = a.enemies.filter((e) => !e.dead);
      if (a.enemies.length) continue;
      a.delay -= dt;
      if (a.delay > 0) continue;
      if (a.wave + 1 < a.waves.length) {
        a.wave++;
        for (const s of a.waves[a.wave]) g.spawnEnemy(s.t, s.p, a);
        a.delay = 0.9;
      } else this.clear(a);
    }
  }

  clear(a) {
    const g = this.game;
    a.state = 'cleared';
    for (const id of a.exits) g.level.doors[id].open();
    if (a.onClear) a.onClear(g);
    if (!this.list.some((x) => x.state === 'active')) g.music.setMode('calm');
    if (!a.boss) g.hud.message('ALAN TEMİZLENDİ', 1.6);
  }

  resetActive() {
    const g = this.game;
    for (const a of this.list) {
      if (a.state !== 'active') continue;
      for (const e of a.enemies) e.removeSilently();
      a.enemies = [];
      if (a.killsAtStart !== undefined) g.stats.kills = a.killsAtStart;
      a.state = 'idle';
      a.wave = -1;
      a.trig.fired = false;
      for (const id of a.lock) g.level.doors[id].reset();
      for (const id of a.exits) g.level.doors[id].reset();
    }
  }

  resetAll() {
    for (const a of this.list) {
      a.state = 'idle';
      a.wave = -1;
      a.enemies = [];
    }
  }
}

class Game {
  constructor() {
    loadSettings();
    this.canvas = document.getElementById('game');
    this.uiRoot = document.getElementById('ui');
    this.renderer = new Renderer(this.canvas);
    this.input = new Input(this.canvas);
    this.audio = new Audio();
    this.music = new Music(this.audio);
    this.tex = buildTextures();
    this.scene = new THREE.Scene();
    this.scene.fog = new THREE.Fog(0x2a0806, 30, 140);
    this.camera = new THREE.PerspectiveCamera(settings.fov, 1, 0.05, 1500);
    this.camera.rotation.order = 'YXZ';
    this.setupLights();
    this.world = new World();
    this.fx = new FX(this);
    this.goreMat = psx(new THREE.MeshLambertMaterial({ map: this.tex.flesh, color: 0xff9090 }));
    this.level = new Level(this);
    buildLevel01(this.level);
    this.player = new Player(this);
    this.weapons = new Weapons(this);
    this.style = new Style(this);
    this.hud = new HUD(this, this.uiRoot);
    this.touch = new TouchControls(this, this.uiRoot);
    this.input.touchMode = this.touch.active;
    this.ui = new UI(this, this.uiRoot);
    this.hud.el.querySelector('#deathscreen').addEventListener('click', () => { if (this.deathT > 0.5) this.respawn(); });
    this.arenas = new Arenas(this);
    this.enemies = [];
    this.projectiles = [];
    this.decor = [];
    this.events = [];
    this.state = 'splash';
    this.time = 0;
    this.realTime = 0;
    this.hitstopT = 0;
    this.trauma = 0;
    this.parryHintT = 0;
    this.deathT = 0;
    this.fps = 0;
    this.frames = 0;
    this.fpsT = 0;
    this.god = false;
    this.stats = { time: 0, kills: 0, restarts: 0, secrets: 0, parries: 0, damageTaken: 0 };
    this.checkpoint = { pos: new THREE.Vector3(0, 0, 6), yaw: 0 };
    this.totalEnemies = this.level.totalEnemies + this.level.extraEnemies.reduce((n, x) => n + x.list.length, 0);
    for (const ex of this.level.extraEnemies) {
      ex.trig = this.level.trigger(ex.trigger, () => { for (const s of ex.list) this.spawnEnemy(s.t, s.p, null); });
    }
    this.spawnDecor();
    this.onResize();
    window.addEventListener('resize', () => this.onResize());
    this.input.onLockChange = (locked, failed) => this.onLockChange(locked, failed);
    this.input.anyKeyHandlers.push((e) => this.onKey(e));
    this.ui.show('splash');
    this.lastT = performance.now();
    this.loop = this.loop.bind(this);
    requestAnimationFrame(this.loop);
  }

  // ---------------------------------------------------------------- ışıklar
  setupLights() {
    const s = this.scene;
    this.hemi = new THREE.HemisphereLight(0xffa888, 0x3a1410, 1.9);
    s.add(this.hemi);
    s.add(new THREE.AmbientLight(0x5a3030, 0.9));
    this.sun = new THREE.DirectionalLight(0xff9a70, 1.3);
    this.sun.position.set(0.4, 1, 0.6);
    s.add(this.sun);
    this.pool = [];
    for (let i = 0; i < 6; i++) {
      const l = new THREE.PointLight(0xff8040, 0, 22, 1.2);
      l.userData.base = 0;
      s.add(l);
      this.pool.push(l);
    }
    this.flashes = [];
    for (let i = 0; i < 2; i++) {
      const l = new THREE.PointLight(0xffffff, 0, 12, 1);
      s.add(l);
      this.flashes.push({ l, t: 0, dur: 1, base: 0 });
    }
    this.flashIdx = 0;
    this.lightT = 0;
  }

  flashLight(pos, color, intensity, dist, dur) {
    const f = this.flashes[this.flashIdx];
    this.flashIdx = (this.flashIdx + 1) % this.flashes.length;
    f.l.position.copy(pos);
    f.l.color.setHex(color);
    f.l.distance = dist;
    f.base = intensity * 6;
    f.t = dur;
    f.dur = dur;
    f.l.intensity = f.base;
  }

  updateLights(dt) {
    this.lightT -= dt;
    const cp = this.camera.position;
    if (this.lightT <= 0) {
      this.lightT = 0.2;
      const lamps = this.level.lamps.filter((l) => !l.secret || !l.secret.taken);
      lamps.sort((a, b) => a.pos.distanceToSquared(cp) - b.pos.distanceToSquared(cp));
      for (let i = 0; i < this.pool.length; i++) {
        const l = this.pool[i];
        const lamp = lamps[i];
        if (lamp && lamp.pos.distanceTo(cp) < 70) {
          l.position.copy(lamp.pos);
          l.color.setHex(lamp.color);
          l.userData.base = lamp.power * 14;
        } else l.userData.base = 0;
      }
    }
    const t = this.realTime;
    for (let i = 0; i < this.pool.length; i++) {
      const l = this.pool[i];
      l.intensity = l.userData.base * (0.85 + 0.12 * Math.sin(t * 13 + i * 7) * Math.sin(t * 7.3 + i));
    }
    for (const f of this.flashes) {
      if (f.t > 0) {
        f.t -= dt;
        f.l.intensity = f.base * Math.max(0, f.t / f.dur);
      } else f.l.intensity = 0;
    }
  }

  // ---------------------------------------------------------------- yardımcılar
  onResize() {
    const a = window.innerWidth / Math.max(1, window.innerHeight);
    this.camera.aspect = a;
    this.camera.updateProjectionMatrix();
    this.weapons.resize(a);
  }

  applySettings() {
    this.input.touchMode = this.touch.active;
    this.renderer.applyScale();
    this.audio.applyVolumes();
    this.camera.fov = settings.fov;
    this.camera.updateProjectionMatrix();
  }

  schedule(delay, fn) {
    this.events.push({ t: this.time + delay, fn });
  }

  hitstop(t) {
    this.hitstopT = Math.max(this.hitstopT, t);
  }

  shake(amount) {
    this.trauma = Math.min(1, this.trauma + amount);
  }

  spawnEnemy(type, p, arena) {
    const Cls = ENEMY_TYPES[type];
    const pos = Array.isArray(p) ? new THREE.Vector3(...p) : p.clone();
    const pl = this.player.pos;
    const e = new Cls(this, pos, { yaw: yawTo(pl.x - pos.x, pl.z - pos.z), arena });
    this.enemies.push(e);
    if (arena) arena.enemies.push(e);
    return e;
  }

  addProjectile(p) {
    this.projectiles.push(p);
    return p;
  }

  spawnDecor() {
    this.clearDecor();
    const list = [['filth', [-4, 0, -6], 0.4], ['filth', [5, 0, -9], -0.3], ['filth', [-7, 0, 1], 1.2], ['schism', [2, 0, -12], 0.1], ['stray', [0, 3, 13.5], Math.PI]];
    for (const [t, p, yaw] of list) {
      const e = new ENEMY_TYPES[t](this, new THREE.Vector3(...p), { decor: true, yaw });
      e.update(0.016);
      this.decor.push(e);
    }
  }

  clearDecor() {
    for (const e of this.decor) e.removeSilently();
    this.decor = [];
  }

  // ---------------------------------------------------------------- hasar & savaş
  damagePlayer(dmg, fromPos, ignoreIframes = false) {
    const p = this.player;
    if (p.dead || this.state !== 'playing') return false;
    if (!ignoreIframes && p.iframes > 0) return false;
    if (this.god) { this.hud.damage(dmg); return true; }
    p.damage(dmg);
    this.stats.damageTaken += dmg;
    this.style.onDamageTaken(dmg);
    this.hud.damage(dmg);
    this.shake(0.22 + Math.min(dmg, 40) * 0.008);
    this.audio.play('hurt');
    if (fromPos) {
      _v.set(p.pos.x - fromPos.x, 0, p.pos.z - fromPos.z);
      if (_v.lengthSq() > 0.001) {
        _v.normalize();
        p.vel.x += _v.x * 6;
        p.vel.z += _v.z * 6;
      }
    }
    if (p.hp <= 0) this.playerDie();
    return true;
  }

  bloodHeal(pt, dmg) {
    const p = this.player;
    if (p.dead) return;
    const d = pt.distanceTo(p.eyePos(_v2));
    if (d < 8) {
      const amt = dmg * 32 * (1 - d / 8) + 1.5;
      if (p.heal(amt) > 0.5) this.audio.play('heal');
    }
  }

  hitscan(o, d, max = 300, opts = {}) {
    const w = this.world.raycast(o.x, o.y, o.z, d.x, d.y, d.z, max);
    const tW = w ? w.t : max;
    const hits = [];
    for (const e of this.enemies) {
      if (e.dead || (e.state === 'spawn' && e.st < 0.15)) continue;
      const h = e.raycast(o, d, tW);
      if (h) hits.push(h);
    }
    const sphere = (c, r, extra) => {
      const ox = o.x - c.x, oy = o.y - c.y, oz = o.z - c.z;
      const b = ox * d.x + oy * d.y + oz * d.z;
      const cc = ox * ox + oy * oy + oz * oz - r * r;
      const disc = b * b - cc;
      if (disc < 0) return;
      const t = -b - Math.sqrt(disc);
      if (t < 0 || t > tW) return;
      hits.push({ t, point: new THREE.Vector3(o.x + d.x * t, o.y + d.y * t, o.z + d.z * t), ...extra });
    };
    if (opts.coins) for (const c of this.weapons.coins) if (c.alive) sphere(c.pos, 0.55, { coin: c });
    if (opts.cores) for (const pr of this.projectiles) if (!pr.dead && pr.kind === 'core' && pr.owner === 'player') sphere(pr.pos, 0.6, { core: pr });
    hits.sort((a, b) => a.t - b.t);
    return { hits, world: w, end: new THREE.Vector3(o.x + d.x * tW, o.y + d.y * tW, o.z + d.z * tW) };
  }

  explode(pos, radius, dmg, opts = {}) {
    if (opts.small) {
      this.fx.shell(pos, 0xbfe6ff, radius, 0.3);
      this.fx.sparkBurst(pos, 16, radius * 3, 0x9fd8ff, 0.4, 0.08);
      this.audio.play('projHit', pos, { vol: 1.5 });
    } else {
      this.fx.explosionFX(pos, radius);
      this.audio.play('explosion', pos);
      const dd = pos.distanceTo(this.camera.position);
      this.shake(clamp(0.8 - dd / 30, 0.1, 0.7));
    }
    if (opts.visualOnly) return;
    for (const e of this.enemies) {
      if (e.dead) continue;
      const c = e.center(_v);
      const dist = c.distanceTo(pos);
      if (dist < radius + e.r) {
        const k = 1 - clamp(dist / radius, 0, 1) * 0.6;
        const dir = c.clone().sub(pos);
        dir.y = Math.max(dir.y, 0) + 0.6;
        dir.normalize();
        e.hit({ dmg: dmg * k, part: 'body', point: c.clone(), dir, knock: opts.knock || 15, explosion: true, weapon: opts.weapon || 'explosion', noHeal: false });
      }
    }
    if (opts.playerDmg > 0) {
      const p = this.player;
      const pc = _v.set(p.pos.x, p.pos.y + p.h * 0.5, p.pos.z);
      const dist = pc.distanceTo(pos);
      if (dist < radius) {
        const k = 1 - (dist / radius) * 0.5;
        const dir = pc.clone().sub(pos).normalize();
        if (this.damagePlayer(opts.playerDmg * k, null)) {
          p.vel.addScaledVector(dir, (opts.knock || 15) * k);
          p.vel.y = Math.max(p.vel.y, 12 * k);
          p.grounded = false;
        }
      }
    }
  }

  // Feedbacker: mermi ve yakın saldırı savuşturma
  tryParry() {
    const p = this.player;
    const o = p.eyePos();
    const d = p.aimDir();
    const list = [];
    for (const pr of this.projectiles) {
      if (pr.dead || pr.owner !== 'enemy' || !pr.parryable) continue;
      _v.subVectors(pr.pos, o);
      const dist = _v.length();
      if (dist > 4.8) continue;
      const dot = _v.dot(d) / (dist || 1);
      if (dot > 0.3 || dist < 1.8) list.push(pr);
    }
    if (list.length) {
      const r = this.hitscan(o, d, 300, {});
      const target = r.hits[0] ? r.hits[0].point : r.end;
      for (const pr of list) {
        const dir = target.clone().sub(pr.pos).normalize();
        pr.parry(dir, Math.max(pr.vel.length() * 1.6, 60));
      }
      this.onParry(list[0].pos.clone(), list.length);
      return true;
    }
    let best = null, bd = 1e9;
    for (const e of this.enemies) {
      if (e.dead || !e.parryable) continue;
      const c = e.center(_v);
      const dist = c.distanceTo(o);
      if (dist > 4.8 + e.r) continue;
      const to = c.clone().sub(o).normalize();
      if (to.dot(d) < 0.25 && dist > 2) continue;
      if (dist < bd) { bd = dist; best = e; }
    }
    if (best) {
      const pos = best.center();
      best.parried(d.clone());
      this.onParry(pos, 1, true);
      return true;
    }
    for (const pr of this.projectiles) {
      if (pr.dead || pr.owner !== 'player' || pr.kind !== 'core') continue;
      _v.subVectors(pr.pos, o);
      const dist = _v.length();
      if (dist < 4 && _v.dot(d) / (dist || 1) > 0.2) {
        pr.vel.copy(d).multiplyScalar(55);
        pr.boosted = true;
        pr.gravity = 4;
        this.style.add('PROJECTILE BOOST', 90, 'shotgun');
        this.hitstop(0.06);
        this.audio.play('punchHit', pr.pos);
        return true;
      }
    }
    return false;
  }

  onParry(pos, n = 1, melee = false) {
    const p = this.player;
    this.stats.parries++;
    p.hp = 100;
    p.hard = 0;
    this.audio.play('parry');
    this.hitstop(melee ? 0.2 : 0.14);
    this.hud.flash('rgba(255,255,255,0.85)', 0.22);
    this.shake(0.35);
    this.fx.sprite(pos, 0xffffff, 4, 0.3, 'star', 2);
    this.fx.sparkBurst(pos, 24, 12, 0xbfe6ff, 0.5, 0.08);
    this.style.add('PARRY', 150, null, { count: n > 1 ? n : 0 });
    if (melee) this.style.add('INTERRUPTION', 60);
  }

  meleePunch() {
    const p = this.player;
    const o = p.eyePos();
    const d = p.aimDir();
    let best = null, bd = 1e9;
    for (const e of this.enemies) {
      if (e.dead || e.state === 'spawn') continue;
      const c = e.center(_v);
      const dist = c.distanceTo(o) - e.r;
      if (dist > 3.2) continue;
      const to = c.clone().sub(o).normalize();
      if (to.dot(d) < 0.45) continue;
      if (dist < bd) { bd = dist; best = e; }
    }
    if (best) {
      const c = best.center();
      const dir = d.clone();
      dir.y = Math.max(dir.y, 0.35);
      best.hit({ dmg: 1, part: 'body', point: c, dir, knock: 14, weapon: 'punch' });
      this.audio.play('punchHit', c);
      this.shake(0.15);
      this.hitstop(0.05);
      this.fx.sparkBurst(c, 10, 7, 0xffffff, 0.25, 0.06);
      return true;
    }
    return false;
  }

  onSlamLand(pos, fall) {
    for (const e of this.enemies) {
      if (e.dead || e.state === 'spawn') continue;
      const dx = e.pos.x - pos.x, dz = e.pos.z - pos.z;
      const dist = Math.hypot(dx, dz);
      if (dist < 4 && Math.abs(e.pos.y - pos.y) < 1.5) {
        e.vel.y = e.boss ? 4 : 11;
        e.grounded = false;
        e.hit({ dmg: 0.25, part: 'body', point: e.center(), dir: new THREE.Vector3(dx / (dist || 1), 0.5, dz / (dist || 1)), knock: 6, weapon: null });
      }
    }
  }

  onEnemyKilled(e) {
    if (e.decor) return;
    this.stats.kills++;
  }

  onBossDefeated() {
    this.hud.message('SWORDSMACHINE YOK EDİLDİ', 2.5, 'big');
    this.music.setMode('calm');
    this.schedule(2.0, () => {
      this.level.doors.hatch.open();
      this.hud.hint('Çıkış açıldı — arenanın ortasındaki DELİĞE atla!', 10);
    });
  }

  // ---------------------------------------------------------------- durumlar
  onSplashClick() {
    this.audio.init();
    this.audio.play('uiClick');
    this.toMenu();
  }

  toMenu() {
    this.state = 'menu';
    this.input.gameActive = false;
    this.input.wantLock = false;
    this.input.exitLock();
    this.hud.show(false);
    this.hud.reset();
    this.resetLevelState();
    this.spawnDecor();
    this.ui.show('menu');
    this.ui.showPanel('play');
    this.audio.stopAllLoops();
    this.audio.muffle(0);
    this.music.setMode('menu');
  }

  startIntro() {
    this.state = 'intro';
    this.music.setMode('off');
    this.ui.startIntro();
  }

  resetLevelState() {
    for (const e of this.enemies) e.removeSilently();
    this.enemies = [];
    for (const p of this.projectiles) p.remove();
    this.projectiles = [];
    for (const c of this.weapons.coins) c.kill();
    this.weapons.coins = [];
    this.fx.clearAll();
    this.fx.clearDecals();
    for (const id in this.level.doors) this.level.doors[id].reset();
    this.arenas.resetAll();
    this.level.resetTriggers();
    for (const s of this.level.secrets) { s.taken = false; s.group.visible = true; }
    this.events = [];
    this.hud.boss(null);
    this.levelDone = false;
  }

  startLevel() {
    this.audio.init();
    this.ui.hideAll();
    progress.introSeen = true;
    saveProgress();
    this.clearDecor();
    this.resetLevelState();
    this.hud.reset();
    this.hud.show(true);
    this.player.reset(new THREE.Vector3(0, 48, 3), 0);
    this.player.pitch = -0.45;
    this.checkpoint = { pos: new THREE.Vector3(0, 0, 6), yaw: 0 };
    this.weapons.reset();
    this.style.reset(true);
    this.stats = { time: 0, kills: 0, restarts: 0, secrets: 0, parries: 0, damageTaken: 0 };
    this.time = 0;
    this.state = 'playing';
    this.input.gameActive = true;
    this.input.wantLock = true;
    this.input.requestLock();
    if (this.touch.active && !document.fullscreenElement && !document.webkitFullscreenElement) this.touch.toggleFullscreen();
    this.audio.muffle(0);
    this.music.setMode('calm');
    this.hud.titleCard('<div class="tc-layer">KATMAN 0: ARAF /// 0-1</div><div class="tc-name">İLK KAN</div>', 4.5);
    this.schedule(2.6, () => this.hud.hint(this.touch.active
      ? 'Sol joystick: yürü · sağa sürükle: bak · [ATIL] ile dash at — atılırken hasar almazsın · [KAY] yerde kayar, havada yere çakar'
      : '[WASD] hareket · [BOŞLUK] zıpla · [SHIFT] atıl — atılırken hasar almazsın · [C] kay / yere çak', 8));
  }

  setCheckpoint(pos, yaw) {
    if (this.checkpoint.pos.distanceTo(pos) < 0.5) return;
    this.checkpoint = { pos: pos.clone(), yaw };
    this.hud.message('CHECKPOINT', 1.5, 'cp');
    this.audio.play('checkpoint');
  }

  playerDie() {
    const p = this.player;
    p.dead = true;
    p.hp = 0;
    this.state = 'dead';
    this.deathT = 0;
    this.hud.death(true);
    this.audio.play('death');
    this.audio.muffle(0.85);
    this.audio.stopAllLoops();
    this.fx.bloodBurst(p.eyePos(), 50, 8, null, true);
    this.style.reset(false);
  }

  respawn(fromPause = false) {
    if (this.state !== 'dead' && !(fromPause && this.state === 'paused')) return;
    this.arenas.resetActive();
    for (const pr of this.projectiles) pr.remove();
    this.projectiles = [];
    for (const c of this.weapons.coins) c.kill();
    this.weapons.coins = [];
    const cur = this.weapons.cur, variant = [...this.weapons.variant];
    this.weapons.reset();
    this.weapons.cur = cur;
    this.weapons.variant = variant;
    this.weapons.updateAccents();
    this.player.reset(this.checkpoint.pos.clone(), this.checkpoint.yaw);
    this.style.reset(false);
    this.stats.restarts++;
    this.hud.death(false);
    this.hud.boss(null);
    this.hud.weaponChanged();
    this.ui.hideAll();
    this.state = 'playing';
    this.input.gameActive = true;
    this.input.wantLock = true;
    if (!this.input.locked) this.input.requestLock();
    this.audio.muffle(0);
    this.music.setMode('calm');
  }

  pause() {
    if (this.state !== 'playing') return;
    this.state = 'paused';
    this.pauseTime = performance.now();
    this.ui.show('pause');
    this.input.exitLock();
    this.audio.muffle(0.6);
    this.audio.stopAllLoops();
    this.hud.stats(false);
    this.hud.hideTitle();
  }

  resume() {
    if (this.state !== 'paused') return;
    this.state = 'playing';
    this.ui.hideAll();
    this.input.requestLock();
    this.audio.muffle(0);
  }

  onLockChange(locked, failed) {
    if (failed) {
      this.hud.lockHint(true, this.input.lockFailed);
      setTimeout(() => this.hud.lockHint(false), 7000);
      return;
    }
    if (locked) this.hud.lockHint(false);
    if (!locked && this.state === 'playing' && !this.input.lockFailed) this.pause();
  }

  onKey(e) {
    if (this.state === 'splash') { this.onSplashClick(); return; }
    if (this.state === 'intro' && (e.code === 'Space' || e.code === 'Enter' || e.code === 'Escape')) { this.ui.introClick(); return; }
    if (e.code === 'Escape') {
      if (this.state === 'playing' && (!this.input.locked || this.input.lockFailed)) this.pause();
      else if (this.state === 'paused' && performance.now() - (this.pauseTime || 0) > 400) this.resume();
    }
    if (this.state === 'dead' && e.code === 'KeyR' && this.deathT > 0.4) this.respawn();
  }

  levelComplete() {
    if (this.levelDone) return;
    this.levelDone = true;
    this.state = 'results';
    this.input.gameActive = false;
    this.input.wantLock = false;
    this.input.exitLock();
    this.style.frozen = true;
    this.hud.show(false);
    this.audio.stopAllLoops();
    this.music.setMode('calm');
    this.hud.flash('rgba(255,255,255,1)', 0.8);
    const s = this.stats;
    const r = {
      time: s.time,
      kills: s.kills,
      killsTotal: this.totalEnemies,
      style: Math.round(this.style.total),
      secrets: s.secrets,
      secretsTotal: this.level.secrets.length,
      parries: s.parries,
      restarts: s.restarts,
      damage: s.damageTaken,
      difficulty: difficulty().name,
    };
    r.timeRank = rankTime(r.time);
    r.killRank = rankKills(r.kills / Math.max(1, r.killsTotal));
    r.styleRank = rankStyle(r.style);
    r.final = finalRank([r.timeRank, r.killRank, r.styleRank], r.restarts);
    r.challenge = r.parries >= 5;
    r.newBest = betterRank(progress.bestRank, r.final) || (progress.bestRank === r.final && (!progress.bestTime || r.time < progress.bestTime));
    if (r.newBest) { progress.bestRank = r.final; progress.bestTime = r.time; }
    progress.bestStyle = Math.max(progress.bestStyle || 0, r.style);
    saveProgress();
    this.lastResults = r;
    this.ui.showResults(r);
  }

  // ---------------------------------------------------------------- döngü
  loop(now) {
    requestAnimationFrame(this.loop);
    const realDt = Math.min(0.05, Math.max(0, (now - this.lastT) / 1000));
    this.lastT = now;
    this.step(realDt);
  }

  step(realDt, render = true) {
    this.realTime += realDt;
    this.frames++;
    this.fpsT += realDt;
    if (this.fpsT >= 0.5) { this.fps = Math.round(this.frames / this.fpsT); this.frames = 0; this.fpsT = 0; }
    let dt = realDt;
    if (this.hitstopT > 0) {
      this.hitstopT -= realDt;
      dt = 0;
    }
    const st = this.state;
    if (st === 'playing' || st === 'dead') this.updatePlaying(dt, realDt);
    else if (st === 'menu' || st === 'splash' || st === 'intro') this.updateMenu(realDt);
    else if (st === 'results') this.updateResults(realDt);
    if (st === 'intro') this.ui.updateIntro(realDt);
    const showVM = st === 'playing' || st === 'paused';
    this.touch.update();
    if (render) this.renderer.render(this.scene, this.camera, showVM && !this.player.dead ? this.weapons.scene : null, this.weapons.cam);
    this.input.endFrame();
  }

  updateMenu(dt) {
    this.time += dt;
    const t = this.realTime * 0.06;
    const cam = this.camera;
    cam.position.set(Math.sin(t) * 15, 5.5 + Math.sin(t * 2.3) * 0.8, -3 + Math.cos(t) * 15);
    cam.lookAt(0, 2.2, -3);
    if (Math.abs(cam.fov - 75) > 0.01) { cam.fov = 75; cam.updateProjectionMatrix(); }
    for (const e of this.decor) e.update(dt);
    this.level.update(dt, this.time, cam.position);
    this.fx.update(dt);
    this.updateLights(dt);
    this.audio.setListener(cam.position, 0);
  }

  updateResults(dt) {
    const cam = this.camera;
    cam.rotation.y += dt * 0.05;
    this.level.update(dt, this.realTime, cam.position);
    this.fx.update(dt);
    this.updateLights(dt);
  }

  updatePlaying(dt, realDt) {
    const input = this.input;
    const p = this.player;
    if (this.state === 'playing') {
      this.time += dt;
      this.stats.time += realDt;
      p.look(input, realDt);
      p.update(dt, input);
      this.weapons.update(dt, input);
      this.hud.stats(input.is('stats'));
    } else {
      this.time += dt;
      this.deathT += realDt;
      if (this.deathT > 0.6 && (input.pressed('restart') || input.pressed('fire'))) {
        this.respawn();
        return;
      }
    }

    // olay zamanlayıcıları
    for (let i = this.events.length - 1; i >= 0; i--) {
      if (this.time >= this.events[i].t) {
        const ev = this.events[i];
        this.events.splice(i, 1);
        ev.fn();
      }
    }

    // düşmanlar
    for (const e of this.enemies) e.update(dt);
    this.separate();
    this.enemies = this.enemies.filter((e) => !e.dead);
    // mermiler
    this.parryHintT = Math.max(0, this.parryHintT - realDt);
    const eye = p.eyePos(_v2);
    for (const pr of this.projectiles) {
      pr.update(dt);
      if (!pr.dead && pr.owner === 'enemy' && pr.parryable && pr.pos.distanceTo(eye) < 5) this.parryHintT = 0.1;
    }
    this.projectiles = this.projectiles.filter((pr) => !pr.dead);

    if (this.state === 'playing') {
      this.arenas.update(dt);
      this.checkTriggers();
      this.checkSecrets();
    }
    this.level.update(dt, this.time, this.camera.position);
    this.fx.update(dt);
    this.style.update(dt, this.weapons.curId);
    this.music.setStyleRank(this.style.rank);
    this.updateCamera(dt, realDt);
    this.updateLights(dt);
    this.hud.update(dt, realDt);
  }

  separate() {
    const E = this.enemies;
    const world = this.world;
    for (let i = 0; i < E.length; i++) {
      const a = E[i];
      if (a.dead) continue;
      for (let j = i + 1; j < E.length; j++) {
        const b = E[j];
        if (b.dead) continue;
        const dx = b.pos.x - a.pos.x, dz = b.pos.z - a.pos.z;
        const min = a.r + b.r;
        const d2 = dx * dx + dz * dz;
        if (d2 < min * min && Math.abs(a.pos.y - b.pos.y) < 1.5) {
          const d = Math.sqrt(d2) || 0.01;
          const push = (min - d) * 0.5;
          const nx = dx / d, nz = dz / d;
          world.moveBody(a, -nx * push, 0, -nz * push);
          world.moveBody(b, nx * push, 0, nz * push);
        }
      }
    }
    // oyuncu ↔ düşman
    const p = this.player;
    if (p.dead) return;
    for (const e of E) {
      if (e.dead) continue;
      const dx = p.pos.x - e.pos.x, dz = p.pos.z - e.pos.z;
      const min = p.r + e.r;
      const d2 = dx * dx + dz * dz;
      if (d2 < min * min && p.pos.y < e.pos.y + e.h && p.pos.y + p.h > e.pos.y) {
        const d = Math.sqrt(d2) || 0.01;
        const push = min - d;
        world.moveBody(p, (dx / d) * push * 0.7, 0, (dz / d) * push * 0.7);
        world.moveBody(e, -(dx / d) * push * 0.3, 0, -(dz / d) * push * 0.3);
      }
    }
  }

  checkTriggers() {
    const p = this.player.pos;
    const px = p.x, py = p.y + 0.5, pz = p.z;
    for (const t of this.level.triggers) {
      if (t.fired && t.once) continue;
      const b = t.box;
      if (px > b[0] && px < b[3] && py > b[1] && py < b[4] && pz > b[2] && pz < b[5]) {
        t.fired = true;
        t.fn();
      }
    }
  }

  checkSecrets() {
    const p = this.player;
    const c = _v.set(p.pos.x, p.pos.y + 0.9, p.pos.z);
    for (const s of this.level.secrets) {
      if (s.taken) continue;
      if (s.group.position.distanceTo(c) < 1.5) {
        s.taken = true;
        s.group.visible = false;
        this.stats.secrets++;
        this.audio.play('secret');
        this.hud.message(`GİZLİ KÜRE  ${this.stats.secrets} / ${this.level.secrets.length}`, 2.5, 'secret');
        this.fx.sparkBurst(s.group.position.clone(), 30, 8, 0x80c8ff, 0.8, 0.08, 0);
        this.fx.ring(s.group.position.clone(), 0x80c8ff, 3, 0.6, 0);
      }
    }
  }

  updateCamera(dt, realDt) {
    const p = this.player;
    const cam = this.camera;
    this.trauma = Math.max(0, this.trauma - realDt * 1.6);
    const sh = this.trauma * this.trauma * settings.shake;
    let eye = p.eye + p.landDip;
    let roll = p.tilt;
    if (p.dead) {
      const k = Math.min(1, this.deathT / 0.8);
      eye = p.eye * (1 - k) + 0.25 * k;
      roll = 0.5 * k;
    }
    const bobY = -Math.abs(Math.sin(p.bobT * 0.95)) * 0.07 * p.bob;
    const bobX = Math.sin(p.bobT * 0.95) * 0.025 * p.bob;
    const cx = Math.cos(p.yaw), cz = -Math.sin(p.yaw);
    cam.position.set(
      p.pos.x + cx * bobX + rand(-1, 1) * sh * 0.2,
      p.pos.y + eye + bobY + rand(-1, 1) * sh * 0.2,
      p.pos.z + cz * bobX + rand(-1, 1) * sh * 0.2
    );
    cam.rotation.set(p.pitch + rand(-1, 1) * sh * 0.03, p.yaw + rand(-1, 1) * sh * 0.03, roll + rand(-1, 1) * sh * 0.04);
    const fov = settings.fov + p.fovKick + (p.sliding ? 5 : 0);
    if (Math.abs(cam.fov - fov) > 0.05) {
      cam.fov = damp(cam.fov, fov, 12, realDt);
      cam.updateProjectionMatrix();
    }
    this.audio.setListener(cam.position, p.yaw);
  }
}

function boot() {
  try {
    const game = new Game();
    window.__uk = game;
    window.__ukProjectile = Projectile;
  } catch (err) {
    console.error(err);
    const d = document.createElement('div');
    d.className = 'fatal';
    d.textContent = 'Oyun başlatılamadı (WebGL gerekli): ' + err.message;
    document.body.appendChild(d);
  }
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
else boot();
