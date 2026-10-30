"""Run with Blender --background --python tools/prepare_villager_house.py."""
import bpy, json, math
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path.cwd()
OUT=ROOT/'Assets/Generated/PixelQuest/3d'
WORK=ROOT/'tmp/villager-house/export'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'vorschau').mkdir(exist_ok=True)
WORK.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'tmp/villager-house/source/source/villahouse.gltf'))
for ob in bpy.data.objects:
    ob.animation_data_clear()
for action in list(bpy.data.actions): bpy.data.actions.remove(action,do_unlink=True)
bpy.context.view_layer.update()
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
# Bake static world transforms, with the entrance facing Blender +Y / USD -Z.
for o in objects:
    world=o.matrix_world.copy()
    o.parent=None
    o.matrix_world=Matrix.Identity(4)
    o.data.transform(world)
coords=[v.co for o in objects for v in o.data.vertices]
lo=Vector([min(v[i] for v in coords) for i in range(3)])
hi=Vector([max(v[i] for v in coords) for i in range(3)])
center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
scale=1/max(hi.x-lo.x,hi.y-lo.y)
# Independent horizontal normalization gives the requested exact 1 x 1 footprint.
for o in objects:
    for v in o.data.vertices:
        q=v.co-center
        v.co=(q.x/(hi.x-lo.x),q.y/(hi.y-lo.y),q.z*scale)
    for p in o.data.polygons: p.use_smooth=False
materials=list(bpy.data.materials)
originals={}
for i,m in enumerate(materials):
    m.name='material_%02d'%i
    for node in m.node_tree.nodes:
        if node.type=='TEX_IMAGE' and node.image:
            node.interpolation='Closest'
            originals[i]=(node.image,list(node.image.pixels[:]))
    m.blend_method='CLIP'
    m.alpha_threshold=0.05

geometry=[]
triangles=0
for o in objects:
    mesh=o.data
    mesh.calc_loop_triangles()
    for slot,mat in enumerate(mesh.materials):
        ts=[t for t in mesh.loop_triangles if t.material_index==slot]
        if not ts: continue
        points=[]; uv=[]
        for t in ts:
            for vi,li in zip(t.vertices,t.loops):
                v=mesh.vertices[vi].co
                points.append([v.x,v.z,-v.y])
                uv.append(list(mesh.uv_layers.active.data[li].uv))
        geometry.append(dict(points=points,uv=uv,material=materials.index(mat)))
        triangles+=len(ts)
assert triangles<5000
(WORK/'geometry.json').write_text(json.dumps(geometry))

scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.eevee.use_gtao=False
scene.render.resolution_x=scene.render.resolution_y=512
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=True
scene.view_settings.view_transform='Standard'
scene.view_settings.look='Medium High Contrast'
scene.world=bpy.data.worlds.new('World')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(0.65,0.65,0.65,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=0.8
height=(hi.z-lo.z)*scale
target=Vector((0,0,height/2))
bpy.ops.object.camera_add(location=(2.5,3.5,2.6))
camera=bpy.context.object
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'; camera.data.ortho_scale=max(1.7,height*1.65)
scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(2,1,4))
bpy.context.object.data.energy=350
bpy.context.object.data.size=5

for variant in ['oak','spruce','birch','sand']:
    folder=WORK/variant; folder.mkdir(exist_ok=True)
    for i,(im,original) in originals.items():
        pix=original.copy()
        for p in range(0,len(pix),4):
            r,g,b=pix[p:p+3]
            wood=r>g*1.08 and g>b*1.12
            if wood and variant!='oak':
                if variant=='spruce': rgb=(r*.52,g*.48,b*.43)
                elif variant=='birch': rgb=(min(1,r*.65+.38),min(1,g*.65+.36),min(1,b*.65+.28))
                else: rgb=(min(1,r*.55+.42),min(1,g*.5+.34),min(1,b*.45+.21))
                pix[p:p+3]=rgb
        variant_image=bpy.data.images.new(variant+'_%02d'%i,width=im.size[0],height=im.size[1],alpha=True)
        variant_image.pixels[:]=pix
        variant_image.update()
        variant_image.filepath_raw=str(folder/('texture_%02d.png'%i)); variant_image.file_format='PNG'; variant_image.save()
        for node in materials[i].node_tree.nodes:
            if node.type=='TEX_IMAGE': node.image=variant_image
    scene.render.filepath=str(OUT/'vorschau'/('villager-house-'+variant+'.png'))
    bpy.ops.render.render(write_still=True)
report=dict(triangles=triangles,animations=0,footprint=[1,1],height=height,up='+Y',front='-Z',origin='bottom center',source_bounds=[list(lo),list(hi)])
(OUT/'validation.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'house.blend'))
print('HOUSE_REPORT',json.dumps(report))
