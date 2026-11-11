"""Solstice Harbour: sculpted geometry and a colour-managed mobile asset set.

Blender 5.2: blender -b --python tools/blender/solstice_models.py
The companion Godot material pipeline is part of this collection.
"""
import bpy,bmesh,sys,math,json,pathlib
HERE=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import premium_models as P
import lib
ROOT=HERE.parent.parent
P.PALETTE.update({
 'Cream':(243,229,203),'White':(255,246,225),'Navy':(40,73,91),
 'Glass':(53,107,121),'Glint':(131,206,208),'Teal':(50,133,141),
 'Coral':(244,126,101),'Gold':(221,182,94),'Steel':(139,170,177),
 'Dark':(42,64,76),'Rubber':(46,65,74),'Sand':(202,179,145),
 'Stone':(219,206,182),'Roof':(87,123,135),'Terracotta':(215,132,101),
 'Leaf':(80,153,119),'LeafLight':(128,188,132),'LeafDark':(49,121,105),
 'HullWhite':(243,229,203),'BootTop':(40,73,91),'Bottom':(135,78,68),
})
REPORT=[]
B,C,E=P.B,P.C,P.E

def lin(rgb):
 return tuple(x/255/12.92 if x/255<=.04045 else ((x/255+.055)/1.055)**2.4 for x in rgb)

