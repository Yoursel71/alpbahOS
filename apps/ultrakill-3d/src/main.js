// ULTRAKILL 3D (hayran yapımı) — oyun döngüsü ve durum makinesi.
import * as THREE from 'three';
import { settings, loadSettings, progress, saveProgress, difficulty } from './settings.js';
import { Input } from './input.js';
import { Audio } from './audio.js';
import { Music } from './music.js';
import { buildTextures } from './textures.js';
import { Renderer, psx } from './render.js';
import { World } from './physics.js';
import { Level } from './level.js';
import { LEVELS } from './levels/index.js';
import { SHOP_ITEMS, ITEM_HINTS } from './shop.js';
import { Player } from './player.js';
import { Weapons } from './weapons.js';
import { FX } from './fx.js';
import { Style } from './style.js';
import { HUD } from './hud.js';
import { UI, rankTime, rankKills, rankStyle, finalRank, betterRank } from './ui.js';
import { ENEMY_TYPES } from './enemies.js';
import { rand, clamp, damp, yawTo, wrapAngle } from './util.js';
import { Projectile } from './projectiles.js';
import { WEAPONS } from './weapons.js';
import { TouchControls, touchDevice } from './touch.js';

const _v = new THREE.Vector3();
const _v2 = new THREE.Vector3();

class Arenas {
  constructor(game) {
    this.game = game;
    this.list = game.level.arenas;
  }

  // prespawn: arenanın ilk dalgası bölüm başında yerinde bekler (ör. uyuyan Cerberus heykelleri)
  prespawn() {
    const g = this.game;
    for (const a of this.list) {
      if (!a.prespawn || a.state !== 'idle' || a.pre) continue;
      a.pre = a.waves[0].map((s) => g.spawnEnemy(s.t, s.p, null, { ...(s.opts || {}), instant: true }));
    }
  }

  start(a) {
    const g = this.game;
    if (a.state !== 'idle' || g.state !== 'playing') return;
    a.state = 'active';
    a.wave = -1;
    a.enemies = [];
    a.delay = a.boss ? 2.4 : 0.35;
    for (const id of a.lock) { const d = g.level.doors[id]; d.saved = d.target > 0.5; d.close(); }
    a.killsAtStart = g.stats.kills;
    a.bossList = [];
    if (a.boss) {
      g.music.setMode('boss');
      g.hud.titleCard(`<div class="tc-boss-sub">${a.bossSub || 'BOSS'}</div><div class="tc-boss">${a.name}</div>`, 3.2);
      g.audio.play('bossRoar');
    } else g.music.setMode('combat');
    if (a.pre) {
      a.wave = 0;
      a.enemies = a.pre.filter((e) => !e.dead);
      for (const e of a.enemies) { e.arena = a; if (e.boss) a.bossList.push(e); }
      a.pre = null;
      a.delay = 0.9;
      if (a.onWave) a.onWave(g, 0, a);
    }
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
        for (const s of a.waves[a.wave]) {
          const e = g.spawnEnemy(s.t, s.p, a, s.opts);
          if (e.boss) a.bossList.push(e);
        }
        if (a.onWave) a.onWave(g, a.wave, a);
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
      for (const e of a.bossList || []) e.removeSilently();
      a.enemies = [];
      a.bossList = [];
      a.pre = null;
      if (a.killsAtStart !== undefined) g.stats.kills = a.killsAtStart;
      a.state = 'idle';
      a.wave = -1;
      a.trig.fired = false;
      for (const id of a.lock) { const d = g.level.doors[id]; d.setInstant(d.saved ?? d.initialOpen); }
      for (const id of a.exits) g.level.doors[id].reset();
    }
  }

  resetAll() {
    for (const a of this.list) {
      a.state = 'idle';
      a.wave = -1;
      a.enemies = [];
      a.bossList = [];
      a.pre = null;
    }
  }
}

