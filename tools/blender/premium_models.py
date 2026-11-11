"""Sort the Shipment / Harbour Collection. Original geometry, mobile-oriented.

Run Blender 5.2: blender -b --python tools/blender/premium_models.py
Godot coordinates throughout; exports preserve the original gameplay contract.
No external textures, fonts, downloads or asset dependencies.
"""
import sys, math, json, pathlib, importlib.util
import bpy, bmesh
from mathutils import Vector

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
import lib

OUT = ROOT / 'assets/models'
EDIT = ROOT / 'art_source'
EDIT.mkdir(exist_ok=True)
(EDIT / '.gdignore').touch()
REPORT = []

# All fixed paint is stored in linear vertex colours, retaining static batching.
PALETTE = {
    'Cream': (248, 239, 216), 'White': (255, 250, 237),
    'Navy': (32, 58, 77), 'Glass': (36, 97, 117),
    'Glint': (135, 211, 211), 'Teal': (33, 135, 142),
    'Coral': (230, 105, 80), 'Gold': (242, 184, 68),
    'Steel': (143, 171, 177), 'Dark': (37, 48, 58),
    'Rubber': (35, 44, 50), 'Sand': (210, 190, 157),
    'Wood': (170, 118, 73), 'Leaf': (69, 151, 104),
    'LeafLight': (108, 183, 113), 'LeafDark': (29, 108, 94),
    'Bark': (143, 102, 66), 'BarkLight': (183, 140, 87),
    'Lamp': (255, 226, 151), 'Roof': (93, 129, 142),
    'Stone': (225, 212, 187), 'Terracotta': (194, 107, 74),
    'Red': (225, 80, 83), 'Blue': (70, 143, 195),
    'HullWhite': (251, 244, 224), 'BootTop': (37, 56, 69),
    'Bottom': (138, 57, 52),
}

def B(c, s, m, bevel=0.0, seg=2):
    return lib.box(c, s, m, bevel=bevel, segments=seg)

def C(c, r, h, m, n=12, axis='y', rt=None):
    return lib.cylinder(c,r,h,m,segs=n,axis=axis,radius_top=rt)

def E(a,b,t,m):
    return lib.beam(a,b,t,m)

def blob(c, scale, mat, sub=2):
    bm=bmesh.new()
    bmesh.ops.create_icosphere(bm,subdivisions=sub,radius=1)
    for v in bm.verts:
        v.co.x*=scale[0]; v.co.y*=scale[2]; v.co.z*=scale[1]
    bmesh.ops.translate(bm,verts=bm.verts,vec=lib.g2b(*c))
    return lib._obj_from_bm(bm,'sculpted_form',mat)

def ring(c, major, minor, mat, axis='z', n=16, k=6):
    vs=[]; fs=[]
    for i in range(n):
        a=i*math.tau/n
        for j in range(k):
            b=j*math.tau/k
            rr=major+minor*math.cos(b)
            u,v,w=rr*math.cos(a),rr*math.sin(a),minor*math.sin(b)
            p=(w,u,v) if axis=='x' else ((u,w,v) if axis=='y' else (u,v,w))
            vs.append(tuple(c[t]+p[t] for t in range(3)))
    for i in range(n):
        for j in range(k):
            fs.append([i*k+j,((i+1)%n)*k+j,((i+1)%n)*k+(j+1)%k,i*k+(j+1)%k])
    return lib.mesh_from(vs,fs,mat,'ring')

def colour_nodes(ob, keep, tint=(61,143,232)):
    for m in ob.data.materials:
        m.use_nodes=True
        nt=m.node_tree; nt.nodes.clear()
        bs=nt.nodes.new('ShaderNodeBsdfPrincipled')
        bs.inputs['Roughness'].default_value=.48
        vc=nt.nodes.new('ShaderNodeVertexColor'); vc.layer_name='AO'
        mix=nt.nodes.new('ShaderNodeMixRGB'); mix.blend_type='MULTIPLY'; mix.inputs[0].default_value=1
        rgb=(255,255,255)
        if m.name in keep:
            rgb=tint if m.name in {'Hull','Funnel'} else tuple(round(t*.22+235*.78) for t in tint)
        linear=tuple((v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4) for v in rgb)
        mix.inputs[2].default_value=(*linear,1)
        nt.links.new(vc.outputs['Color'],mix.inputs[1]); nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
        out=nt.nodes.new('ShaderNodeOutputMaterial'); nt.links.new(bs.outputs[0],out.inputs[0])
        m.diffuse_color=(*linear,1)