def finish(parts,name,keep=None,palette=None,ao=.45,tint=(61,143,232),gray=None,paint=False):
 keep=set() if keep is None else set(keep)
 ob=lib.join(parts,name)
 bm=bmesh.new();bm.from_mesh(ob.data)
 loose=[v for v in bm.verts if not v.link_faces]
 if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
 bm.to_mesh(ob.data);bm.free()
 lib.auto_smooth(ob,48)
 # Weighted normals keep large planes calm and bevel highlights continuous.
 bpy.context.view_layer.objects.active=ob
 mod=ob.modifiers.new('Sculpted weighted normals','WEIGHTED_NORMAL')
 mod.keep_sharp=True;mod.weight=60;mod.mode='FACE_AREA_WITH_ANGLE'
 bpy.ops.object.modifier_apply(modifier=mod.name)
 lib.bake_ao(ob,ground=not name.startswith('ship'),distance=ao,samples=24,max_len=0)
 attr=ob.data.color_attributes['AO']
 for d in attr.data:
  f=.34+.66*d.color[0];d.color=(f,f,f,1)
 if paint:
  for poly in ob.data.polygons:
   n=ob.data.materials[poly.material_index].name
   fixed=n in {'Casting','Hardware','Sticker'}
   rgb=lin({'Casting':(237,225,197),'Hardware':(45,67,80),'Sticker':(249,238,213)}.get(n,(255,255,255)))
   shade={'Frame':.87,'Door':.96}.get(n,1.)
   for li in poly.loop_indices:
    a=attr.data[li].color[0]
    attr.data[li].color=(*[a*c*shade for c in rgb],0. if fixed else 1.)
   poly.material_index=0
  ob.data.materials.clear();ob.data.materials.append(lib.mat('Body'));keep={'Body'}
 elif gray:
  for poly in ob.data.polygons:
   factor=gray.get(ob.data.materials[poly.material_index].name,1.)
   for li in poly.loop_indices:
    a=attr.data[li].color[0]*factor;attr.data[li].color=(a,a,a,1)
   poly.material_index=0
  ob.data.materials.clear();ob.data.materials.append(lib.mat('Body'));keep={'Body'}
 else:lib.collapse_fixed_materials(ob,keep,palette or P.PALETTE)
 for m in ob.data.materials:
  m.use_nodes=True
  bs=m.node_tree.nodes.get('Principled BSDF')
  colour=tint if m.name in {'Hull','Funnel','Body'} else (255,255,255)
  if m.name=='Hull':colour=tuple(round(v*.94) for v in tint)
  if m.name=='Deck':colour=tuple(round(v*.78+c*.22) for v,c in zip(tint,(237,240,227)))
  if m.name=='Glass':colour=P.PALETTE['Glass']
  if bs:
   bs.inputs['Base Color'].default_value=(*lin(colour),1)
   bs.inputs['Roughness'].default_value=.31 if m.name=='Glass' else .48
 lib.export(ob,str(P.OUT/(name+'.glb')))
 # Editable Blender colour treatment uses the same authored data and tint masks.
 for m in ob.data.materials:
  m.use_nodes=True; nt=m.node_tree;nt.nodes.clear()
  bs=nt.nodes.new('ShaderNodeBsdfPrincipled');bs.inputs['Roughness'].default_value=.43
  vc=nt.nodes.new('ShaderNodeVertexColor');vc.layer_name='AO'
  mult=nt.nodes.new('ShaderNodeMixRGB');mult.blend_type='MULTIPLY';mult.inputs[0].default_value=1
  col=tint if m.name in {'Hull','Funnel','Body'} else (255,255,255)
  if m.name=='Hull':col=tuple(round(v*.94) for v in tint)
  if m.name=='Deck':col=tuple(round(v*.78+c*.22) for v,c in zip(tint,(237,240,227)))
  if m.name=='Glass':col=P.PALETTE['Glass'];bs.inputs['Roughness'].default_value=.27
  mult.inputs[2].default_value=(*lin(col),1)
  nt.links.new(vc.outputs['Color'],mult.inputs[1])
  if paint:
   mask=nt.nodes.new('ShaderNodeMixRGB');mask.inputs[1].default_value=(1,1,1,1);mask.inputs[2].default_value=(*lin(col),1)
   nt.links.new(vc.outputs['Alpha'],mask.inputs[0]);nt.links.new(mask.outputs[0],mult.inputs[2])
  nt.links.new(mult.outputs[0],bs.inputs['Base Color'])
  out=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(bs.outputs[0],out.inputs[0])
 bpy.ops.wm.save_as_mainfile(filepath=str(P.EDIT/(name+'.blend')),compress=True)
 ob.data.calc_loop_triangles()
 pts=[(v.co.x,v.co.z,-v.co.y) for v in ob.data.vertices]
 REPORT.append(dict(name=name,triangles=len(ob.data.loop_triangles),surfaces=len(ob.data.materials),
   bounds_min=[round(min(v[i] for v in pts),5) for i in range(3)],
   bounds_max=[round(max(v[i] for v in pts),5) for i in range(3)],bytes=(P.OUT/(name+'.glb')).stat().st_size))
 print('SOLSTICE_MODEL',name,REPORT[-1]['triangles'],flush=True)

def roundbox(c,s,m,bevel=0.,seg=2):
 # Existing accessory proportions stay fixed; soften major silhouette edges.
 if min(s)>.24:bevel=max(bevel,min(s)*.08);seg=max(seg,3)
 return lib.box(c,s,m,bevel=bevel,segments=seg)

