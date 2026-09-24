// Eksen hizalı kutu (AABB) dünyası: çarpışma, basamak çıkma, ışın atma.
const EPS = 0.002;

export class Solid {
  constructor(minX, minY, minZ, maxX, maxY, maxZ, tag = 'static') {
    this.minX = minX; this.minY = minY; this.minZ = minZ;
    this.maxX = maxX; this.maxY = maxY; this.maxZ = maxZ;
    this.enabled = true;
    this.tag = tag;
    this.playerOnly = false;
  }
}

export class World {
  constructor() {
    this.solids = [];
  }

  add(minX, minY, minZ, maxX, maxY, maxZ, tag) {
    const s = new Solid(Math.min(minX, maxX), Math.min(minY, maxY), Math.min(minZ, maxZ), Math.max(minX, maxX), Math.max(minY, maxY), Math.max(minZ, maxZ), tag);
    this.solids.push(s);
    return s;
  }

  // Gövde: {pos (ayak merkezi), r (yarı genişlik), h (yükseklik)}
  overlapBox(x0, y0, z0, x1, y1, z1, isEnemy = false) {
    const arr = this.solids;
    for (let i = 0; i < arr.length; i++) {
      const s = arr[i];
      if (!s.enabled || (isEnemy && s.playerOnly)) continue;
      if (x1 > s.minX && x0 < s.maxX && y1 > s.minY && y0 < s.maxY && z1 > s.minZ && z0 < s.maxZ) return s;
    }
    return null;
  }

  overlapBody(b, px = b.pos.x, py = b.pos.y, pz = b.pos.z) {
    return this.overlapBox(px - b.r, py, pz - b.r, px + b.r, py + b.h, pz + b.r, b.isEnemy);
  }

  // Gövdeyi hareket ettirir, çarpışmaları çözer. stepUp > 0 ise basamak çıkar.
  moveBody(b, dx, dy, dz, stepUp = 0) {
    const res = { ground: false, ceil: false, hitX: false, hitZ: false, groundSolid: null, stepped: 0 };
    const len = Math.max(Math.abs(dx), Math.abs(dy), Math.abs(dz));
    const steps = Math.max(1, Math.ceil(len / 0.25));
    const sx = dx / steps, sy = dy / steps, sz = dz / steps;
    const p = b.pos;
    for (let i = 0; i < steps; i++) {
      if (sx !== 0) {
        p.x += sx;
        let s = this.overlapBody(b);
        if (s) {
          if (stepUp > 0 && this.tryStep(b, s, stepUp, res)) { /* basamak */ } else {
            for (let k = 0; k < 4 && s; k++) {
              p.x = sx > 0 ? s.minX - b.r - EPS : s.maxX + b.r + EPS;
              s = this.overlapBody(b);
            }
            res.hitX = true;
          }
        }
      }
      if (sz !== 0) {
        p.z += sz;
        let s = this.overlapBody(b);
        if (s) {
          if (stepUp > 0 && this.tryStep(b, s, stepUp, res)) { /* basamak */ } else {
            for (let k = 0; k < 4 && s; k++) {
              p.z = sz > 0 ? s.minZ - b.r - EPS : s.maxZ + b.r + EPS;
              s = this.overlapBody(b);
            }
            res.hitZ = true;
          }
        }
      }
      if (sy !== 0) {
        p.y += sy;
        let s = this.overlapBody(b);
        for (let k = 0; k < 4 && s; k++) {
          if (sy < 0) {
            p.y = s.maxY + EPS;
            res.ground = true;
            res.groundSolid = s;
          } else {
            p.y = s.minY - b.h - EPS;
            res.ceil = true;
          }
          s = this.overlapBody(b);
        }
      }
    }
    return res;
  }

  tryStep(b, s, stepUp, res) {
    const p = b.pos;
    const rise = s.maxY - p.y;
    if (rise <= 0 || rise > stepUp) return false;
    const oldY = p.y;
    p.y = s.maxY + EPS;
    if (this.overlapBody(b)) {
      p.y = oldY;
      return false;
    }
    res.stepped += p.y - oldY;
    return true;
  }