def finish(parts,name,keep=None,palette=None,ao=.45,tint=(61,143,232),gray=None):
    keep=set() if keep is None else keep
    ob=lib.join(parts,name)
    # Remove unused vertices inherited from the lofted hull's material islands.
    bm=bmesh.new(); bm.from_mesh(ob.data)
    loose=[v for v in bm.verts if not v.link_faces]
    if loose: bmesh.ops.delete(bm,geom=loose,context='VERTS')
    bm.to_mesh(ob.data); bm.free()
    lib.auto_smooth(ob,40)
    lib.bake_ao(ob,ground=not name.startswith('ship'),distance=ao,samples=12,max_len=0)
    attr=ob.data.color_attributes['AO']
    for d in attr.data:
        v=.48+.52*d.color[0]
        d.color=(v,v,v,1)
    if gray:
        for p in ob.data.polygons:
            f=gray.get(ob.data.materials[p.material_index].name,1.0)
            for li in p.loop_indices:
                col=attr.data[li].color
                attr.data[li].color=(col[0]*f,col[1]*f,col[2]*f,1)
        for p in ob.data.polygons: p.material_index=0
        ob.data.materials.clear(); ob.data.materials.append(lib.mat('Body'))
        keep={'Body'}
    else:
        lib.collapse_fixed_materials(ob,keep,palette or PALETTE)
    # Export conventional PBR base factors; the game applies its own named materials.
    for m in ob.data.materials:
        m.use_nodes=True
        bs=m.node_tree.nodes.get('Principled BSDF')
        rgb=tint if m.name in {'Hull','Funnel'} else ((61,143,232) if gray else (255,255,255))
        if m.name=='Deck': rgb=tuple(round(t*.22+235*.78) for t in tint)
        linear=tuple((v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4) for v in rgb)
        if bs: bs.inputs['Base Color'].default_value=(*linear,1)
    lib.export(ob,str(OUT/(name+'.glb')))
    # Preview/edit source uses the same baked colour data as the GLB.
    colour_nodes(ob,keep,tint)
    if gray:
        m=ob.data.materials[0]
        mix=next(n for n in m.node_tree.nodes if n.type=='MIX_RGB')
        mix.inputs[2].default_value=(.07,.34,.65,1)
    bpy.ops.wm.save_as_mainfile(filepath=str(EDIT/(name+'.blend')),compress=True)
    ob.data.calc_loop_triangles()
    pts=[lib.g2b(0,0,0)] # bounds reported in Godot axes
    coords=[(v.co.x,v.co.z,-v.co.y) for v in ob.data.vertices]
    REPORT.append({'name':name,'triangles':len(ob.data.loop_triangles),'surfaces':len(ob.data.materials),
                   'bounds_min':[round(min(v[i] for v in coords),4) for i in range(3)],
                   'bounds_max':[round(max(v[i] for v in coords),4) for i in range(3)],
                   'bytes':(OUT/(name+'.glb')).stat().st_size})
    print('PREMIUM_FINISHED',name,flush=True)

def container(lod=False):
    lib.reset(); o=[]
    o.append(B((0,.4,0),(.956,.75,1.85),'Body',.025,1 if lod else 2))
    # Raised steel ribs are intentionally broad enough to read at game distance.
    for sx in (-1,1):
        for k in range(5 if lod else 9):
            z=-.76+k*1.52/(4 if lod else 8)
            o.append(B((sx*.479,.4,z),(.028,.61,.046),'Body',0 if lod else .007,1))
        for y in (.045,.755):
            o.append(B((sx*.463,y,0),(.074,.09,1.9),'Frame',0 if lod else .013,1))
    for sz in (-1,1):
        for y in (.045,.755): o.append(B((0,y,sz*.913),(.86,.09,.074),'Frame',0 if lod else .012,1))
        for sx in (-1,1):
            o.append(B((sx*.458,.4,sz*.908),(.084,.8,.084),'Frame',0 if lod else .012,1))
            if not lod:
                for y in (.048,.752):
                    o.append(B((sx*.45,y,sz*.9),(.1,.096,.1),'Casting',.014,1))
    if not lod:
        # Leave a quiet central area beneath the existing colour-blind symbol.
        for z in (-.72,-.57,.43,.59,.73):
            o.append(B((0,.784,z),(.81,.024,.038),'Body',.006,1))
    for sx in (-1,1):
        o.append(B((sx*.211,.4,-.925),(.407,.60,.018),'Door',0 if lod else .013,1))
    for x in ((-.29,.29) if lod else (-.32,-.11,.11,.32)):
        o.append(C((x,.4,-.937),.011,.56,'Hardware',6))
        if not lod:
            for y in (.19,.62): o.append(B((x,y,-.938),(.048,.035,.024),'Hardware',.006,1))
            o.append(B((x+.025,.35,-.94),(.065,.022,.02),'Hardware',.005,1))
    if not lod:
        for sx in (-1,1):
            for z in (-.5,.5): o.append(B((sx*.492,.06,z),(.016,.042,.19),'Hardware'))
    finish(o,'container_lod' if lod else 'container',gray={'Frame':.82,'Casting':.68,'Hardware':.42,'Door':.91},ao=.19)