def container(lod=False):
 lib.reset();o=[]
 o.append(B((0,.4,0),(.95,.74,1.84),'Body',.035,2 if lod else 3))
 for s in (-1,1):
  for k in range(5 if lod else 7):
   z=-.73+k*1.46/(4 if lod else 6)
   o.append(B((s*.476,.4,z),(.030,.59,.054),'Body',0 if lod else .012,2))
  for y in (.045,.755):o.append(B((s*.46,y,0),(.080,.09,1.9),'Frame',0 if lod else .016,2))
 for s in (-1,1):
  for y in (.045,.755):o.append(B((0,y,s*.91),(.84,.09,.08),'Frame',0 if lod else .013,2))
  for x in (-.455,.455):
   o.append(B((x,.4,s*.905),(.09,.80,.09),'Frame',0 if lod else .016,2))
   for y in (.048,.752):
    o.append(B((x,y,s*.902),(.09,.096,.096),'Casting',0 if lod else .013,2))
 for s in (-1,1):o.append(B((s*.212,.40,-.922),(.408,.6,.025),'Door',0 if lod else .020,2))
 for x in (-.27,.27):
  o.append(C((x,.4,-.94),.010,.54,'Hardware',6))
  if not lod:
   for y in (.18,.62):o.append(B((x,y,-.934),(.046,.038,.026),'Hardware',.008,1))
   o.append(B((x+.031,.34,-.94),(.07,.025,.020),'Hardware',.006,1))
 if not lod:
  for z in (-.71,-.53,.48,.68):o.append(B((0,.785,z),(.80,.018,.033),'Body',.006,1))
  # Small neutral inspection plates add detail without competing with the symbols.
  for s in (-1,1):o.append(B((s*.492,.60,.66),(.009,.12,.21),'Sticker',.003,1))
 finish(o,'container_lod' if lod else 'container',ao=.20,paint=True)

def hull(kind):
 xs=[-2.64,-2.56,-2.42,-2.18,-1.8,-1.4,-.7,0,.7,1.35,1.62,1.84,2.05,2.25,2.43,2.55,2.60]
 widths=[.48,.82,1.03,1.14,1.18,1.18,1.18,1.18,1.18,1.18,1.13,1.04,.88,.67,.43,.21,.025]
 if kind==1:widths=[min(1.19,w*1.025) for w in widths]
 levels=[(-.64,.68),(-.48,.83),(-.27,.95),(-.03,1),(.08,1),(.77,1),(.86,.99),(.95,.975)]
 verts=[];faces=[];mats=[]
 for y,fac in levels:
  for s in (-1,1):
   for x,w in zip(xs,widths):
    bx=x
    if x>1.6:bx-=max(0,.95-y)*(.14 if kind!=2 else .05)*(x-1.6)
    verts.append((bx,y,s*w*fac))
 n=len(xs);r=2*n
 for j in range(len(levels)-1):
  mid=(levels[j][0]+levels[j+1][0])/2
  m='Bottom' if mid<-.03 else ('BootTop' if mid<.08 else ('HullWhite' if mid>.77 else 'Hull'))
  for side in range(2):
   for i in range(n-1):
    a=j*r+side*n+i;b=(j+1)*r+side*n+i
    f=[a,a+1,b+1,b]
    faces.append(f);mats.append(m)
  for i in (0,n-1):
   faces.append([j*r+i,(j+1)*r+i,(j+1)*r+n+i,j*r+n+i]);mats.append(m)
 for j,m in [(0,'Bottom'),(len(levels)-1,'Deck')]:
  # Convex planar cap as a single polygon, with its normal explicitly oriented.
  f=[j*r+i for i in range(n)]+[j*r+n+i for i in reversed(range(n))]
  faces.append(f);mats.append(m)
 parts=[]
 for m in set(mats):
  fs=[f for f,mm in zip(faces,mats) if mm==m]
  def want(c):
   if m=='Deck':return (0,1,0)
   if m=='Bottom' and c[1]<-.62:return (0,-1,0)
   return (c[0]*.05,(c[1]-.3)*.15,c[2])
  parts.append(lib.mesh_from(verts,fs,m,'sculpted_hull',outward=want))
 return parts

