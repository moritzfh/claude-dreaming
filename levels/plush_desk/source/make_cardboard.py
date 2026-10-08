"""Blender (bpy) generator for cardboard Claude.

    python make_cardboard.py
Writes ../models/cardboard.glb: one object CB_<Part> for every part of the
robot (assets/models/robot.glb) that gets a cardboard version. Each mesh is in
the local space of that part, so the level can swap the meshes into the normal
robot rig and every animation still works. Plus CB_USB (the USB stick in the
head, hinge at its origin, pointing up).

Surfaces (materials, mapped to shaders in the level):
  kraft   flat corrugated board   UV in metres, flutes run along V
  flute   cut edge of the board   U along the edge (m), V across 0..1
  tape    brown packing tape      U along the strip (m), V across 0..1
  tube    paper tube (outside)    U around 0..1, V along (m)
  tubein  inside of a tube
  paper   white paper sticker     UV 0..1
  straw   striped paper straw     U around, V along
  brass   paper fastener
  steel   USB connector
  yellow  star coloured in with marker
"""
import os, math, random
import bpy, bmesh
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "..", "models", "cardboard.glb")
MATS = ["kraft", "flute", "tape", "tube", "tubein", "paper", "straw", "brass", "steel", "yellow"]
rnd = random.Random(5)
T = 0.016     # board thickness