def ship(kind):
    # Load just the compatible hull builder; no execution of its original builds.
    scope={'__file__':str(HERE/'ships.py')}
    txt=(HERE/'ships.py').read_text()
    exec(txt[:txt.index('\nbuild("ship_feeder"')],scope)
    lib.reset()
    style=['raked','tanker','straight'][kind]
    o,hw=scope['hull'](style)
    # Painted hatch coamings stay under the original three cargo footprints.
    for x in (-1.15,-.05,1.05):
        o.append(B((x,.97,0),(1.065,.04,1.98),'Navy',.015,1))
        o.append(B((x,.992,0),(1.0,.016,1.90),'Deck',.006,1))
    # Chunkier gunwales and quieter railings create a clear outline on a phone.
    for s in (-1,1):
        xs=[-1.65,-1.15,-.65,-.15,.35,.85,1.35,1.70,1.98,2.19,2.36]
        prev=None
        for x in xs:
            z=s*(hw(x,.95)-.045)
            if abs(z)<.08: continue
            o.append(C((x,1.06,z),.018,.22,'Cream',6))
            p=(x,1.17,z)
            if prev: o.append(E(prev,p,.033,'Cream'))
            prev=p
        o.append(B((-.25,.79,s*1.174),(3.4,.075,.025),'Cream',.01,1))
        # Heavy fenders, bright rescue ring and painted rubbing strake.
        for x in (-1.4,.55,1.37):
            o.append(C((x,.53,s*1.18),.068,.29,'Rubber',10))
        o.append(ring((-2.13,1.56,s*1.077),.10,.027,'Coral'))
    for z in (-.55,.55):
        o.append(C((1.88,1.02,z),.043,.14,'Navy',8))
        o.append(B((1.88,1.09,z),(.18,.04,.06),'Navy',.016,1))
    o.append(B((2.15,1.02,0),(.30,.12,.35),'Navy',.04,2))
    o.append(C((2.14,1.47,0),.025,.78,'Cream',8))
    o.append(C((2.14,1.88,0),.055,.07,'Gold',8))
    # Accommodation is aft of x=-1.72: all slots and entry paths remain clear.
    if kind==0:
        tiers=[(-2.18,1.29,.81,.66,2.02),(-2.20,1.87,.74,.49,1.83),(-2.18,2.36,.74,.46,2.24)]
    elif kind==1:
        tiers=[(-2.19,1.36,.82,.80,2.07),(-2.2,2.01,.76,.48,1.91),(-2.15,2.49,.72,.44,2.20)]
    else:
        tiers=[(-2.18,1.45,.81,1.0,2.06),(-2.18,2.20,.77,.48,2.40)]
    for t,(cx,cy,w,h,d) in enumerate(tiers):
        o.append(B((cx,cy,0),(w,h,d),'Cream',.065,3))
        o.append(B((cx,cy+h/2+.018,0),(w+.065,.065,d+.08),'White',.028,2))
        # Dark glazed panels on every viewing side, with a bright top reflection.
        gy=cy+.07; gw=w-.13; gd=d-.18
        o.append(B((cx+w/2+.003,gy,0),(.018,.185,gd),'Glass',.008,1))
        for s in (-1,1):
            o.append(B((cx,gy,s*(d/2+.004)),(gw,.185,.018),'Glass',.008,1))
            o.append(B((cx,gy+.066,s*(d/2+.015)),(gw*.72,.021,.006),'Glint'))
            for dx in (-.19,.19): o.append(B((cx+dx,gy,s*(d/2+.016)),(.022,.19,.009),'Cream'))
        for z in (-gd*.26,gd*.26):
            o.append(B((cx+w/2+.015,gy,z),(.012,.185,.035),'Cream'))
    # Life rafts sit on a small platform, with softly rounded orange shells.
    for s in (-1,1):
        o.append(B((-2.18,1.72,s*1.02),(.62,.07,.3),'White',.025,1))
        o.append(B((-2.18,1.83,s*1.035),(.49,.19,.23),'Coral',.08,3))
        o.append(B((-2.18,1.91,s*1.035),(.25,.04,.15),'Cream',.02,1))
    ft=[(-2.43,3.52,0),(-2.45,3.65,.3),(-2.45,3.7,-.55)][kind]
    fx,fy,fz=ft
    if kind==1:
        for z in (-.3,.3):
            o.append(C((fx,fy-.625,z),.105,1.15,'Funnel',12))
            o.append(C((fx,fy-.045,z),.115,.09,'Navy',12))
            o.append(C((fx,fy-.23,z),.108,.085,'Cream',12))
    else:
        o.append(B((fx,fy-.75,fz),(.31,1.4,.35),'Funnel',.065,3))
        o.append(B((fx,fy-.05,fz),(.34,.1,.38),'Navy',.03,2))
        o.append(B((fx,fy-.30,fz),(.318,.09,.358),'Cream',.03,2))
    rz=.50 if kind==2 else -.58
    o.append(C((-2.1,3.02,rz),.022,.72,'Navy',8))
    o.append(B((-2.1,3.24,rz),(.08,.065,.6),'White',.022,2))
    o.append(blob((-2.1,2.78,-rz),(.10,.11,.10),'White'))
    if kind==1:
        for z in (-1.015,1.015): o.append(C((-.08,1.07,z),.025,3.35,'Gold',8,'x'))
    if kind==2:
        o.append(B((-2.64,.98,0),(.09,.55,1.47),'Navy',.035,2))
        for z in (-.5,0,.5): o.append(B((-2.694,.99,z),(.02,.36,.055),'Gold'))
    finish(o,['ship_feeder','ship_tanker','ship_coaster'][kind],keep={'Hull','Funnel','Deck'},ao=.52,
           tint=[(239,75,92),(61,143,232),(255,197,61)][kind])

