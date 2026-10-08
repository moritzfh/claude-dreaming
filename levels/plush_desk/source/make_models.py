"""Blender (bpy) generator for the Plush Desk hero meshes.

Run with Blender's Python module (pip install bpy):
    python make_models.py [keycap planet mouse pad kb_base]   # default: all
Writes ../models/<name>.glb (Y-up, metres).

Every stuffed shape is made the way a plush is: panels are "sewn" together
(the seam vertices are pinned) and the inside is inflated with a cloth
pressure simulation, so the panels bulge, the seams pinch in and the fabric
wrinkles around them. UV0 is 0..1 per panel (seams/stitches/labels in the
shader), the colour attribute carries per-panel flags:
    R = panel id / 16, G = 1 on the top panel (keycaps), B = seam closeness.
"""
import sys, os, math
import bpy, bmesh
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "models")
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.gravity = (0, 0, 0)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    return obj


def cube_panels(sx, sy, sz, cuts):
    """Subdivided box as a bmesh; returns (bm, panel id per face, (u,v) per loop)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def face_panel(n):
    """+X 0, -X 1, +Y 2, -Y 3, +Z 4 (top), -Z 5 (bottom)."""
    a = max(range(3), key=lambda i: abs(n[i]))
    return a * 2 + (0 if n[a] > 0 else 1)


def panel_uv(p, co, half):
    """UV 0..1 on a box panel, seen from outside, v down."""
    x, y, z = co.x / half.x, co.y / half.y, co.z / half.z
    if p == 0: u, v = -y, -z
    elif p == 1: u, v = y, -z
    elif p == 2: u, v = x, -z
    elif p == 3: u, v = -x, -z
    elif p == 4: u, v = x, -y
    else: u, v = x, y
    return (u * 0.5 + 0.5, v * 0.5 + 0.5)


def write_attrs(bm, half, seam_fn, top_panel=4):
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.float_color.new("Col")
    for f in bm.faces:
        p = face_panel(f.normal)
        for l in f.loops:
            u, v = panel_uv(p, l.vert.co, half)
            l[uv].uv = (u, 1.0 - v)
            l[col] = (p / 16.0, 1.0 if p == top_panel else 0.0, seam_fn(l.vert), 1.0)


def inflate(obj, pin_group, frames, pressure, shrink=0.0, shrink_group=None,
            stiff=12.0, bend=0.3, quality=6):
    mod = obj.modifiers.new("Cloth", 'CLOTH')
    s = mod.settings
    s.quality = quality
    s.mass = 0.25
    s.air_damping = 2.0
    s.tension_stiffness = stiff
    s.compression_stiffness = stiff
    s.shear_stiffness = stiff * 0.4
    s.bending_stiffness = bend
    s.use_pressure = True
    s.uniform_pressure_force = pressure
    s.effector_weights.gravity = 0.0
    if pin_group:
        s.vertex_group_mass = pin_group
        s.pin_stiffness = 1.0
    if shrink:
        s.shrink_min = shrink
        if shrink_group:
            s.vertex_group_shrink = shrink_group
    mod.point_cache.frame_start = 1
    mod.point_cache.frame_end = frames
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 1, frames
    for f in range(1, frames + 1):
        sc.frame_set(f)
    before = [v.co.copy() for v in obj.data.vertices]
    bpy.ops.object.modifier_apply(modifier=mod.name)
    moved = max((v.co - b).length for v, b in zip(obj.data.vertices, before))
    print("  cloth: max displacement %.4f" % moved)


def finish(obj, name, smooth_iters=0):
    me = obj.data
    if smooth_iters:
        bm = bmesh.new(); bm.from_mesh(me)
        for _ in range(smooth_iters):
            bmesh.ops.smooth_vert(bm, verts=bm.verts[:], factor=0.5,
                                  use_axis_x=True, use_axis_y=True, use_axis_z=True)
        bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = True
    obj.name = name
    me.name = name


def export(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format='GLB',
                              export_yup=True, export_apply=True, export_normals=True,
                              export_tangents=False, export_vertex_color='ACTIVE',
                              export_all_vertex_colors=False, export_materials='NONE',
                              export_animations=False)
    print("wrote", path)


def mesh_from_bm(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if "Col" in me.color_attributes:
        me.color_attributes.active_color = me.color_attributes["Col"]
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
    return link(bpy.data.objects.new(name, me))


def box_grid(sx, sy, sz, cell):
    """Closed box surface with roughly square quads of size `cell` (bmesh)."""
    bm = bmesh.new()
    nx, ny, nz = (max(2, round(v / cell)) for v in (sx, sy, sz))
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    def face(origin, du, dv, nu, nv):
        grid = []
        for j in range(nv + 1):
            row = []
            for i in range(nu + 1):
                row.append(bm.verts.new(origin + du * (i / nu) + dv * (j / nv)))
            grid.append(row)
        for j in range(nv):
            for i in range(nu):
                bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    V = Vector
    face(V((-hx, -hy, hz)), V((sx, 0, 0)), V((0, sy, 0)), nx, ny)      # top
    face(V((-hx, -hy, -hz)), V((0, sy, 0)), V((sx, 0, 0)), ny, nx)     # bottom
    face(V((-hx, -hy, -hz)), V((sx, 0, 0)), V((0, 0, sz)), nx, nz)     # -y
    face(V((-hx, hy, -hz)), V((0, 0, sz)), V((sx, 0, 0)), nz, nx)      # +y
    face(V((-hx, -hy, -hz)), V((0, 0, sz)), V((0, sy, 0)), nz, ny)     # -x
    face(V((hx, -hy, -hz)), V((0, sy, 0)), V((0, 0, sz)), ny, nz)      # +x
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def round_box(bm, half, r):
    """Push the box surface onto a rounded box with edge radius r."""
    inner = Vector((half.x - r, half.y - r, half.z - r))
    for v in bm.verts:
        c = Vector((max(-inner.x, min(inner.x, v.co.x)), max(-inner.y, min(inner.y, v.co.y)),
                    max(-inner.z, min(inner.z, v.co.z))))
        d = v.co - c
        if d.length > 1e-6:
            v.co = c + d.normalized() * r


def cushion(name, sx, sy, sz, cell, pressure=8.0, stiff=5.0, frames=20, seam_w=0.06, round_r=0.0):
    """A stuffed box (bottom pinned flat), origin at the bottom centre. Blender axes."""
    reset()
    half = Vector((sx / 2, sy / 2, sz / 2))
    bm = box_grid(sx, sy, sz, cell)
    seam = lambda v: max(0.0, 1.0 - sorted([half.x - abs(v.co.x), half.y - abs(v.co.y),
                                            half.z - abs(v.co.z)])[0] / seam_w) if False else \
        max(0.0, 1.0 - sorted([half.x - abs(v.co.x), half.y - abs(v.co.y), half.z - abs(v.co.z)])[1] / seam_w)
    write_attrs(bm, half, seam)
    if round_r:
        round_box(bm, half, round_r)
    obj = mesh_from_bm(bm, name)
    vg = obj.vertex_groups.new(name="pin")
    vg.add([v.index for v in obj.data.vertices if v.co.z < -half.z + 1e-4], 1.0, 'REPLACE')
    inflate(obj, "pin", frames, pressure=pressure, stiff=stiff, bend=0.15)
    zmin = min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co.z -= zmin
    finish(obj, name, smooth_iters=1)
    export([obj], name)
    return obj


# ------------------------------------------------------------------- keycap
def keycap(pressure=10.0, out="keycap", stiff=4.0):
    """1u felt key cushion, 0.42 x 0.42, 0.24 high, origin at the bottom centre.
    The shader stretches it horizontally for wider keys (9-slice in the vertex
    shader), so the middle is a flat band of vertices at x = 0."""
    reset()
    half = Vector((0.21, 0.21, 0.12))
    bm = cube_panels(half.x * 2, half.y * 2, half.z * 2, 15)
    seam = lambda v: max(0.0, 1.0 - min(half.x - abs(v.co.x), half.y - abs(v.co.y),
                                        half.z - abs(v.co.z)) / 0.03)
    write_attrs(bm, half, seam)
    obj = mesh_from_bm(bm, "keycap")
    vg = obj.vertex_groups.new(name="pin")
    vg.add([v.index for v in obj.data.vertices if v.co.z < -half.z + 1e-4], 1.0, 'REPLACE')
    inflate(obj, "pin", 18, pressure=pressure, stiff=stiff, bend=0.15)
    # origin to the bottom centre
    zmin = min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co.z -= zmin
    finish(obj, out, smooth_iters=1)
    export([obj], out)


# ------------------------------------------------------------------- plush ball
def plush_ball(name, radius, cuts=20, pressure=12.0, stiff=5.0, seam_depth=0.06, shrink=0.05):
    """Cube-sphere sewn from 6 panels, seams pulled in and pinned, panels inflated."""
    reset()
    half = Vector((1, 1, 1))
    bm = cube_panels(2, 2, 2, cuts)
    def seam_cube(v):
        a = sorted([1 - abs(v.co.x), 1 - abs(v.co.y), 1 - abs(v.co.z)])
        return max(0.0, 1.0 - a[1] / 0.1)
    bm.verts.index_update()
    seam_vals = {v.index: seam_cube(v) for v in bm.verts}
    write_attrs(bm, half, lambda v: seam_vals[v.index])
    on_seam = [v.index for v in bm.verts if seam_vals[v.index] > 0.999]
    near = [v.index for v in bm.verts if seam_vals[v.index] > 0.3]
    for v in bm.verts:
        s = seam_vals[v.index]
        v.co = v.co.normalized() * radius * (1.0 - seam_depth * s * s)
    obj = mesh_from_bm(bm, name)
    vg = obj.vertex_groups.new(name="pin")
    vg.add(on_seam, 1.0, 'REPLACE')
    sg = obj.vertex_groups.new(name="shrink")
    sg.add(near, 1.0, 'REPLACE')
    inflate(obj, "pin", 20, pressure=pressure, stiff=stiff, bend=0.1, shrink=shrink, shrink_group="shrink")
    finish(obj, name, smooth_iters=1)
    export([obj], name)


# ------------------------------------------------------------------- mouse
def plush_mouse():
    """Stuffed computer mouse, 1.7 wide, 2.9 long, ~1.05 high (Blender: +Y = front).
    Seams: the split between the two buttons and the line around the bottom."""
    reset()
    half = Vector((1, 1, 1))
    bm = cube_panels(2, 2, 2, 22)
    write_attrs(bm, half, lambda v: 0.0)
    for v in bm.verts:
        p = v.co.normalized()
        x, y, z = p.x, p.y, p.z
        hump = 1.0 + 0.32 * max(0.0, -y) - 0.18 * max(0.0, y)
        X = x * 0.85 * (1.0 - 0.1 * max(0.0, y))
        Y = y * 1.45
        Z = z * 0.62 * hump if z > 0 else z * 0.16
        v.co = Vector((X, Y, Z))
    zmin = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z -= zmin
    bm.verts.index_update()
    seam = [v.index for v in bm.verts if (abs(v.co.x) < 0.03 and v.co.y > 0.2 and v.co.z > 0.35) or v.co.z < 0.09]
    obj = mesh_from_bm(bm, "mouse")
    # seam closeness into the colour attribute (B) for the shader
    col = obj.data.color_attributes["Col"]
    for poly in obj.data.polygons:
        for li in poly.loop_indices:
            vi = obj.data.loops[li].vertex_index
            co = obj.data.vertices[vi].co
            split = max(0.0, 1.0 - abs(co.x) / 0.08) if (co.y > 0.15 and co.z > 0.3) else 0.0
            bottom = max(0.0, 1.0 - (co.z - 0.05) / 0.08) if co.z > 0.05 else 1.0
            c = list(col.data[li].color)
            c[2] = max(split, bottom * 0.6)
            col.data[li].color = c
    vg = obj.vertex_groups.new(name="pin")
    vg.add(seam, 1.0, 'REPLACE')
    inflate(obj, "pin", 16, pressure=2.5, stiff=8.0, bend=0.2)
    zmin = min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co.z -= zmin
    finish(obj, "mouse", smooth_iters=2)
    export([obj], "mouse")


if __name__ == "__main__":
    want = sys.argv[1:] or ["keycap", "planet", "mouse", "pad", "kb_base"]
    if "keycap" in want:
        keycap()
    if "planet" in want:
        plush_ball("planet", 1.0, cuts=24)
    if "mouse" in want:
        plush_mouse()
    if "pad" in want:
        cushion("pad", 5.4, 4.6, 0.12, 0.08, pressure=0.05, stiff=12.0, round_r=0.05)
    if "kb_base" in want:
        # keyboard case: 18.25u x 6.4u keys at 0.55 pitch + border, 0.34 high
        cushion("kb_base", 18.25 * 0.55 + 2.2, 6.4 * 0.55 + 0.7, 0.36, 0.06, pressure=0.06, stiff=12.0, round_r=0.16)
