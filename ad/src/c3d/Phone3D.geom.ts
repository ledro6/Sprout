// Геометрия корпуса: скруглённые пластины с фаской и ленты браслета.
import * as THREE from 'three';

// Контур скруглённого прямоугольника с центром в нуле.
export const roundedRectShape = (hw: number, hh: number, r: number) => {
  const s = new THREE.Shape();
  s.moveTo(-hw + r, -hh);
  s.lineTo(hw - r, -hh);
  s.absarc(hw - r, -hh + r, r, -Math.PI / 2, 0, false);
  s.lineTo(hw, hh - r);
  s.absarc(hw - r, hh - r, r, 0, Math.PI / 2, false);
  s.lineTo(-hw + r, hh);
  s.absarc(-hw + r, hh - r, r, Math.PI / 2, Math.PI, false);
  s.lineTo(-hw, -hh + r);
  s.absarc(-hw + r, -hh + r, r, Math.PI, Math.PI * 1.5, false);
  return s;
};

// Пластина w×h (контур в XY) толщиной d по Z, центр в нуле.
// Фаска bevel «округляет» кромку, как у титанового корпуса.
export const roundedSlab = (w: number, h: number, r: number, d: number, bevel: number) => {
  const b = Math.min(bevel, d / 2 - 1e-4, r - 1e-4);
  const shape = roundedRectShape(w / 2 - b, h / 2 - b, Math.max(r - b, 1e-4));
  const dE = d - 2 * b;
  const g = new THREE.ExtrudeGeometry(shape, {
    depth: dE,
    bevelEnabled: true,
    bevelThickness: b,
    bevelSize: b,
    bevelSegments: 8,
    curveSegments: 24,
    steps: 1,
  });
  g.translate(0, 0, -dE / 2);
  return g;
};

// Плоская «лицевая» форма для стекла/чёрной подложки (совпадает с плоской частью слэба).
export const faceShape = (w: number, h: number, r: number, bevel: number) => {
  const b = Math.min(bevel, r - 1e-4);
  return roundedRectShape(w / 2 - b, h / 2 - b, Math.max(r - b, 1e-4));
};

// Лента прямоугольного сечения (ширина по X, толщина по нормали к кривой).
// Каждая грань — отдельные вершины, поэтому рёбра остаются резкими.
export const ribbonGeometry = (curve: THREE.Curve<THREE.Vector3>, width: number, thick: number, segs: number) => {
  const pts = curve.getSpacedPoints(segs);
  const X = new THREE.Vector3(1, 0, 0);
  const hw = width / 2;
  const ht = thick / 2;
  const pos: number[] = [];
  const idx: number[] = [];
  // На каждой точке: 4 стороны × 2 угла = 8 вершин.
  const vi = (i: number, side: number, corner: number) => i * 8 + side * 2 + corner;
  pts.forEach((p, i) => {
    const t = curve.getTangentAt(i / segs).normalize();
    const N = new THREE.Vector3().crossVectors(t, X).normalize();
    const corners = [
      p.clone().addScaledVector(X, hw).addScaledVector(N, ht),
      p.clone().addScaledVector(X, -hw).addScaledVector(N, ht),
      p.clone().addScaledVector(X, -hw).addScaledVector(N, -ht),
      p.clone().addScaledVector(X, hw).addScaledVector(N, -ht),
    ];
    for (let s = 0; s < 4; s++) {
      for (const c of [corners[s], corners[(s + 1) % 4]]) pos.push(c.x, c.y, c.z);
    }
  });
  for (let i = 0; i < pts.length - 1; i++) {
    for (let s = 0; s < 4; s++) {
      const a = vi(i, s, 0);
      const b = vi(i, s, 1);
      const c = vi(i + 1, s, 1);
      const d = vi(i + 1, s, 0);
      idx.push(a, b, c, a, c, d);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setIndex(idx);
  g.computeVertexNormals();
  return g;
};