def crane(gold=False):
    lib.reset(); o=[]; main='Gold' if gold else 'Teal'; accent='Coral' if gold else 'Gold'
    # Broad tapered portal legs and clean open trusses replace visual noise.
    for x in (-1.3,1.3):
        for z in (-2.75,.05):
            o.append(B((x,.24,z),(.5,.29,.9),'Navy',.08,2))
            for dz in (-.29,.29): o.append(C((x,.15,z+dz),.15,.52,'Rubber',10,'x'))
            o.append(E((x,.43,z),(x*.87,6.45,z),.27,main))
            o.append(B((x,.80,z),(.32,.59,.32),accent,.025,1))
            for y in (.64,.93): o.append(B((x,y,z),(.329,.11,.329),'Navy'))
        o.append(B((x*.87,6.4,-1.35),(.34,.42,3.22),main,.065,2))
        o.append(E((x,.9,-2.75),(x*.9,6.2,.05),.105,main))
    for z in (-2.75,.05):
        o.append(B((0,6.4,z),(2.95,.42,.35),main,.065,2))
        o.append(B((0,2.35,z),(2.6,.20,.22),main,.025,1))
    for x in (-.61,.61):
        o.append(B((x,6.67,-2.55),(.18,.20,11.9),'Cream',.025,1))
        o.append(B((x,7.27,-2.55),(.13,.14,11.9),'Cream',.025,1))
        for k in range(10):
            z=-8.5+k*1.19
            a,b=(6.73,7.22) if k%2==0 else (7.22,6.73)
            o.append(E((x,a,z),(x,b,z+1.19),.065,'Cream'))
    for z in (-8.4,-6,-3.6,-1.2,1.2,3.3):
        o.append(B((0,6.67,z),(1.26,.1,.1),'Cream'))
    for x in (-1.12,1.12):
        o.append(E((x,6.6,-2.75),(x*.25,9.85,-1.5),.18,main))
        o.append(E((x,6.6,.05),(x*.25,9.85,-1.5),.18,main))
        o.append(E((x*.25,9.85,-1.5),(x*.5,7.25,-7.6),.04,'Navy'))
        o.append(E((x*.25,9.85,-1.5),(x*.5,7.25,3.0),.04,'Navy'))
    o.append(B((0,9.85,-1.5),(.85,.23,.35),accent,.04,2))
    o.append(B((0,7.7,1.77),(1.75,.85,2.15),'Cream',.11,3))
    o.append(B((0,8.14,1.77),(1.88,.12,2.28),main,.045,2))
    for s in (-1,1):
        o.append(B((s*.882,7.66,1.85),(.025,.33,1.32),'Navy',.025,1))
        for z in (1.38,1.68,1.98,2.28): o.append(B((s*.9,7.66,z),(.015,.25,.04),'Steel'))
    tz=-3.6
    o.append(B((0,6.38,tz),(1.35,.35,.94),accent,.055,2))
    o.append(B((.46,5.91,tz+.17),(.61,.6,.65),'Cream',.085,3))
    o.append(B((.46,5.97,tz-.16),(.48,.32,.025),'Glass',.035,2))
    o.append(B((.775,5.97,tz+.17),(.025,.32,.45),'Glass',.025,2))
    for dx in (-.32,.32):
        for dz in (-.55,.55): o.append(E((dx,6.17,tz+dz*.65),(dx,3.8,tz+dz),.022,'Navy'))
    o.append(B((0,3.7,tz),(1.0,.18,1.95),accent,.04,2))
    for z in (-.8,.8): o.append(B((0,3.81,tz+z),(1.06,.08,.1),'Navy',.01,1))
    # Two sturdy access rails and evenly spaced rungs are readable at distance.
    for z in (-.15,.18): o.append(E((1.56,.6,z),(1.39,6.2,z),.04,'Cream'))
    for k in range(14): o.append(B((1.51-k*.011,.7+k*.38,.015),(.05,.035,.39),'Cream'))
    for z in (-8.45,3.3): o.append(C((0,7.43,z),.085,.13,'Coral',10))
    finish(o,'crane_gold' if gold else 'crane',ao=.7)