class Builder:
    """Collects geometry for one part in world space."""
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def face(self, verts, uvs, mat):
        vs = [self.bm.verts.new(v) for v in verts]
        f = self.bm.faces.new(vs)
        f.material_index = MATS.index(mat)
        for l, uv in zip(f.loops, uvs):
            l[self.uv].uv = uv
        return f

    def poly_slab(self, poly, thick, xf, face_mat="kraft", rim_mat="flute", back_mat=None):
        """Extrude a 2D polygon (counter-clockwise, metres) along local +Z by thick.
        xf maps local -> world. Front (+Z) and back faces use face_mat."""
        back_mat = back_mat or face_mat
        n = len(poly)
        top = [xf @ Vector((x, y, thick)) for x, y in poly]
        bot = [xf @ Vector((x, y, 0.0)) for x, y in poly]
        self.face(top, [(x, y) for x, y in poly], face_mat)
        self.face(bot[::-1], [(x, y) for x, y in poly[::-1]], back_mat)
        acc = 0.0
        for i in range(n):
            j = (i + 1) % n
            seg = (Vector(poly[j]) - Vector(poly[i])).length
            self.face([bot[i], bot[j], top[j], top[i]],
                      [(acc, 0.0), (acc + seg, 0.0), (acc + seg, 1.0), (acc, 1.0)], rim_mat)
            acc += seg

    def board(self, center, size_u, size_v, normal, up, thick=T, hole=None, wobble=1.0,
              face_mat="kraft", rim_mat="flute"):
        """A flat rectangular piece of board. normal = outward, up = v direction."""
        n = Vector(normal).normalized()
        v = Vector(up).normalized()
        u = v.cross(n)
        rot = Matrix.Rotation(math.radians(rnd.uniform(-1, 1) * wobble), 4, n) @ \
            Matrix.Rotation(math.radians(rnd.uniform(-0.8, 0.8) * wobble), 4, u)
        m = Matrix((u, v, n)).transposed().to_4x4()
        xf = Matrix.Translation(Vector(center) - n * thick) @ rot @ m
        hu, hv = size_u / 2, size_v / 2
        if hole is None:
            self.poly_slab([(-hu, -hv), (hu, -hv), (hu, hv), (-hu, hv)], thick, xf, face_mat, rim_mat)
        else:
            # a frame around a rectangular window: four strips
            x0, y0, x1, y1 = hole
            self.poly_slab([(-hu, -hv), (hu, -hv), (hu, y0), (-hu, y0)], thick, xf, face_mat, rim_mat)
            self.poly_slab([(-hu, y1), (hu, y1), (hu, hv), (-hu, hv)], thick, xf, face_mat, rim_mat)
            self.poly_slab([(-hu, y0), (x0, y0), (x0, y1), (-hu, y1)], thick, xf, face_mat, rim_mat)
            self.poly_slab([(x1, y0), (hu, y0), (hu, y1), (x1, y1)], thick, xf, face_mat, rim_mat)

    def tape(self, a, b, normal, width=0.05, thick=0.0018):
        """A strip of packing tape from a to b lying on a surface with this normal.
        The ends are torn in a zig-zag like from a tape dispenser."""
        a, b = Vector(a), Vector(b)
        n = Vector(normal).normalized()
        d = (b - a)
        L = d.length
        u = d.normalized()
        w = n.cross(u)
        poly = [(0.0, -width / 2)]
        steps = 6
        for i in range(steps + 1):        # far end, zig-zag
            poly.append((L + (0.006 if i % 2 else -0.004), -width / 2 + width * i / steps))
        poly.append((0.0, width / 2))
        for i in range(steps, -1, -1):    # near end
            poly.append(((0.006 if i % 2 else -0.004), -width / 2 + width * i / steps))
        poly = poly[:1] + poly[1:steps + 2] + poly[steps + 2:]
        # simplify: use a clean outline (start corner, far zigzag, end corner, near zigzag)
        far = [(L + (0.006 if i % 2 else -0.004), -width / 2 + width * i / steps) for i in range(steps + 1)]
        near = [((0.006 if i % 2 else -0.004), width / 2 - width * i / steps) for i in range(steps + 1)]
        poly = far + near
        m = Matrix((u, w, n)).transposed().to_4x4()
        xf = Matrix.Translation(a + n * 0.0012) @ m
        # tape: top/bottom faces get UV (along, across 0..1)
        k = len(poly)
        top = [xf @ Vector((x, y, thick)) for x, y in poly]
        bot = [xf @ Vector((x, y, 0.0)) for x, y in poly]
        uvs = [(x, y / width + 0.5) for x, y in poly]
        self.face(top, uvs, "tape")
        self.face(bot[::-1], uvs[::-1], "tape")
        for i in range(k):
            j = (i + 1) % k
            self.face([bot[i], bot[j], top[j], top[i]], [uvs[i], uvs[j], uvs[j], uvs[i]], "tape")

    def tape_corner(self, a, b, n1, n2, width=0.05):
        """Tape folded over an edge from a to b between faces with normals n1, n2."""
        n1, n2 = Vector(n1).normalized(), Vector(n2).normalized()
        self.tape(Vector(a) + n2 * 0.0, Vector(b), n1, width)
        self.tape(Vector(a), Vector(b), n2, width)

    def tube(self, a, b, r, wall=0.006, segs=20, outer="tube", inner="tubein", rim="kraft"):
        a, b = Vector(a), Vector(b)
        ax = (b - a)
        L = ax.length
        z = ax.normalized()
        x = z.orthogonal().normalized()
        y = z.cross(x)
        ring = lambda rr, t: [a + z * (L * t) + (x * math.cos(i * math.tau / segs) + y * math.sin(i * math.tau / segs)) * rr
                              for i in range(segs)]
        o0, o1 = ring(r, 0), ring(r, 1)
        i0, i1 = ring(r - wall, 0), ring(r - wall, 1)
        for i in range(segs):
            j = (i + 1) % segs
            u0, u1 = i / segs, (i + 1) / segs
            self.face([o0[i], o0[j], o1[j], o1[i]], [(u0, 0), (u1, 0), (u1, L), (u0, L)], outer)
            self.face([i0[j], i0[i], i1[i], i1[j]], [(u1, 0), (u0, 0), (u0, L), (u1, L)], inner)
            self.face([o1[i], o1[j], i1[j], i1[i]], [(u0, 0), (u1, 0), (u1, 1), (u0, 1)], rim)
            self.face([o0[j], o0[i], i0[i], i0[j]], [(u1, 0), (u0, 0), (u0, 1), (u1, 1)], rim)

    def solid_cyl(self, a, b, r, segs=16, mat="brass", cap=True):
        a, b = Vector(a), Vector(b)
        z = (b - a).normalized()
        x = z.orthogonal().normalized()
        y = z.cross(x)
        r0 = [a + (x * math.cos(i * math.tau / segs) + y * math.sin(i * math.tau / segs)) * r for i in range(segs)]
        r1 = [p + (b - a) for p in r0]
        for i in range(segs):
            j = (i + 1) % segs
            self.face([r0[i], r0[j], r1[j], r1[i]], [(i / segs, 0), ((i + 1) / segs, 0), ((i + 1) / segs, 1), (i / segs, 1)], mat)
        if cap:
            self.face(r1, [(0.5 + 0.5 * math.cos(i * math.tau / segs), 0.5 + 0.5 * math.sin(i * math.tau / segs)) for i in range(segs)], mat)
            self.face(r0[::-1], [(0.5, 0.5)] * segs, mat)

    def dome(self, c, normal, r, h, segs=12, mat="brass"):
        c = Vector(c); n = Vector(normal).normalized()
        x = n.orthogonal().normalized(); y = n.cross(x)
        rings = 4
        pts = []
        for k in range(rings + 1):
            a = (k / rings) * math.pi / 2
            rr, hh = r * math.cos(a), h * math.sin(a)
            pts.append([c + n * hh + (x * math.cos(i * math.tau / segs) + y * math.sin(i * math.tau / segs)) * rr for i in range(segs)])
        for k in range(rings):
            for i in range(segs):
                j = (i + 1) % segs
                self.face([pts[k][i], pts[k][j], pts[k + 1][j], pts[k + 1][i]], [(0, 0)] * 4, mat)

    def to_object(self, name, ref_obj):
        """Bake into an object whose mesh is in ref_obj's local space."""
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts[:], dist=1e-6)
        inv = ref_obj.matrix_world.inverted() if ref_obj else Matrix.Identity(4)
        bmesh.ops.transform(self.bm, matrix=inv, verts=self.bm.verts[:])
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for mname in MATS:
            me.materials.append(bpy.data.materials.get(mname) or bpy.data.materials.new(mname))
        # flat shading for board, smooth for round things
        for p in me.polygons:
            p.use_smooth = MATS[p.material_index] in ("tube", "tubein", "straw", "brass")
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def circle(r, n=24, cx=0.0, cy=0.0):
    return [(cx + r * math.cos(i * math.tau / n), cy + r * math.sin(i * math.tau / n)) for i in range(n)]