  // Ayak altında zemin var mı (küçük aralıkla)
  groundCheck(b, dist = 0.08) {
    return this.overlapBox(b.pos.x - b.r * 0.95, b.pos.y - dist, b.pos.z - b.r * 0.95, b.pos.x + b.r * 0.95, b.pos.y + 0.01, b.pos.z + b.r * 0.95, b.isEnemy);
  }

  // Gövdenin yanında duvar var mı → duvar normali {x,z}
  wallCheck(b, margin = 0.35) {
    const p = b.pos;
    const y0 = p.y + 0.2, y1 = p.y + b.h - 0.2;
    let best = null;
    const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
    for (const [dx, dz] of dirs) {
      const cx = p.x + dx * margin, cz = p.z + dz * margin;
      const s = this.overlapBox(cx - b.r, y0, cz - b.r, cx + b.r, y1, cz + b.r, b.isEnemy);
      if (s) {
        best = best || { x: 0, z: 0 };
        best.x -= dx;
        best.z -= dz;
      }
    }
    if (best) {
      const l = Math.hypot(best.x, best.z);
      if (l < 0.01) return null;
      best.x /= l;
      best.z /= l;
    }
    return best;
  }

  pointInSolid(x, y, z) {
    const arr = this.solids;
    for (let i = 0; i < arr.length; i++) {
      const s = arr[i];
      if (!s.enabled) continue;
      if (x > s.minX && x < s.maxX && y > s.minY && y < s.maxY && z > s.minZ && z < s.maxZ) return s;
    }
    return null;
  }

  // Slab yöntemiyle ışın. dir birim vektör olmalı.
  raycast(ox, oy, oz, dx, dy, dz, maxT = 1000, ignorePlayerOnly = true) {
    let bestT = maxT;
    let best = null;
    let bnx = 0, bny = 0, bnz = 0;
    const ix = dx !== 0 ? 1 / dx : Infinity;
    const iy = dy !== 0 ? 1 / dy : Infinity;
    const iz = dz !== 0 ? 1 / dz : Infinity;
    const arr = this.solids;
    for (let i = 0; i < arr.length; i++) {
      const s = arr[i];
      if (!s.enabled || (ignorePlayerOnly && s.playerOnly)) continue;
      let t1 = (s.minX - ox) * ix, t2 = (s.maxX - ox) * ix;
      let tminX = Math.min(t1, t2), tmaxX = Math.max(t1, t2);
      if (dx === 0) { if (ox <= s.minX || ox >= s.maxX) continue; tminX = -Infinity; tmaxX = Infinity; }
      t1 = (s.minY - oy) * iy; t2 = (s.maxY - oy) * iy;
      let tminY = Math.min(t1, t2), tmaxY = Math.max(t1, t2);
      if (dy === 0) { if (oy <= s.minY || oy >= s.maxY) continue; tminY = -Infinity; tmaxY = Infinity; }
      t1 = (s.minZ - oz) * iz; t2 = (s.maxZ - oz) * iz;
      let tminZ = Math.min(t1, t2), tmaxZ = Math.max(t1, t2);
      if (dz === 0) { if (oz <= s.minZ || oz >= s.maxZ) continue; tminZ = -Infinity; tmaxZ = Infinity; }
      const tmin = Math.max(tminX, tminY, tminZ);
      const tmax = Math.min(tmaxX, tmaxY, tmaxZ);
      if (tmax < 0 || tmin > tmax) continue;
      const t = tmin < 0 ? 0 : tmin;
      if (t < bestT) {
        bestT = t;
        best = s;
        if (tmin === tminX) { bnx = dx > 0 ? -1 : 1; bny = 0; bnz = 0; }
        else if (tmin === tminY) { bnx = 0; bny = dy > 0 ? -1 : 1; bnz = 0; }
        else { bnx = 0; bny = 0; bnz = dz > 0 ? -1 : 1; }
      }
    }
    if (!best) return null;
    return { t: bestT, solid: best, nx: bnx, ny: bny, nz: bnz, x: ox + dx * bestT, y: oy + dy * bestT, z: oz + dz * bestT };
  }

  lineOfSight(a, b) {
    const dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z;
    const d = Math.sqrt(dx * dx + dy * dy + dz * dz);
    if (d < 0.001) return true;
    const hit = this.raycast(a.x, a.y, a.z, dx / d, dy / d, dz / d, d);
    return !hit;
  }
}