def warehouse(name,accent):
    lib.reset(); o=[]; w,d,h=7.2,5.0,3.2; f=-2.5
    o.append(B((0,1.55,0),(w,3.1,d),'Cream',.065,2))
    o.append(B((0,.18,0),(7.3,.36,5.1),'Stone',.035,1))
    for x in (-3.5,-1.10,1.10,3.5): o.append(B((x,1.7,f-.03),(.16,2.9,.15),accent,.025,1))
    # Folded roof / broad raised skylights make a recognisable top-view silhouette.
    o.append(B((0,3.29,0),(7.45,.21,5.25),accent,.055,2))
    o.append(B((0,3.41,0),(7.14,.055,4.97),'Roof',.025,1))
    for x in (-2.35,0,2.35):
        o.append(B((x,3.50,.4),(1.48,.14,2.6),'Cream',.055,2))
        o.append(B((x,3.585,.4),(1.30,.045,2.40),'Glass',.025,1))
        for z in (-.4,.4,1.2): o.append(B((x,3.611,z),(1.32,.015,.045),'Glint'))
    for x in (-3.5,3.5): o.append(B((x,3.49,0),(.12,.13,5.16),accent,.025,1))
    for x in (-2.18,.3):
        o.append(B((x,1.26,f-.04),(2.04,2.52,.08),'Navy',.065,2))
        o.append(B((x,1.22,f-.09),(1.81,2.38,.045),'Steel',.025,1))
        for y in (.37,.70,1.03,1.36,1.69,2.02):
            o.append(B((x,y,f-.12),(1.79,.038,.018),'Roof'))
        o.append(B((x,2.61,f-.2),(2.20,.18,.42),accent,.055,2))
        for s in (-1,1):
            o.append(B((x+s*.89,.38,f-.19),(.13,.62,.19),'Navy',.035,2))
            o.append(C((x+s*1.08,.35,f-.36),.055,.7,'Gold',8))
    o.append(B((2.62,1.02,f-.06),(.84,2.05,.07),'Navy',.025,1))
    o.append(B((2.62,1.05,f-.105),(.67,1.82,.025),accent,.015,1))
    o.append(B((2.62,1.53,f-.125),(.48,.42,.015),'Glass',.015,1))
    o.append(B((2.62,2.2,f-.3),(1.2,.09,.65),accent,.03,1))
    o.append(B((.05,2.91,f-.07),(6.5,.32,.06),'Navy',.035,2))
    for x in (-2.75,-1.85,-.95,-.05,.85,1.75,2.65):
        o.append(B((x,2.92,f-.11),(.70,.20,.025),'Glint',.015,1))
    # Plain port emblem; no microscopic lettering.
    o.append(B((2.63,2.63,f-.08),(.7,.25,.03),accent,.025,1))
    for x in (2.47,2.63,2.79): o.append(B((x,2.63,f-.105),(.075,.13,.015),'Cream'))
    finish(o,name,ao=.6)

