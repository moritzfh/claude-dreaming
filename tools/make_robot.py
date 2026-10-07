# Builds the Claude robot in Blender (bpy) and exports it as glb.
# Face points to Blender +Y (= Godot -Z / forward). Units: meters. Total height ~0.95m
import bpy, bmesh, math
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene

def mat(name, col, rough=0.5, metal=0.0, emis=None, es=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emis:
        b.inputs["Emission Color"].default_value = (*emis, 1)
        b.inputs["Emission Strength"].default_value = es
    return m

M_CREAM = mat("Cream", (0.93, 0.90, 0.84), 0.42)
M_CORAL = mat("Coral", (0.88, 0.34, 0.22), 0.5)
M_WHITE = mat("White", (0.95, 0.94, 0.91), 0.5)
M_GOLD  = mat("Gold",  (0.92, 0.70, 0.32), 0.3, 0.85)
M_STAR  = mat("Star",  (1.0, 0.72, 0.55), 0.4, 0.0, (1.0, 0.6, 0.4), 1.5)
M_SCREEN= mat("Screen",(0.02, 0.02, 0.03), 0.15)
M_BEZEL = mat("Bezel", (0.10, 0.09, 0.10), 0.3)

def finish(o, m, smooth=True):
    o.data.materials.clear(); o.data.materials.append(m)
    if smooth:
        for p in o.data.polygons: p.use_smooth = True
    return o

def apply_mods(o):
    dg = bpy.context.evaluated_depsgraph_get()
    oe = o.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(oe)
    o.modifiers.clear()
    o.data = me
    return o

def set_origin(o, p):
    # move object origin to world point p without moving geometry
    p = Vector(p)
    off = p - o.location
    o.data.transform(__import__('mathutils').Matrix.Translation(-off))
    o.location = p

def rounded_box(name, size, bevel, seg=6, m=M_CREAM, loc=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object; o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    md = o.modifiers.new("bev", "BEVEL"); md.width = bevel; md.segments = seg; md.limit_method = 'NONE'
    apply_mods(o)
    return finish(o, m)

def sphere(name, r, scale=(1,1,1), loc=(0,0,0), m=M_CORAL, seg=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg, ring_count=rings, location=loc)
    o = bpy.context.active_object; o.name = name; o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m)

def capsule(name, p0, p1, r, m=M_CORAL):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0; L = d.length
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=r)
    # stretch upper hemisphere to make capsule along +Z
    for v in bm.verts:
        if v.co.z > 0: v.co.z += L
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scn.collection.objects.link(o)
    o.location = p0
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = Vector((0,0,1)).rotation_difference(d.normalized())
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(o, m)

def rounded_rect_plane(name, w, h, r, seg=8, m=M_SCREEN):
    # flat rounded rectangle in XZ plane facing +Y, UV 0..1
    pts = []
    corners = [( w/2-r,  h/2-r, 0), (-w/2+r,  h/2-r, 90), (-w/2+r, -h/2+r, 180), ( w/2-r, -h/2+r, 270)]
    for cx, cz, a0 in corners:
        for i in range(seg+1):
            a = math.radians(a0 + 90*i/seg)
            pts.append((cx + r*math.cos(a), cz + r*math.sin(a)))
    bm = bmesh.new()
    c = bm.verts.new((0,0,0))
    vs = [bm.verts.new((x, 0, z)) for x, z in pts]
    for i in range(len(vs)):
        bm.faces.new((c, vs[(i+1)%len(vs)], vs[i]))
    uv = bm.loops.layers.uv.new()
    for f in bm.faces:
        for l in f.loops:
            l[uv].uv = ((l.vert.co.x + w/2)/w, (l.vert.co.z + h/2)/h)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scn.collection.objects.link(o)
    return finish(o, m, smooth=False)

def parent(child, par):
    bpy.context.view_layer.update()   # make sure matrix_world reflects origin changes
    mw = child.matrix_world.copy()
    child.parent = par
    child.matrix_world = mw

# ---------------- dimensions
HIP_Z = 0.20
HEAD_W, HEAD_D, HEAD_H = 0.58, 0.48, 0.46
NECK_Z = 0.50

root = bpy.data.objects.new("Robot", None); scn.collection.objects.link(root)

# ---------------- body (pivot at hips)
body = sphere("Body", 0.2, scale=(0.98, 0.84, 0.92), loc=(0, 0, 0.35), m=M_CORAL)
belly = sphere("Belly", 0.105, scale=(1.0, 0.25, 1.0), loc=(0, 0.145, 0.33), m=M_WHITE)
set_origin(body, (0, 0, HIP_Z)); set_origin(belly, (0, 0, HIP_Z))
# small star emblem on belly
def star_mesh(name, R, r, depth, m, loc, axis='Y'):
    bm = bmesh.new()
    top = []; bot = []
    for i in range(10):
        a = math.pi/2 + i*math.pi/5
        rr = R if i % 2 == 0 else r
        x, z = rr*math.cos(a), rr*math.sin(a)
        top.append(bm.verts.new((x,  depth/2, z)))
        bot.append(bm.verts.new((x, -depth/2, z)))
    bm.faces.new(top); bm.faces.new(list(reversed(bot)))
    for i in range(10):
        j = (i+1) % 10
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scn.collection.objects.link(o)
    o.location = loc
    return finish(o, m, smooth=False)