def sparkle(r, inner=0.32, n=4, rot=math.pi / 2):
    pts = []
    for k in range(n * 2):
        rr = r if k % 2 == 0 else r * inner
        a = rot + k * math.pi / n
        pts.append((rr * math.cos(a), rr * math.sin(a)))
    # round off: add midpoints pulled in for a softer cut
    return pts


def mitten(s=1.0):
    pts = [(-0.035, -0.03), (0.035, -0.03), (0.04, 0.02), (0.033, 0.05), (0.012, 0.062), (-0.012, 0.062),
           (-0.03, 0.05), (-0.036, 0.03), (-0.06, 0.035), (-0.068, 0.02), (-0.05, 0.0)]
    return [(x * s, y * s) for x, y in pts]


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "robot.glb"))
    ref = {o.name: o for o in bpy.data.objects}
    for o in list(bpy.data.objects):
        o.hide_set(True)
    out = []
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

    # ------------------------------------------------------------ head: a taped box
    b = Builder()
    x0, x1, y0, y1, z0, z1 = -0.29, 0.29, -0.23, 0.25, 0.5, 0.945
    cx, cy, cz = 0.0, (y0 + y1) / 2, (z0 + z1) / 2
    W, D, H = x1 - x0, y1 - y0, z1 - z0
    # front with the screen window (window in local u,v of the board)
    b.board((cx, y1, cz), W, H, Y, Z, hole=(-0.212, 0.575 - cz, 0.212, 0.872 - cz), wobble=0.4)
    b.board((cx, y0 + T, cz), W - 2 * T, H, -Y, Z)
    b.board((x0 + T, cy, cz), D - 2 * T, H, -X, Z)
    b.board((x1 - T, cy, cz), D - 2 * T, H, X, Z)
    b.board((cx, cy, z0 + T), W - 2 * T, D - 2 * T, -Z, Y)
    # two top flaps, the right one a little proud
    b.board((cx - W / 4, cy, z1), W / 2 - 0.004, D, Z, Y, wobble=1.5)
    b.board((cx + W / 4, cy, z1 + 0.004), W / 2 - 0.004, D, Z, Y, wobble=2.0)
    # tape: along the flap seam and down the front and back
    b.tape((0.0, y0 - 0.002, z1 + 0.006), (0.0, y1 + 0.002, z1 + 0.006), Z, 0.07)
    b.tape((0.0, y1 + 0.001, z1 + 0.004), (0.0, y1 + 0.001, z1 - 0.055), Y, 0.07)
    b.tape((0.0, y0 - 0.001, z1 + 0.004), (0.0, y0 - 0.001, z1 - 0.07), -Y, 0.07)
    # vertical corner tapes
    for sx in (-1, 1):
        xe = x1 if sx > 0 else x0
        b.tape((xe + sx * 0.001, y1 - 0.025, z0 + 0.03), (xe + sx * 0.001, y1 - 0.025, z1 - 0.04), X * sx, 0.045)
        b.tape((xe - sx * 0.025, y1 + 0.001, z0 + 0.06), (xe - sx * 0.025, y1 + 0.001, z0 + 0.2), Y, 0.045)
    # a slot in the top for the USB stick: two dark-ish flute strips
    out.append(b.to_object("CB_Head", ref["Head"]))

    # screen: the drawn-on face sheet sits just behind the window
    b = Builder()
    sw, sh = 0.44, 0.31
    y = y1 - T - 0.004
    c = (0.0, y, (0.575 + 0.872) / 2)
    pts = [Vector((-sw / 2, y, c[2] - sh / 2)), Vector((sw / 2, y, c[2] - sh / 2)),
           Vector((sw / 2, y, c[2] + sh / 2)), Vector((-sw / 2, y, c[2] + sh / 2))]
    b.face(pts[::-1], [(0, 1), (1, 1), (1, 0), (0, 0)][::-1], "paper")
    out.append(b.to_object("CB_Screen", ref["Screen"]))

    # ears: cardboard discs with a brass paper fastener
    for side, nm in ((-1, "L"), (1, "R")):
        b = Builder()
        n = X * side
        m = Matrix((Y, Z, n)).transposed().to_4x4() if side > 0 else Matrix((-Y, Z, n)).transposed().to_4x4()
        xf = Matrix.Translation(Vector((side * (0.29 + 0.002), 0.01, 0.74))) @ m
        b.poly_slab(circle(0.082, 28), 0.022, xf)
        out.append(b.to_object("CB_Ear" + nm, ref["Ear" + nm]))
        b = Builder()
        b.dome((side * 0.314, 0.01, 0.74), n, 0.02, 0.012)
        out.append(b.to_object("CB_EarDot" + nm, ref["EarDot" + nm]))

    # antenna: a striped paper straw with a cardboard star coloured in yellow
    b = Builder()
    b.tube((0.0, 0.0, 0.93), (0.004, -0.008, 1.12), 0.013, wall=0.003, segs=12, outer="straw", inner="tubein", rim="paper")
    out.append(b.to_object("CB_AntStick", ref["AntStick"]))
    b = Builder()
    m = Matrix((X, Z, -Y)).transposed().to_4x4()
    xf = Matrix.Translation(Vector((0.004, 0.0, 1.165))) @ Matrix.Rotation(math.radians(8), 4, Y) @ m
    b.poly_slab(sparkle(0.075, 0.36), 0.014, xf, face_mat="yellow", rim_mat="flute")
    out.append(b.to_object("CB_Star", ref["Star"]))

    # ------------------------------------------------------------ body: a smaller box
    b = Builder()
    x0, x1, y0, y1, z0, z1 = -0.18, 0.18, -0.15, 0.15, 0.17, 0.52
    cx, cy, cz = 0.0, 0.0, (z0 + z1) / 2
    W, D, H = x1 - x0, y1 - y0, z1 - z0
    b.board((cx, y1, cz), W, H, Y, Z, wobble=0.6)
    b.board((cx, y0 + T, cz), W - 2 * T, H, -Y, Z)
    b.board((x0 + T, cy, cz), D - 2 * T, H, -X, Z)
    b.board((x1 - T, cy, cz), D - 2 * T, H, X, Z)
    b.board((cx, cy, z0 + T), W - 2 * T, D - 2 * T, -Z, Y)
    for sx in (-1, 1):
        xe = x1 if sx > 0 else x0
        b.tape((xe + sx * 0.001, y1 - 0.02, z0 + 0.02), (xe + sx * 0.001, y1 - 0.02, z1 - 0.02), X * sx, 0.04)
        b.tape((xe - sx * 0.02, y1 + 0.001, z0 + 0.02), (xe - sx * 0.02, y1 + 0.001, z1 - 0.06), Y, 0.04)
    b.tape((x0 + 0.03, y1 + 0.001, z0 + 0.025), (x1 - 0.03, y1 + 0.001, z0 + 0.03), Y, 0.035)
    out.append(b.to_object("CB_Body", ref["Body"]))
    # belly: a white paper sticker (the level draws the emblem on it)
    b = Builder()
    y = 0.15 + 0.0025
    s = 0.105
    zc = 0.355
    pts = [Vector((-s, y, zc - s)), Vector((s, y, zc - s)), Vector((s, y, zc + s)), Vector((-s, y, zc + s))]
    b.face(pts[::-1], [(0, 1), (1, 1), (1, 0), (0, 0)][::-1], "paper")
    out.append(b.to_object("CB_Belly", ref["Belly"]))

    # ------------------------------------------------------------ arms: paper tubes with mitten hands
    for side, nm in ((-1, "L"), (1, "R")):
        b = Builder()
        b.tube((side * 0.2, 0.0, 0.47), (side * 0.25, 0.03, 0.27), 0.046)
        out.append(b.to_object("CB_Arm" + nm, ref["Arm" + nm]))
        b = Builder()
        m = Matrix((Y * -side, Z, X * side)).transposed().to_4x4()
        xf = Matrix.Translation(Vector((side * 0.262, 0.035, 0.24))) @ Matrix.Rotation(math.radians(-10 * side), 4, Y) @ m
        b.poly_slab(mitten(1.15), 0.016, xf)
        out.append(b.to_object("CB_Arm" + nm + "Hand", ref["Arm" + nm + "Hand"]))

    # ------------------------------------------------------------ legs: tubes, matchbox feet
    for side, nm in ((-1, "L"), (1, "R")):
        b = Builder()
        b.tube((side * 0.095, 0.0, 0.215), (side * 0.095, 0.01, 0.07), 0.052)
        out.append(b.to_object("CB_Leg" + nm, ref["Leg" + nm]))
        b = Builder()
        fx0, fx1 = (side * 0.02, side * 0.175) if side > 0 else (side * 0.175, side * 0.02)
        fy0, fy1, fz0, fz1 = -0.08, 0.14, 0.0, 0.082
        fc = Vector(((fx0 + fx1) / 2, (fy0 + fy1) / 2, (fz0 + fz1) / 2))
        fw, fd, fh = abs(fx1 - fx0), fy1 - fy0, fz1 - fz0
        t2 = 0.008
        b.board((fc.x, fc.y, fz1), fw, fd, Z, Y, thick=t2, face_mat="paper", rim_mat="kraft", wobble=0.5)
        b.board((fc.x, fc.y, fz0 + t2), fw, fd, -Z, Y, thick=t2, wobble=0.0)
        b.board((fc.x, fy1, fc.z), fw, fh - 2 * t2, Y, Z, thick=t2, face_mat="kraft", rim_mat="kraft", wobble=0.0)
        b.board((fc.x, fy0 + t2, fc.z), fw, fh - 2 * t2, -Y, Z, thick=t2, wobble=0.0)
        for sx in (-1, 1):
            xe = fx1 if sx > 0 else fx0
            # the striker strip on the outer side (dark red-brown)
            outer = (sx > 0) == (side > 0)
            b.board((xe - sx * t2 * (0 if True else 1), fc.y, fc.z), fd - 2 * t2, fh - 2 * t2, X * sx, Z, thick=t2,
                    face_mat="tubein" if outer else "kraft", rim_mat="kraft", wobble=0.0)
        out.append(b.to_object("CB_Leg" + nm + "Foot", ref["Leg" + nm + "Foot"]))

    # ------------------------------------------------------------ the USB stick (hinge at origin, up = +Z)
    b = Builder()
    bw, bt, bl = 0.15, 0.048, 0.19
    b.board((0, 0, bl / 2), bw, bl, Y, Z, thick=bt, wobble=0.0)
    b.tape((-bw / 2 - 0.004, bt * 0.0 + 0.001, bl * 0.55), (bw / 2 + 0.004, 0.001, bl * 0.55), Y, 0.05)
    b.tape((-bw / 2 - 0.004, -bt - 0.001, bl * 0.55), (bw / 2 + 0.004, -bt - 0.001, bl * 0.55), -Y, 0.05)
    # metal connector
    cw, ct, cl = 0.125, 0.04, 0.12
    yc = -bt / 2
    zb = bl
    def steel_box(xa, xb, ya, yb, za, zb_):
        v = [Vector((xa, ya, za)), Vector((xb, ya, za)), Vector((xb, yb, za)), Vector((xa, yb, za)),
             Vector((xa, ya, zb_)), Vector((xb, ya, zb_)), Vector((xb, yb, zb_)), Vector((xa, yb, zb_))]
        for q in ((0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7), (3, 2, 1, 0)):
            b.face([v[i] for i in q], [(0, 0), (1, 0), (1, 1), (0, 1)], "steel")
    steel_box(-cw / 2, cw / 2, yc - ct / 2, yc + ct / 2, zb, zb + cl)
    # the two square holes on the connector face (dark inlays)
    for hx in (-0.028, 0.028):
        y = yc + ct / 2 + 0.0008
        z = zb + cl * 0.62
        s = 0.014
        b.face([Vector((hx - s, y, z - s)), Vector((hx + s, y, z - s)), Vector((hx + s, y, z + s)), Vector((hx - s, y, z + s))][::-1],
               [(0, 0)] * 4, "tubein")
    out.append(b.to_object("CB_USB", None))

    # placeholder materials so the exporter writes them by name
    for o in bpy.data.objects:
        o.select_set(False)
    for o in out:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = out[0]
    bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_format='GLB', export_yup=True,
                              export_apply=True, export_normals=True, export_materials='EXPORT',
                              export_animations=False)
    print("wrote", OUT, len(out), "parts")


build()