def arch(cx,y,w,h,z,mat):
    r=w/2; pts=[(cx-r,y,z),(cx+r,y,z),(cx+r,y+h-r,z)]
    for i in range(1,13):
        a=math.pi*i/12; pts.append((cx+r*math.cos(a),y+h-r+r*math.sin(a),z))
    return lib.mesh_from(pts,[list(range(len(pts)))],mat,'arched_opening',outward=lambda c:(0,0,-1))

def house(kind):
    lib.reset(); o=[]
    w,d,h=[(2.2,2,1.6),(2.6,2.2,2.4),(1.9,1.9,2),(2.8,2.4,1.4)][kind]
    accent=['Blue','Teal','Terracotta','Teal'][kind]; f=-d/2
    o.append(B((0,h/2,0),(w,h,d),'Cream',.075,3))
    o.append(B((0,.16,0),(w+.015,.32,d+.015),'Stone',.025,1))
    # Recessed roof terrace, actually enclosed by four parapet walls.
    o.append(B((0,h+.025,0),(w-.10,.05,d-.10),'Sand',.015,1))
    for s in (-1,1):
        o.append(B((s*(w/2-.06),h+.14,0),(.12,.28,d),'Cream',.035,2))
        o.append(B((0,h+.14,s*(d/2-.06)),(w,.28,.12),'Cream',.035,2))
    dx=-w*.23
    o.append(arch(dx,.015,.59,1.05,f-.008,accent))
    o.append(arch(dx,.04,.43,.94,f-.020,'Wood'))
    o.append(C((dx+.12,.45,f-.035),.026,.014,'Gold',8,'z'))
    o.append(B((dx,.035,f-.15),(.72,.07,.3),'Stone',.025,1))
    for wx in (w*.22,):
        for y in ([.64,1.60] if h>2.1 else [.78]):
            o.append(arch(wx,y,.42,.57,f-.015,accent))
            o.append(arch(wx,y+.055,.29,.43,f-.025,'Navy'))
            o.append(B((wx,y+.025,f-.075),(.5,.07,.17),'Stone',.025,1))
            for s in (-1,1): o.append(B((wx+s*.27,y+.26,f-.035),(.11,.44,.05),accent,.018,1))
    # Side window is visible from the elevated camera.
    for s in (-1,1):
        o.append(B((s*(w/2+.008),h*.62,0),(.025,.46,.38),accent,.025,1))
        o.append(B((s*(w/2+.025),h*.62,0),(.012,.34,.25),'Navy',.025,1))
    if kind==1:
        o.append(B((.05,1.58,f-.26),(1.17,.09,.55),'Cream',.035,2))
        o.append(B((.05,1.81,f-.5),(1.12,.33,.065),accent,.04,2))
        o.append(B((-.55,h+.35,.50),(.72,.70,.68),'Cream',.065,2))
        o.append(arch(-.55,h,.38,.55,.15,'Wood'))
    if kind==3:
        o.append(C((.35,h+.12,.35),.48,.24,'Cream',20))
        # Smooth faceted dome, no conical placeholder.
        o.append(blob((.35,h+.28,.35),(.48,.41,.48),'Teal',3))
        o.append(C((.35,h+.72,.35),.027,.13,'Gold',8))
    if kind in (0,2):
        o.append(B((.45,h+.1,.4),(.58,.12,.5),'Stone',.03,1))
        o.append(C((.45,h+.35,.4),.22,.42,'Teal',12))
        o.append(C((.45,h+.57,.4),.23,.055,'Cream',12))
    for k in range(2 if kind!=2 else 3):
        x=-w*.28+k*.4
        o.append(C((x,h+.12,-.2),.11,.24,'Terracotta',8,rt=.14))
        o.append(blob((x,h+.34,-.2),(.20,.21,.18),'Leaf',2))
    finish(o,'house_'+chr(97+kind),ao=.4)

def tree(cypress=False):
    lib.reset(); o=[]
    o.append(C((0,.45,0),.085,.9,'Bark',8,rt=.06))
    if cypress:
        o.append(blob((0,1.18,0),(.31,.95,.30),'LeafDark',2))
        o.append(blob((.025,1.6,0),(.21,.65,.21),'Leaf',2))
    else:
        for c,s,m in [((0,1.3,0),(.56,.60,.5),'Leaf'),((.31,1.14,.07),(.35,.37,.34),'LeafLight'),
                      ((-.28,1.15,-.06),(.37,.39,.38),'LeafDark'),((.03,1.68,.02),(.35,.34,.34),'LeafLight')]:
            o.append(blob(c,s,m,2))
    finish(o,'cypress' if cypress else 'tree_round',ao=.36)