def ship(kind):
 lib.reset();o=hull(kind)
 for x in (-1.15,-.05,1.05):
  o.append(B((x,.973,0),(1.06,.045,1.98),'Navy',.017,2))
  o.append(B((x,.994,0),(1.0,.012,1.89),'Deck',.005,1))
 for s in (-1,1):
  # A smooth raised rubbing rail gives the entire silhouette a deliberate edge.
  o.append(B((-.06,.79,s*1.184),(3.45,.09,.065),'Cream',.026,3))
  xs=[-1.65,-1.10,-.55,0,.55,1.10,1.60,1.88,2.10,2.30,2.45]
  prev=None
  for x in xs:
   w=1.13 if x<1.60 else max(.2,1.13-(x-1.60)*1.02)
   p=(x,1.18,s*w)
   o.append(C((x,1.085,s*w),.018,.19,'Cream',6))
   if prev:o.append(E(prev,p,.032,'Cream'))
   prev=p
  for x in (-1.4,.58,1.34):
   o.append(B((x,.52,s*1.192),(.12,.28,.12),'Rubber',.05,3))
  o.append(P.ring((-2.15,1.58,s*1.04),.105,.026,'Coral','z',14,6))
 # Three wheelhouse silhouettes, with continuous wraparound glazing.
 tiers=[
  [(1.29,.68,1.94,.80),(1.89,.52,1.78,.74),(2.48,.56,2.18,.75)],
  [(1.40,.90,2.00,.80),(2.20,.67,2.21,.75)],
  [(1.46,1.02,1.97,.80),(2.31,.65,2.28,.77)]
 ][kind]
 for i,(cy,h,d,w) in enumerate(tiers):
  cx=-2.19
  o.append(B((cx,cy,0),(w,h,d),'Cream',.12,4))
  gh=.20 if i<len(tiers)-1 else .27
  o.append(B((cx,cy+.06,0),(w+.018,gh,d+.018),'Glass',.072,4))
  # Glazing mullions and a fine reflection strip, legible from front and side.
  for s in (-1,1):
   o.append(B((cx,cy+.12,s*(d/2+.013)),(w-.13,.024,.008),'Glint',.003,1))
   o.append(B((cx,cy+.06,s*(d/2+.016)),(.025,gh+.03,.012),'Cream',.004,1))
  for z in (-d*.24,d*.24):o.append(B((cx+w/2+.018,cy+.06,z),(.015,gh+.025,.038),'Cream',.005,1))
  roofy=cy+h/2+.028
  o.append(B((cx,roofy,0),(w+.08,.10,d+.12),'Cream',.038,3))
  o.append(B((cx,roofy+.053,0),(w-.03,.024,d-.04),'Teal',.010,2))
 # Tiny pilothouse doors and capsule lifeboats make the aft deck feel inhabited.
 for s in (-1,1):
  o.append(B((-2.15,1.71,s*1.02),(.64,.075,.32),'Cream',.025,2))
  o.append(B((-2.15,1.82,s*1.04),(.52,.19,.24),'Coral',.095,4))
  o.append(B((-2.15,1.90,s*1.04),(.25,.05,.14),'Glass',.024,2))
 for z in (-.53,.53):
  o.append(C((1.91,1.03,z),.045,.14,'Navy',8))
  o.append(B((1.91,1.10,z),(.18,.045,.075),'Navy',.018,2))
 o.append(B((2.14,1.05,0),(.29,.14,.33),'Navy',.055,3))
 o.append(C((2.14,1.49,0),.027,.80,'Cream',8))
 o.append(C((2.14,1.91,0),.048,.065,'Gold',10))
 ft=[(-2.43,3.52,0),(-2.45,3.65,.3),(-2.45,3.70,-.55)][kind]
 fx,fy,fz=ft
 if kind==1:
  for z in (-.3,.3):
   o.append(C((fx,fy-.65,z),.105,1.2,'Funnel',16))
   o.append(C((fx,fy-.045,z),.115,.09,'Navy',16))
   o.append(C((fx,fy-.24,z),.108,.09,'Cream',16))
 else:
  o.append(B((fx,fy-.75,fz),(.31,1.40,.35),'Funnel',.09,4))
  o.append(B((fx,fy-.05,fz),(.34,.10,.38),'Navy',.035,3))
  o.append(B((fx,fy-.29,fz),(.32,.085,.36),'Cream',.035,3))
 rz=.49 if kind==2 else -.59
 o.append(C((-2.11,2.98,rz),.024,.61,'Cream',8))
 o.append(B((-2.11,3.26,rz),(.075,.065,.52),'Cream',.025,3))
 o.append(P.blob((-2.13,2.90,-rz),(.115,.13,.115),'Cream',2))
 if kind==2:
  o.append(B((-2.66,.99,0),(.08,.56,1.43),'Navy',.03,2))
  for z in (-.48,0,.48):o.append(B((-2.706,1.0,z),(.014,.30,.055),'Gold'))
 if kind==1:
  for z in (-1.015,1.015):o.append(C((-.10,1.07,z),.027,3.30,'Gold',8,'x'))
 finish(o,['ship_feeder','ship_tanker','ship_coaster'][kind],keep={'Hull','Funnel','Deck','Glass'},ao=.55,
  tint=[(239,75,92),(61,143,232),(255,197,61)][kind])

