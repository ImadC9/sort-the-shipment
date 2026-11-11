"""Render the actual Harbour Collection meshes; creates an editable diorama.
Run after premium_models.py. Optional -- ships / props / harbour.
"""
import bpy, math, pathlib, sys
from mathutils import Vector
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parent.parent
sys.path.insert(0,str(HERE))
import lib
DEST=ROOT/'art_previews'; DEST.mkdir(exist_ok=True); (DEST/'.gdignore').touch()

def linear(hex):
    vals=[int(hex[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals)

def mat(name,hex,rough=.6):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*linear(hex),1)
    bs.inputs['Roughness'].default_value=rough
    return m

def cube(c,size,hex,bevel=.08,name='display_base'):
    ob=lib.box(c,size,name,bevel=bevel,segments=3)
    ob.data.materials.clear(); ob.data.materials.append(mat(name,hex))
    return ob

def asset(name,at=(0,0,0),yaw=0,scale=1,tint=None):
    path=ROOT/'art_source'/(name+'.blend')
    with bpy.data.libraries.load(str(path),link=False) as (src,dst): dst.objects=[name]
    ob=dst.objects[0]; bpy.context.collection.objects.link(ob)
    ob.location=lib.g2b(*at); ob.rotation_euler.z=math.radians(yaw); ob.scale=(scale,)*3
    if tint:
        for i,m in enumerate(ob.data.materials):
            if m.name.startswith(('Hull','Funnel','Deck','Body')):
                nm=m.copy(); ob.data.materials[i]=nm
                mix=next(n for n in nm.node_tree.nodes if n.type=='MIX_RGB')
                col=linear(tint)
                if m.name.startswith('Deck'): col=tuple(v*.20+.72 for v in col)
                mix.inputs[2].default_value=(*col,1)
    return ob

def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    lib._mats.clear()
    scene=bpy.context.scene; scene.render.engine='CYCLES'
    scene.cycles.samples=48; scene.cycles.use_denoising=True
    # GPU use when available; deterministic CPU fallback.
    try:
        prefs=bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type='CUDA'; prefs.get_devices()
        for d in prefs.devices: d.use=d.type=='CUDA'
        if any(d.type=='CUDA' for d in prefs.devices): scene.cycles.device='GPU'
    except Exception: pass
    world=bpy.data.worlds.new('Soft studio'); world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.64,.77,.85,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.45
    scene.world=world
    for name,loc,power,size,col in [('Key',(-8,13,-9),2600,10,'FFF0D9'),('Fill',(11,8,-1),1900,9,'CEEDFF'),('Rim',(-3,12,10),2400,8,'FFFFFF')]:
        data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=linear(col)
        ob=bpy.data.objects.new(name,data); scene.collection.objects.link(ob); ob.location=lib.g2b(*loc)
        ob.rotation_euler=(lib.g2b(0,0,0)-ob.location).to_track_quat('-Z','Y').to_euler()
    scene.view_settings.view_transform='AgX'
    scene.view_settings.exposure=.35
    scene.render.resolution_x=1800; scene.render.resolution_y=1400; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.film_transparent=False
    scene.render.image_settings.color_mode='RGB'
    scene.render.use_file_extension=True
    scene.render.fps=30
    return scene

def camera(at,target,ortho):
    data=bpy.data.cameras.new('Collection camera'); ob=bpy.data.objects.new('Collection camera',data)
    bpy.context.collection.objects.link(ob); ob.location=lib.g2b(*at)
    ob.rotation_euler=(lib.g2b(*target)-ob.location).to_track_quat('-Z','Y').to_euler()
    data.type='ORTHO'; data.ortho_scale=ortho; data.lens=50; bpy.context.scene.camera=ob

def render(name):
    bpy.context.scene.render.filepath=str(DEST/(name+'.png'))
    bpy.ops.wm.save_as_mainfile(filepath=str(DEST/(name+'.blend')),compress=True)
    bpy.ops.render.render(write_still=True)
    print('RENDER_COMPLETE',name,flush=True)

def harbour():
    setup()
    # The stage is presentation only; every featured prop is an exported game model.
    cube((0,-.58,0),(22,.8,20),'164758',.6,'diorama_water')
    cube((0,-.10,3.6),(19,.74,11.0),'CBB996',.20,'quay_sides')
    cube((0,.30,3.6),(19,.10,11.0),'EADCC2',.06,'quay_top')
    cube((0,.38,-1.88),(19,.08,.15),'FAEBC8',.025,'quay_edge')
    for x in range(-9,10,2):
        cube((x,.38,-1.88),(.65,.085,.16),'233E50',.012,'edge_mark')
    for x in (-6.7,-1,4.7):
        cube((x,.37,3.0),(.04,.025,7.2),'FAF2D6',.005,'bay_paint')
    asset('crane',(-6.3,.36,1.1),scale=.85)
    asset('ship_feeder',(1.4,-.15,-4.3),yaw=0,tint='E85957')
    asset('ship_tanker',(5.7,-.15,-7.8),yaw=-12,scale=.8,tint='3D9CAF')
    for x,z,cols in [(-3.3,1.0,['3C8FAB','E8B44B']),(-1.9,1.0,['E56C54','E8B44B','408FA6']),
                       (-.5,1.0,['427C9C','49A78D']),(.9,1.0,['E56C54','4A9AB0'])]:
        for k,col in enumerate(cols): asset('container',(x,.36+k*.8,z),tint=col)
    for x,col in [(.25,'E85957'),(1.35,'E85957')]: asset('container',(x,.85,-4.3),tint=col)
    asset('warehouse_a',(-2,.36,6.0),scale=.85)
    asset('warehouse_b',(4.5,.36,6.0),scale=.85)
    asset('tractor',(5.8,.36,1.5),yaw=10)
    asset('container',(5.8,1.06,1.94),yaw=10,tint='438FAD')
    for name,at in [('house_b',(-7.6,.36,7.1)),('house_a',(-7.7,.36,4.5)),('house_c',(8,.36,6.7))]:
        asset(name,at,scale=.8)
    for at in [(-8.2,.36,1.7),(8.2,.36,4),(-5.7,.36,7.7)]: asset('palm',at,scale=.95)
    for at in [(-7,.36,5.9),(7.5,.36,7.9),(8.2,.36,1.8)]: asset('tree_round',at)
    asset('car_blue',(7.5,.36,4.5),yaw=15)
    asset('light_mast',(7.2,.36,-.7),scale=.70)
    cube((-8.3,-.05,-3.8),(2.0,.4,2.0),'CBB996',.12,'lighthouse_island')
    asset('lighthouse',(-8.3,.15,-3.8),scale=.64)
    asset('navigation_buoy',(-5,-.15,-7.2),tint='E56C54')
    for x in (-5,-2,1,4,7): asset('mooring_bollard',(x,.39,-1.6))
    # Deliberately low-cost, opaque foam accents for the studio water.
    for x,z,l in [(-1,-5.8,1.5),(1,-6.2,.9),(3,-5.9,1.7),(6,-9.6,1.1),(-7,-6,2),(-2,-8,1.3),(-6,-8,1.0)]:
        cube((x,-.173,z),(l,.018,.055),'72B6BC',.02,'water_ripple')
    camera((20,21,-28),(0,1.3,.2),29)
    render('Harbour_Collection')

def ships():
    s=setup(); s.render.resolution_x=1800; s.render.resolution_y=1150
    cube((0,-.34,0),(20,.5,12),'D9E4DF',.3,'studio_plinth')
    for i,name in enumerate(['ship_feeder','ship_tanker','ship_coaster']):
        asset(name,((i-1)*6.1,.31,0),yaw=18)
    camera((15,15,-23),(0,1.2,0),21.5)
    render('Ships')

def props():
    s=setup(); s.render.resolution_x=1800; s.render.resolution_y=1250
    cube((0,-.20,0),(22,.35,17),'DFE7DF',.3,'studio_plinth')
    asset('warehouse_a',(-4,.01,4),scale=.75)
    asset('warehouse_b',(3,.01,4),scale=.75)
    for i,n in enumerate(['house_a','house_b','house_c','house_d']): asset(n,(-6+i*3.7,.01,-.4),scale=.85)
    for x,c in [(-6,'E85957'),(-4.7,'438FAD'),(-3.4,'E8B44B')]: asset('container',(x,.01,-4),tint=c)
    asset('tractor',(0,.01,-4),yaw=25)
    asset('car_red',(3,.01,-4),yaw=25); asset('car_blue',(4.5,.01,-4),yaw=25)
    asset('palm',(7,.01,-3)); asset('cypress',(7,.01,.2)); asset('tree_round',(8.5,.01,1.4))
    asset('lighthouse',(-9,.01,1),scale=.7)
    camera((16,20,-27),(0,1,0),24)
    render('Buildings_Cargo_and_Props')

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['harbour','ships','props']
    if 'harbour' in args: harbour()
    if 'ships' in args: ships()
    if 'props' in args: props()