def palm():
    lib.reset(); o=[]
    pts=[(.48*(k/10)**2,3*k/10,0) for k in range(11)]
    for k in range(10):
        a,b=pts[k:k+2]
        o.append(E(a,b,.155-.045*k/10,'BarkLight' if k%2 else 'Bark'))
    top=pts[-1]
    for j in range(9):
        yaw=j*math.tau/9; length=1.55 if j%2 else 1.72
        dx,dz=math.cos(yaw),math.sin(yaw); px,pz=-dz,dx
        vs=[]; fs=[]; n=9
        for k in range(n+1):
            t=k/n; reach=length*t; y=3+.38*math.sin(t*math.pi)-.76*t*t
            width=.29*math.sin(math.pi*t)**.7
            for side in (-1,0,1):
                vs.append((top[0]+dx*reach+side*px*width,y-(.07 if side else 0),dz*reach+side*pz*width))
        for k in range(n):
            for s in (0,1):
                f=[k*3+s,(k+1)*3+s,(k+1)*3+s+1,k*3+s+1]; fs.extend([f,f[::-1]])
        o.append(lib.mesh_from(vs,fs,'LeafDark' if j%3==0 else 'Leaf','frond'))
    for x,z in ((.44,.1),(.61,0),(.40,-.12)):
        o.append(blob((x,2.93,z),(.10,.12,.10),'Wood',1))
    finish(o,'palm',ao=.4)

def wheels(o,x,z,r=.19):
    for s in (-1,1):
        o.append(C((s*x,r,z),r,.16,'Rubber',12,'x'))
        o.append(C((s*(x+.085),r,z),r*.49,.025,'Cream',10,'x'))
        o.append(C((s*(x+.102),r,z),r*.23,.028,'Navy',8,'x'))

def car(name,paint):
    lib.reset(); o=[]
    o.append(B((0,.32,0),(.78,.32,1.7),paint,.10,3))
    o.append(B((0,.57,.06),(.66,.32,.94),paint,.10,3))
    o.append(B((0,.60,-.41),(.54,.19,.025),'Glass',.035,2))
    o.append(B((0,.60,.535),(.54,.19,.025),'Glass',.035,2))
    o.append(B((0,.745,.06),(.54,.045,.62),'Cream',.025,2))
    for s in (-1,1):
        o.append(B((s*.334,.61,.06),(.018,.18,.68),'Glass',.025,2))
        o.append(B((s*.346,.61,.08),(.015,.2,.035),paint))
        o.append(B((s*.245,.34,-.85),(.16,.1,.025),'Lamp',.03,2))
        o.append(B((s*.245,.34,.85),(.16,.075,.025),'Coral',.02,1))
        o.append(B((s*.33,.46,.20),(.025,.025,.12),'Cream',.01,1))
    o.append(B((0,.23,-.86),(.48,.08,.04),'Navy',.02,1))
    for z in (-.54,.54): wheels(o,.37,z,.16)
    finish(o,name,ao=.28)

def tractor():
    lib.reset(); o=[]
    o.append(B((0,.40,-1.50),(.90,.34,1.14),'Navy',.065,2))
    o.append(B((-.1,.85,-1.73),(.70,.70,.72),'Gold',.09,3))
    o.append(B((-.1,1.23,-1.73),(.78,.09,.79),'Cream',.04,2))
    o.append(B((-.1,.99,-2.10),(.57,.32,.025),'Glass',.04,2))
    for x in (-.46,.26): o.append(B((x,1.0,-1.74),(.025,.3,.54),'Glass',.03,2))
    o.append(B((-.1,.61,-2.11),(.53,.10,.035),'Navy',.025,1))
    for x in (-.3,.28): o.append(B((x,.48,-2.09),(.12,.11,.045),'Lamp',.025,2))
    o.append(C((-.10,1.33,-1.73),.065,.10,'Coral',10))
    o.append(C((.34,.99,-1.36),.04,.68,'Navy',8))
    for z in (-1.85,-1.15): wheels(o,.43,z,.20)
    for x in (-.42,.42): o.append(B((x,.58,.43),(.11,.13,2.34),'Navy',.025,1))
    for z in (-.65,.46,1.5):
        o.append(B((0,.62,z),(1.0,.085,.15),'Steel',.02,1))
        for x in (-.43,.43): o.append(B((x,.69,z),(.14,.07,.13),'Gold',.01,1))
    for z in (1.12,1.51): wheels(o,.43,z,.20)
    o.append(B((0,.5,1.64),(1.0,.12,.06),'Cream',.02,1))
    for x in (-.37,.37): o.append(B((x,.51,1.68),(.19,.08,.025),'Coral',.018,1))
    finish(o,'tractor',ao=.3)