class Game {
  constructor() {
    const hadSettings = loadSettings();
    this.mobile = touchDevice();
    if (!hadSettings && this.mobile) { settings.resScale = 0.42; settings.shake = 0.8; }
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
    this.level = null;
    this.levelIdx = -1;
    this.player = new Player(this);
    this.weapons = new Weapons(this);
    this.style = new Style(this);
    this.hud = new HUD(this, this.uiRoot);
    this.touch = new TouchControls(this, this.uiRoot);
    this.input.touchMode = this.touch.active;
    this.ui = new UI(this, this.uiRoot);
    this.hud.el.querySelector('#deathscreen').addEventListener('click', () => { if (this.deathT > 1.0) this.respawn(); });
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
    this.corpses = [];
    this.shocks = [];
    this.bankedStyle = 0;
    this.bonusP = 0;
    this.levelP = 0;
    this.aimFriction = 1;
    this.frameAcc = 0;
    this.loadLevel(Math.min(Math.max(0, (progress.unlocked || 1) - 1), LEVELS.length - 1));
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
    this.ambient = new THREE.AmbientLight(0x5a3030, 0.9);
    s.add(this.ambient);
    this.sun = new THREE.DirectionalLight(0xff9a70, 1.3);
    this.sun.position.set(0.4, 1, 0.6);
    s.add(this.sun);
    this.pool = [];
    // mobilde daha az dinamik ışık (gölgelendirici maliyeti)
    for (let i = 0; i < (this.mobile ? 4 : 6); i++) {
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

  // ---------------------------------------------------------------- bölümler
  // Bölümü kur (zaten yüklüyse bir şey yapmaz). Eski bölüm sahneden ve fizik dünyasından tamamen kalkar.
  loadLevel(idx) {
    idx = clamp(idx | 0, 0, LEVELS.length - 1);
    if (this.level && this.levelIdx === idx) return false;
    if (this.level) {
      this.resetLevelState();
      this.clearDecor();
      this.level.dispose();
    }
    this.world.clear();
    this.levelIdx = idx;
    this.levelDef = LEVELS[idx];
    const L = new Level(this);
    this.level = L;
    this.levelDef.build(L);
    this.applyTheme(L.theme);
    this.attachPickupModels();
    this.arenas = new Arenas(this);
    this.totalEnemies = L.totalEnemies + L.extraEnemies.reduce((n, x) => n + x.list.length, 0);
    for (const ex of L.extraEnemies) {
      if (!ex.trigger) continue;
      ex.trig = L.trigger(ex.trigger, () => { for (const s of ex.list) this.spawnEnemy(s.t, s.p, null); });
    }
    this.checkpoint = { pos: new THREE.Vector3(...L.spawn.checkpoint), yaw: L.spawn.yaw };
    return true;
  }

  applyTheme(th) {
    this.scene.fog.color.setHex(th.fog);
    this.scene.fog.near = th.fogNear;
    this.scene.fog.far = th.fogFar;
    this.hemi.color.setHex(th.hemiSky);
    this.hemi.groundColor.setHex(th.hemiGround);
    this.hemi.intensity = th.hemi;
    this.ambient.color.setHex(th.ambient);
    this.sun.color.setHex(th.sun);
  }

  // Sunaklarda dönen silah/kol modelleri
  attachPickupModels() {
    for (const pk of this.level.pickups) {
      const src = typeof pk.weapon === 'number' ? this.weapons.models[pk.weapon].gun : pk.weapon === 'knuckle' ? this.weapons.armModels[1] : this.weapons.hookHand;
      const m = src.clone();
      m.visible = true;
      m.traverse((o) => { o.visible = true; });
      m.position.set(0, 0, 0);
      m.rotation.set(0, Math.PI / 2, 0);
      m.scale.setScalar(2.6);
      pk.holder.add(m);
    }
  }

  // Dükkân sahipliğini silahlara uygula (test modu: her şey)
  applyLoadout() {
    if (settings.allWeapons) this.weapons.giveAll();
    else this.weapons.applyLoadout(progress.shop);
  }

  // ---------------------------------------------------------------- P (stil puanı parası)
  // Stil puanı anında P olarak birikir; checkpoint'te, dükkânda ve bölüm sonunda kasaya girer.
  // Ölünce son checkpoint'ten beri kazanılan P kaybolur.
  get unbankedP() {
    return Math.max(0, Math.floor(this.style.total) - this.bankedStyle) + this.bonusP;
  }

  bankPoints() {
    const n = this.unbankedP;
    progress.points = (progress.points || 0) + n;
    this.levelP = (this.levelP || 0) + n;
    this.bankedStyle = Math.floor(this.style.total);
    this.bonusP = 0;
    saveProgress();
    return n;
  }

  dropUnbanked() {
    this.bankedStyle = Math.floor(this.style.total);
    this.bonusP = 0;
  }

  // ---------------------------------------------------------------- dükkân
  openShop() {
    if (this.state !== 'playing') return;
    this.bankPoints();
    this.state = 'shop';
    this.pauseTime = performance.now();
    this.input.exitLock();
    this.audio.stopAllLoops();
    this.audio.muffle(0.5);
    this.audio.play('uiClick');
    this.touch.releaseAll();
    this.hud.stats(false);
    this.ui.showShop();
  }

  closeShop() {
    if (this.state !== 'shop') return;
    this.state = 'playing';
    this.ui.hideAll();
    this.input.requestLock();
    this.audio.muffle(0);
  }

  buy(id) {
    const it = SHOP_ITEMS.find((x) => x.id === id);
    if (!it || progress.shop[id] || settings.allWeapons) return false;
    if (it.needs && !progress.shop[it.needs]) return false;
    if ((progress.points || 0) < it.price) { this.audio.play('empty'); return false; }
    progress.points -= it.price;
    progress.shop[id] = true;
    saveProgress();
    this.applyLoadout();
    if (it.w !== undefined) {
      this.weapons.variant[it.w] = it.v;
      this.weapons.updateAccents();
      if (this.weapons.cur !== it.w) this.weapons.select(it.w);
      else this.hud.weaponChanged();
    } else if (id === 'arm.knuckle') {
      this.weapons.arm = 1;
      this.hud.weaponChanged();
    }
    this.audio.play('pickup');
    this.hud.flash('rgba(90,255,140,0.35)', 0.3);
    this.pendingHint = ITEM_HINTS[id] || null;
    return true;
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

  haptic(pattern) {
    if (!this.touch || !this.touch.active) return;
    try { if (navigator.vibrate) navigator.vibrate(pattern); } catch (e) { /* desteklenmiyor */ }
  }

  hitstop(t) {
    this.hitstopT = Math.max(this.hitstopT, t);
  }

  shake(amount) {
    this.trauma = Math.min(1, this.trauma + amount);
  }

  spawnEnemy(type, p, arena, opts = {}) {
    const Cls = ENEMY_TYPES[type];
    const pos = Array.isArray(p) ? new THREE.Vector3(...p) : p.clone();
    const pl = this.player.pos;
    const e = new Cls(this, pos, { yaw: yawTo(pl.x - pos.x, pl.z - pos.z), arena, ...opts });
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
    for (const [t, p, yaw, opts] of this.level.decor) {
      const e = new ENEMY_TYPES[t](this, new THREE.Vector3(...p), { ...(opts || {}), decor: true, yaw });
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
    this.haptic(Math.min(120, 30 + dmg * 2));
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

  // Feedbacker: mermi ve yakın saldırı savuşturma. buffered=true: yumruktan hemen sonraki
  // kısa pencerede (erken basılan yumruk) otomatik denemeler.
  tryParry(buffered = false) {
    const p = this.player;
    const w = this.weapons;
    const knuckle = w.armId === 'knuckle';
    const o = p.eyePos();
    const d = p.aimDir();
    // 1) Düşman mermileri (Knuckleblaster mermi savuşturamaz)
    const list = [];
    if (!knuckle) {
      for (const pr of this.projectiles) {
        if (pr.dead || pr.owner !== 'enemy' || !pr.parryable) continue;
        _v.subVectors(pr.pos, o);
        const dist = _v.length();
        if (dist > 7) continue;
        const dot = _v.dot(d) / (dist || 1);
        if (dot > 0.2 || dist < 2.4) list.push(pr);
      }
    }
    if (list.length) {
      // hedef: nişangâh; yakınında düşman varsa hafif güdüm ile ona
      const r = this.hitscan(o, d, 300, {});
      let target = r.hits[0] ? r.hits[0].point : r.end;
      const assist = w.assistDir(o, d, 0.26);
      if (assist) {
        const hit = this.hitscan(o, assist, 300, {});
        if (hit.hits[0]) target = hit.hits[0].point;
      }
      for (const pr of list) {
        const dir = target.clone().sub(pr.pos).normalize();
        pr.parry(dir, Math.max(pr.vel.length() * 1.8, 65));
      }
      this.onParry(list[0].pos.clone(), list.length);
      return true;
    }
    // 2) Parlayan yakın saldırı
    // en iyi aday: nişangâhın baktığı (yakın ve önde olan) parlayan düşman
    let best = null, bd = 1e9;
    for (const e of this.enemies) {
      if (e.dead || !e.parryable) continue;
      const c = e.center(_v);
      const dist = c.distanceTo(o);
      if (dist > 6.5 + e.r) continue;
      const to = c.clone().sub(o).normalize();
      const dot = to.dot(d);
      if (dot < 0.15 && dist > 2.6) continue;
      const score = dist * (1.6 - dot);
      if (score < bd) { bd = score; best = e; }
    }
    if (best) {
      const pos = best.center();
      best.parried(d.clone());
      this.onParry(pos, 1, true);
      return true;
    }
    if (buffered) return false;
    // 3) Oyuncunun kendi mermileri: çekirdek/roket/gülle → hızlandır (PROJECTILE BOOST)
    for (const pr of this.projectiles) {
      if (pr.dead || pr.owner !== 'player' || !['core', 'rocket', 'cannonball'].includes(pr.kind)) continue;
      _v.subVectors(pr.pos, o);
      const dist = _v.length();
      if (dist < 5.5 && _v.dot(d) / (dist || 1) > 0.2) {
        const assist = w.assistDir(o, d, 0.2);
        pr.vel.copy(assist || d).multiplyScalar(pr.kind === 'cannonball' ? 60 : 70);
        pr.boosted = true;
        pr.damage *= 1.5;
        if (pr.kind === 'core') pr.gravity = 4;
        this.style.add('PROJECTILE BOOST', 90, pr.kind === 'core' ? 'shotgun' : 'rocket');
        this.hitstop(0.06);
        this.audio.play('punchHit', pr.pos);
        this.fx.sprite(pr.pos.clone(), 0xffffff, 2, 0.2, 'star', 1.6);
        return true;
      }
    }
    // 4) Bozuk parayı yumrukla → anında sekme (zincir bonusu)
    for (const c of w.coins) {
      if (!c.alive) continue;
      _v.subVectors(c.pos, o);
      const dist = _v.length();
      if (dist < 4.5 && _v.dot(d) / (dist || 1) > 0.3) {
        this.style.add('COIN PUNCH', 60, 'revolver');
        w.ricochet(c, 1);
        return true;
      }
    }
    return false;
  }

  onParry(pos, n = 1, melee = false) {
    const p = this.player;
    this.stats.parries++;
    this.haptic([20, 30, 60]);
    p.hp = 100;
    p.hard = 0;
    this.audio.play('parry');
    this.hitstop(melee ? 0.22 : 0.15);
    this.hud.flash('rgba(255,255,255,0.85)', 0.22);
    this.hud.parryPulse();
    this.shake(0.35);
    this.fx.sprite(pos, 0xffffff, 4, 0.3, 'star', 2);
    this.fx.ring(pos.clone(), 0x9fd8ff, 3, 0.35, 0);
    this.fx.sparkBurst(pos, 24, 12, 0xbfe6ff, 0.5, 0.08);
    this.style.add('PARRY', 150, null, { count: n > 1 ? n : 0 });
    if (melee) this.style.add('INTERRUPTION', 60);
  }

  meleePunch(knuckle = false) {
    const p = this.player;
    const o = p.eyePos();
    const d = p.aimDir();
    let best = null, bd = 1e9;
    for (const e of this.enemies) {
      if (e.dead || e.state === 'spawn') continue;
      const c = e.center(_v);
      const dist = c.distanceTo(o) - e.r;
      if (dist > (knuckle ? 4.6 : 4.2)) continue;
      const to = c.clone().sub(o).normalize();
      if (to.dot(d) < 0.4) continue;
      if (dist < bd) { bd = dist; best = e; }
    }
    if (!best) return false;
    const c = best.center();
    const dir = d.clone();
    dir.y = Math.max(dir.y, 0.35);
    // SHOTGUN PARRY: yakından shotgun isabetinin hemen ardından yumruk
    const sp = this.weapons.lastShotgunHit;
    if (sp && sp.enemy === best && this.time - sp.time < 0.3 && !best.dead) {
      this.weapons.lastShotgunHit = null;
      best.hit({ dmg: 4, part: 'body', point: c, dir, knock: 24, weapon: 'shotgun' });
      this.style.add('SHOTGUN PARRY', 160, 'shotgun');
      this.onParry(c, 1, true);
      return true;
    }
    best.hit({ dmg: knuckle ? 3 : 1, part: 'body', point: c, dir, knock: knuckle ? 30 : 14, weapon: 'punch' });
    this.audio.play('punchHit', c, { rate: knuckle ? 0.7 : 1, exactRate: true });
    this.shake(knuckle ? 0.35 : 0.15);
    this.hitstop(knuckle ? 0.09 : 0.05);
    this.fx.sparkBurst(c, knuckle ? 20 : 10, 7, knuckle ? 0xff8a60 : 0xffffff, 0.25, 0.06);
    return true;
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
    if (e.type === 'trainer') {
      const door = this.level.doors[e.trainerDoor];
      if (door) this.schedule(0.8, () => door.open());
      this.hud.message('PARRY ÖĞRENİLDİ', 2.2, 'secret');
      this.hud.hint('Harika! Mermileri ve PARLAYAN saldırıları geri çevirmek canını tamamen doldurur. Kapı açıldı.', 7);
      return;
    }
    if (e.noCount) return;
    this.stats.kills++;
  }

  spawnTrainers() {
    for (const t of this.level.trainers) {
      const e = this.spawnEnemy('trainer', t.p, null);
      e.trainerDoor = t.door;
      e.yaw = Math.PI / 2;
    }
  }

  checkPickups() {
    const p = this.player;
    const c = _v.set(p.pos.x, p.pos.y + 0.9, p.pos.z);
    for (const pk of this.level.pickups) {
      if (pk.taken || pk.pos.distanceTo(c) > 2.0) continue;
      pk.taken = true;
      pk.holder.visible = false;
      pk.ring.visible = false;
      let first, name, sub;
      if (typeof pk.weapon === 'number') {
        first = this.weapons.give(pk.weapon);
        name = WEAPONS[pk.weapon].name;
        sub = `${pk.weapon + 1} · ${WEAPONS[pk.weapon].variants.map((v) => v.name).join(' / ')}`;
      } else {
        first = this.weapons.giveArm(pk.weapon);
        name = pk.weapon === 'hook' ? 'WHIPLASH' : 'KNUCKLEBLASTER';
        sub = pk.weapon === 'hook' ? 'E · KANCA' : 'G · KOL DEĞİŞTİR';
      }
      this.audio.play('pickup');
      this.hitstop(0.08);
      this.hud.flash('rgba(160,210,255,0.5)', 0.4);
      this.hud.titleCard(`<div class="tc-layer">YENİ ${typeof pk.weapon === 'number' ? 'SİLAH' : 'KOL'}</div><div class="tc-name tc-weapon">${name}</div><div class="tc-layer small">${sub}</div>`, 3);
      this.fx.sparkBurst(pk.pos.clone(), 30, 8, 0x9fd8ff, 0.7, 0.07, 0);
      this.fx.ring(pk.pos.clone().setY(pk.pos.y - 1.5), 0x9fd8ff, 3, 0.6, 0);
      if (pk.onGive) pk.onGive(this);
      if (first && pk.onTake) pk.onTake(this);
    }
  }

  onBossDefeated(msg, then) {
    this.hud.message(msg, 2.5, 'big');
    this.music.setMode('calm');
    if (then) this.schedule(2.0, then);
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
    for (const pk of this.level.pickups) { pk.taken = false; pk.holder.visible = true; pk.ring.visible = true; }
    for (const c of this.corpses) c.removeSilently();
    this.corpses = [];
    for (const sh of this.shocks) sh.remove();
    this.shocks = [];
    this.renderer.postMat.uniforms.uGray.value = 0;
    this.renderer.postMat.uniforms.uTintAmt.value = 0;
    this.events = [];
    this.hud.boss(null);
    this.levelDone = false;
    this.nearShop = null;
  }

  // idx verilmezse yüklü bölüm yeniden başlar
  startLevel(idx = this.levelIdx) {
    this.audio.init();
    this.ui.hideAll();
    progress.introSeen = true;
    saveProgress();
    this.clearDecor();
    if (!this.loadLevel(idx)) this.resetLevelState();
    this.hud.reset();
    this.hud.show(true);
    const L = this.level;
    const sp = L.spawn;
    this.player.reset(new THREE.Vector3(...sp.pos), sp.yaw);
    this.player.pitch = sp.pitch ?? -0.5;
    this.checkpoint = { pos: new THREE.Vector3(...sp.checkpoint), yaw: sp.yaw };
    this.weapons.reset();
    if (settings.allWeapons) this.weapons.giveAll();
    else if (L.startArmed) this.applyLoadout();
    this.spawnTrainers();
    this.arenas.prespawn();
    this.style.reset(true);
    this.bankedStyle = 0;
    this.bonusP = 0;
    this.levelP = 0;
    this.stats = { time: 0, kills: 0, restarts: 0, secrets: 0, parries: 0, damageTaken: 0 };
    this.time = 0;
    this.state = 'playing';
    this.input.gameActive = true;
    this.input.wantLock = true;
    this.input.requestLock();
    if (this.touch.active && !document.fullscreenElement && !document.webkitFullscreenElement) this.touch.toggleFullscreen();
    this.audio.muffle(0);
    this.music.setMode('calm');
    const def = this.levelDef;
    this.hud.titleCard(`<div class="tc-layer">${def.layer} /// ${def.id}</div><div class="tc-name">${def.name}</div>`, 4.5);
    if (L.onStart) L.onStart(this);
  }

  setCheckpoint(pos, yaw) {
    if (this.checkpoint.pos.distanceTo(pos) < 0.5) return;
    this.checkpoint = { pos: pos.clone(), yaw };
    const n = this.bankPoints();
    this.hud.message(n > 0 ? `CHECKPOINT  +${n} P` : 'CHECKPOINT', 1.5, 'cp');
    this.audio.play('checkpoint');
  }

  playerDie() {
    const p = this.player;
    p.dead = true;
    p.hp = 0;
    this.state = 'dead';
    this.deathT = 0;
    this.deaths = (this.deaths || 0) + 1;
    this.hud.death(true, this.stats.restarts + 1);
    this.hud.flash('rgba(255,0,0,0.8)', 0.5);
    this.shake(0.8);
    this.audio.play('death');
    this.audio.play('glitch');
    this.audio.loop('pierce', false);
    this.audio.muffle(0.85);
    this.audio.stopAllLoops();
    this.fx.bloodBurst(p.eyePos(), 50, 8, null, true);
    this.lostP = this.unbankedP;
    this.dropUnbanked();
    this.style.reset(false);
  }

  respawn(fromPause = false) {
    if (this.state !== 'dead' && !(fromPause && this.state === 'paused')) return;
    this.arenas.resetActive();
    this.arenas.prespawn();
    for (const pr of this.projectiles) pr.remove();
    this.projectiles = [];
    for (const c of this.weapons.coins) c.kill();
    this.weapons.coins = [];
    const cur = this.weapons.cur;
    this.weapons.reset(true);
    if (cur >= 0) this.weapons.cur = cur;
    this.renderer.postMat.uniforms.uGray.value = 0;
    this.renderer.postMat.uniforms.uTintAmt.value = 0;
    for (const sh of this.shocks) sh.remove();
    this.shocks = [];
    this.player.reset(this.checkpoint.pos.clone(), this.checkpoint.yaw);
    if (fromPause) this.dropUnbanked();
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
    if (this.state === 'shop' && (e.code === 'Escape' || e.code === 'KeyB') && performance.now() - (this.pauseTime || 0) > 250) { this.closeShop(); return; }
    if (e.code === 'Escape') {
      if (this.state === 'playing' && (!this.input.locked || this.input.lockFailed)) this.pause();
      else if (this.state === 'paused' && performance.now() - (this.pauseTime || 0) > 400) this.resume();
    }
    if (this.state === 'dead' && e.code === 'KeyR' && this.deathT > 1.0) this.respawn();
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
    const def = this.levelDef;
    r.levelId = def.id;
    r.levelTitle = `${def.id}: ${def.name}`;
    r.timeRank = rankTime(r.time, def.thresh.time);
    r.killRank = rankKills(r.kills / Math.max(1, r.killsTotal));
    r.styleRank = rankStyle(r.style, def.thresh.style);
    r.final = finalRank([r.timeRank, r.killRank, r.styleRank], r.restarts);
    r.challenge = def.challenge.check(r);
    r.challengeText = def.challenge.text(r);
    // P: kasaya kalanı yatır + sıra ve meydan okuma ödülü
    r.rankBonus = { P: 5000, S: 3000, A: 2000, B: 1200, C: 600, D: 300 }[r.final] + (r.challenge ? 1000 : 0);
    this.bonusP += r.rankBonus;
    this.bankPoints();
    r.pointsEarned = this.levelP;
    r.pointsTotal = progress.points;
    const rec = progress.levels[def.id];
    r.newBest = !rec || betterRank(rec.rank, r.final) || (rec.rank === r.final && (!rec.time || r.time < rec.time));
    progress.levels[def.id] = r.newBest ? { rank: r.final, time: r.time, style: Math.max(r.style, rec ? rec.style || 0 : 0) } : { ...rec, style: Math.max(rec.style || 0, r.style) };
    progress.unlocked = Math.max(progress.unlocked || 1, Math.min(LEVELS.length, this.levelIdx + 2));
    r.hasNext = this.levelIdx + 1 < LEVELS.length;
    r.last = !r.hasNext;
    saveProgress();
    this.lastResults = r;
    this.ui.showResults(r);
  }

  nextLevel() {
    if (this.levelIdx + 1 < LEVELS.length) this.startLevel(this.levelIdx + 1);
    else this.toMenu();
  }

  // ---------------------------------------------------------------- döngü
  loop(now) {
    requestAnimationFrame(this.loop);
    const realDt = Math.min(0.1, Math.max(0, (now - this.lastT) / 1000));
    this.lastT = now;
    // Telefonda oyun dışı ekranlar daha seyrek çizilir (menü 30, duraklatma/dükkân 12 kare/sn)
    const st = this.state;
    const cap = !this.mobile ? 0 : st === 'paused' || st === 'shop' || st === 'results' ? 1 / 12 : st === 'menu' || st === 'splash' ? 1 / 30 : 0;
    this.frameAcc += realDt;
    if (cap && this.frameAcc < cap) return;
    const dt = Math.min(0.05, this.frameAcc);
    this.frameAcc = 0;
    this.step(dt);
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
    const showVM = st === 'playing' || st === 'paused' || st === 'shop';
    this.touch.update();
    if (render) this.renderer.render(this.scene, this.camera, showVM && !this.player.dead ? this.weapons.scene : null, this.weapons.cam);
    this.input.endFrame();
  }

  updateMenu(dt) {
    this.time += dt;
    const t = this.realTime * 0.06;
    const cam = this.camera;
    const mc = this.level.menuCam;
    const [tx, ty, tz] = mc.target;
    cam.position.set(tx + Math.sin(t) * mc.radius, mc.height + Math.sin(t * 2.3) * 0.8, tz + Math.cos(t) * mc.radius);
    cam.lookAt(tx, ty, tz);
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
      p.look(input, realDt, this.aimFriction);
      this.aimMagnet(realDt);
      p.update(dt, input);
      this.weapons.update(dt, input);
      this.hud.stats(input.is('stats'));
    } else {
      // ölüm: dünya ağır çekimde akar, görüntü kırmızıya/griye döner
      this.deathT += realDt;
      dt *= this.deathT < 1.5 ? 0.22 : 0.5;
      this.time += dt;
      const u = this.renderer.postMat.uniforms;
      const k = Math.min(1, this.deathT / 0.9);
      u.uGray.value = 0.8 * k;
      u.uTint.value.setRGB(0.55, 0, 0.02);
      u.uTintAmt.value = 0.3 * k;
      if (this.deathT > 1.0 && (input.pressed('restart') || input.pressed('fire') || input.pressed('jump'))) {
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
    if (this.corpses.length) this.corpses = this.corpses.filter((c) => c.updateCorpse(dt));
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
    if (this.shocks.length) this.shocks = this.shocks.filter((sh) => sh.update(dt));

    if (this.state === 'playing') {
      this.arenas.update(dt);
      this.checkTriggers();
      this.checkSecrets();
      this.checkPickups();
      this.checkShops();
      if (this.pendingHint) { this.hud.hint(this.pendingHint, 9); this.pendingHint = null; }
    }
    this.updateBossBar();
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

  checkShops() {
    const p = this.player;
    let near = null;
    for (const sh of this.level.shops) {
      const dx = sh.pos.x - p.pos.x, dz = sh.pos.z - p.pos.z;
      if (dx * dx + dz * dz < 2.8 * 2.8 && Math.abs(sh.pos.y - p.pos.y) < 2) { near = sh; break; }
    }
    if (near !== this.nearShop) { this.nearShop = near; this.hud.shopPrompt(!!near); }
    if (near && this.input.pressed('shop')) this.openShop();
  }

  // Boss çubuğu: etkin arenadaki boss'ların toplam canı
  updateBossBar() {
    let name = null, hp = 0, max = 0, enraged = false;
    for (const a of this.arenas.list) {
      if (a.state !== 'active' || !a.bossList || !a.bossList.length) continue;
      name = a.boss ? a.name : a.bossList[0].name;
      for (const e of a.bossList) { hp += Math.max(0, e.dead ? 0 : e.hp); max += e.maxHp; enraged = enraged || (!e.dead && !!e.enraged); }
      break;
    }
    if (name && max > 0) this.hud.boss(name, hp / max, enraged);
    else if (this.hud.bossActive) this.hud.boss(null);
  }

  // Nişan yardımı (dokunmatik, güçlü): ateş basılıyken bakış yakındaki düşmana doğru kayar;
  // nişangâh düşmanın üstündeyken bakış yavaşlar (yapışkan nişan).
  aimMagnet(dt) {
    this.aimFriction = 1;
    if (!this.touch.active || (settings.aimAssist | 0) < 2) return;
    const p = this.player;
    if (p.dead) return;
    const input = this.input;
    const firing = input.is('fire') || input.is('alt');
    const o = p.eyePos(_v2);
    const d = p.aimDir();
    let best = null, bestScore = 1e9, bestA = 0;
    const maxA = firing ? 0.32 : 0.14;
    for (const e of this.enemies) {
      if (e.dead || e.decor || e.state === 'spawn' || e.dormant) continue;
      const c = e.center(_v);
      const tx = c.x - o.x, ty = c.y - o.y, tz = c.z - o.z;
      const dist = Math.hypot(tx, ty, tz);
      if (dist > 70 || dist < 0.5) continue;
      const a = Math.acos(clamp((tx * d.x + ty * d.y + tz * d.z) / dist, -1, 1));
      if (a > maxA + (e.r || 0.5) / dist) continue;
      const score = a + dist * 0.003;
      if (score < bestScore && this.world.lineOfSight(o, c)) { bestScore = score; best = e; bestA = a; }
    }
    if (!best) return;
    if (bestA < 0.09) this.aimFriction = 0.55;
    if (!firing) return;
    const c = best.center(_v);
    const tx = c.x - o.x, ty = c.y - o.y, tz = c.z - o.z;
    const tYaw = Math.atan2(-tx, -tz);
    const tPitch = Math.atan2(ty, Math.hypot(tx, tz));
    const k = 1 - Math.exp(-dt * 6);
    p.yaw += wrapAngle(tYaw - p.yaw) * k;
    p.pitch += (tPitch - p.pitch) * k;
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
        this.bonusP += 1000;
        this.audio.play('secret');
        this.hud.message(`GİZLİ KÜRE  ${this.stats.secrets} / ${this.level.secrets.length}  +1000 P`, 2.5, 'secret');
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
    // test/hata ayıklama kancaları
    window.__ukSettings = settings;
    window.__ukProgress = progress;
    window.__ukPoints = () => progress.points;
    window.__ukSetPoints = (n) => { progress.points = n; };
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