def palm():
 lib.reset();o=[]
 pts=[(.43*(k/9)**2,3*k/9,0) for k in range(10)]
 for k in range(9):
  o.append(E(pts[k],pts[k+1],.15-.045*k/9,'Bark' if k%2 else 'BarkLight'))
 top=pts[-1]
 for j in range(9):
  a=j*math.tau/9;dx,dz=math.cos(a),math.sin(a);px,pz=-dz,dx
  length=1.58 if j%2 else 1.72;n=7;vs=[];fs=[]
  # Solid thin leaves, not coincident reverse faces discarded by the exporter.
  for lower in (False,True):
   for k in range(n+1):
    t=k/n; y=3+.39*math.sin(t*math.pi)-.62*t*t-(.018 if lower else 0)
    w=.32*math.sin(math.pi*t)**.65+.006
    for s in (-1,0,1):vs.append((top[0]+dx*length*t+s*px*w,y-(.055 if s else 0),dz*length*t+s*pz*w))
  off=(n+1)*3
  for k in range(n):
   for s in (0,1):
    f=[k*3+s,(k+1)*3+s,(k+1)*3+s+1,k*3+s+1]
    fs.append(f);fs.append([v+off for v in f[::-1]])
   for s in (0,2):
    v=k*3+s;w=(k+1)*3+s;fs.append([v,w,w+off,v+off])
  for k in (0,n):
   for s in (0,1):v=k*3+s;fs.append([v,v+1,v+1+off,v+off])
  leaf=lib.mesh_from(vs,fs,'LeafLight' if j%3 else 'Leaf','solid_palm_leaf')
  # All normals outside for a closed blade.
  bm=bmesh.new();bm.from_mesh(leaf.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(leaf.data);bm.free()
  o.append(leaf)
 for x,z in ((.43,.11),(.58,-.03),(.33,-.11)):o.append(P.blob((x,2.91,z),(.10,.12,.10),'Wood',2))
 finish(o,'palm',ao=.35)

def crane(gold=False):
 old=P.PALETTE.copy()
 P.PALETTE['Teal']=(244,126,101) if not gold else (40,73,91)
 # Portal beams are deliberately heavier, while truss detail stays economical.
 original_e=P.E
 def strong(a,b,t,m):return E(a,b,t*1.25 if m=='Teal' and t>=.17 else t,m)
 P.E=strong
 P.crane(gold)
 P.E=original_e;P.PALETTE.clear();P.PALETTE.update(old)

if __name__=='__main__':
 P.finish=finish;P.B=roundbox
 container();container(True)
 for i in range(3):ship(i)
 crane();crane(True)
 P.warehouse('warehouse_a','Coral');P.warehouse('warehouse_b','Teal')
 for i in range(4):P.house(i)
 P.tree();P.tree(True);palm()
 P.car('car_red','Coral');P.car('car_blue','Blue');P.tractor();P.light();P.landmarks()
 (ROOT/'model_stats.json').write_text(json.dumps(REPORT,indent=2))
 print('SOLSTICE_COMPLETE',len(REPORT),flush=True)