def light():
    lib.reset(); o=[]
    o.append(C((0,.15,0),.29,.3,'Stone',12))
    o.append(C((0,.48,0),.12,.66,'Navy',10,rt=.09))
    o.append(C((0,4.4,0),.063,7.2,'Cream',10,rt=.047))
    o.append(B((0,8.10,0),(1.45,.13,.42),'Navy',.045,2))
    for x in (-.5,0,.5):
        o.append(B((x,8.03,-.16),(.37,.19,.28),'Navy',.045,2))
        o.append(B((x,8.025,-.307),(.28,.12,.018),'Lamp',.02,1))
    finish(o,'light_mast',ao=.4)

def landmarks():
    lib.reset(); o=[]
    o.append(C((0,.09,0),.51,.18,'Stone',20))
    # Continuous taper, broad colour bands, open lantern and a copper roof.
    for k in range(6):
        r=.41-k*.026
        o.append(C((0,.18+.70*(k+.5),0),r,.70,'Cream' if k%2==0 else 'Coral',20,rt=r-.026))
    o.append(C((0,4.42,0),.48,.13,'Cream',20))
    o.append(C((0,4.76,0),.30,.55,'Glass',16))
    o.append(C((0,4.77,0),.22,.35,'Lamp',12))
    for i in range(8):
        a=i*math.tau/8; x,z=.30*math.cos(a),.30*math.sin(a)
        o.append(C((x,4.77,z),.018,.63,'Navy',6))
        o.append(C((x*1.4,4.61,z*1.4),.016,.30,'Navy',6))
    o.append(ring((0,4.77,0),.42,.018,'Navy','y',24,4))
    o.append(C((0,5.10,0),.45,.24,'Coral',20,rt=.035))
    o.append(C((0,5.27,0),.027,.14,'Gold',8))
    o.append(B((0,.56,-.414),(.23,.72,.025),'Navy',.03,2))
    o.append(B((0,2.42,-.329),(.14,.25,.022),'Navy',.03,2))
    finish(o,'lighthouse',ao=.4)
    lib.reset(); o=[]
    o.append(C((0,.12,0),.29,.24,'Hull',16,rt=.22))
    o.append(C((0,.34,0),.22,.24,'Hull',16,rt=.12))
    o.append(C((0,.53,0),.06,.25,'Cream',10))
    o.append(C((0,.71,0),.09,.12,'Hull',12))
    o.append(C((0,.79,0),.044,.055,'Lamp',10))
    o.append(ring((0,.23,0),.25,.025,'Cream','y',16,5))
    finish(o,'navigation_buoy',keep={'Hull'},tint=(225,80,83),ao=.2)
    lib.reset(); o=[]
    o.append(B((0,.035,0),(.37,.07,.34),'Navy',.04,2))
    o.append(C((0,.15,0),.12,.23,'Navy',12,rt=.15))
    o.append(B((0,.28,0),(.44,.11,.19),'Navy',.045,3))
    o.append(B((0,.34,0),(.30,.018,.12),'Gold',.01,1))
    finish(o,'mooring_bollard',ao=.15)

if __name__=='__main__':
    requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    groups=set(requested) or {'cargo','ships','cranes','scenery','props'}
    if 'cargo' in groups: container(); container(True)
    if 'ships' in groups:
        for i in range(3): ship(i)
    if 'cranes' in groups: crane(); crane(True)
    if 'scenery' in groups:
        warehouse('warehouse_a','Coral'); warehouse('warehouse_b','Teal')
        for i in range(4): house(i)
        tree(); tree(True); palm(); car('car_red','Coral'); car('car_blue','Blue')
    if 'props' in groups: tractor(); light(); landmarks()
    (ROOT/'model_stats.json').write_text(json.dumps(REPORT,indent=2))
    print('HARBOUR_COLLECTION_COMPLETE',len(REPORT),flush=True)