emblem = star_mesh("Emblem", 0.03, 0.013, 0.01, M_CORAL, (0, 0.172, 0.34))

# ---------------- head (pivot at neck)
head = rounded_box("Head", (HEAD_W, HEAD_D, HEAD_H), 0.075, 7, M_CREAM, loc=(0, 0.01, NECK_Z + HEAD_H/2))
set_origin(head, (0, 0, NECK_Z))
fy = 0.01 + HEAD_D/2
bezel = rounded_rect_plane("Bezel", 0.47, 0.33, 0.06, m=M_BEZEL)
bezel.location = (0, fy + 0.0015, NECK_Z + HEAD_H/2 - 0.005)
screen = rounded_rect_plane("Screen", 0.445, 0.305, 0.05, m=M_SCREEN)
screen.location = (0, fy + 0.003, NECK_Z + HEAD_H/2 - 0.005)
# ears
ears = []
for s in (-1, 1):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.085, depth=0.035, vertices=48,
        location=(s*(HEAD_W/2 + 0.01), 0.01, NECK_Z + HEAD_H/2 + 0.01), rotation=(0, math.pi/2, 0))
    e = bpy.context.active_object; e.name = "Ear" + ("L" if s < 0 else "R")
    md = e.modifiers.new("bev", "BEVEL"); md.width = 0.012; md.segments = 4; apply_mods(e)
    finish(e, M_CORAL)
    d = sphere("EarDot" + ("L" if s < 0 else "R"), 0.014, (0.5, 1, 1), (s*(HEAD_W/2 + 0.03), 0.04, NECK_Z + HEAD_H/2 + 0.04), M_GOLD, 16, 8)
    ears += [e, d]
# antenna (pivot at top of head)
TOP = NECK_Z + HEAD_H
ant_base = sphere("AntBase", 0.03, (1, 1, 0.45), (0, 0.0, TOP), M_GOLD, 24, 12)
stick = capsule("AntStick", (0, 0, TOP), (0.0, -0.02, TOP + 0.17), 0.009, M_GOLD)
star = star_mesh("Star", 0.05, 0.022, 0.016, M_STAR, (0, -0.02, TOP + 0.2))
antenna = bpy.data.objects.new("Antenna", None); scn.collection.objects.link(antenna)
antenna.location = (0, 0, TOP)

# ---------------- arms (pivot at shoulders)
arms = []
for s, nm in ((-1, "ArmL"), (1, "ArmR")):
    sh = Vector((s*0.17, 0.0, 0.42))
    hand_p = Vector((s*0.26, 0.05, 0.28))
    a = capsule(nm, sh, hand_p, 0.062, M_CORAL)
    cuff = capsule(nm + "Cuff", hand_p - (hand_p - sh).normalized()*0.01, hand_p + (hand_p - sh).normalized()*0.005, 0.064, M_BEZEL)
    h = sphere(nm + "Hand", 0.068, (1, 0.95, 1.05), tuple(hand_p + (hand_p - sh).normalized()*0.04), M_WHITE, 32, 16)
    for o in (a, cuff, h): set_origin(o, sh)
    arms.append((a, cuff, h))

# ---------------- legs (pivot at hips)
legs = []
for s, nm in ((-1, "LegL"), (1, "LegR")):
    hip = Vector((s*0.095, 0, 0.22))
    knee = Vector((s*0.10, 0.0, 0.08))
    l = capsule(nm, hip, knee, 0.072, M_CORAL)
    foot = sphere(nm + "Foot", 0.085, (0.95, 1.25, 0.62), (s*0.10, 0.03, 0.05), M_CORAL, 32, 16)
    for o in (l, foot): set_origin(o, hip)
    legs.append((l, foot))

# ---------------- hierarchy
for o in (body,): parent(o, root)
for o in (belly, emblem, head): parent(o, body)
for o in (bezel, screen, *ears, antenna, ant_base): parent(o, head)
for o in (stick, star): parent(o, antenna)
for a, cuff, h in arms:
    parent(a, body); parent(cuff, a); parent(h, a)
for l, foot in legs:
    parent(l, root); parent(foot, l)

bpy.ops.export_scene.gltf(filepath="/home/claude/dreamgame/assets/models/robot.glb", export_format='GLB', export_apply=True, export_yup=True)
print("OK robot")
