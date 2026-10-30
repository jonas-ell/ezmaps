"""Render the delivered face textures on an actual orthographic cube."""
import bpy
from pathlib import Path
from mathutils import Vector
root=Path.cwd()/'Assets/Generated/PixelQuest/cube'
bpy.ops.wm.read_factory_settings(use_empty=True)
materials=[]
for name in ['top','side','bottom']:
    m=bpy.data.materials.new(name); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=1
    tex=m.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(str(root/('px-cube-'+name+'.png')))
    tex.interpolation='Closest'
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    materials.append(m)
# Each face has independent full-square UVs, north of top toward +Y.
faces=[('top',[(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)],0),
 ('front',[(-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1)],1),
 ('right',[(1,-1,-1),(1,1,-1),(1,1,1),(1,-1,1)],1),
 ('back',[(1,1,-1),(-1,1,-1),(-1,1,1),(1,1,1)],1),
 ('left',[(-1,1,-1),(-1,-1,-1),(-1,-1,1),(-1,1,1)],1),
 ('bottom',[(-1,1,-1),(1,1,-1),(1,-1,-1),(-1,-1,-1)],2)]
for name,verts,idx in faces:
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],[(0,1,2,3)]); mesh.update()
    ob=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(ob)
    mesh.materials.append(materials[idx]); uv=mesh.uv_layers.new()
    for i,p in enumerate([(0,0),(1,0),(1,1),(0,1)]): uv.data[i].uv=p
scene=bpy.context.scene; scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=scene.render.resolution_y=1024
scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('World'); scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.20,.28,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.8
scene.view_settings.view_transform='Standard'; scene.view_settings.look='Medium High Contrast'
bpy.ops.object.camera_add(location=(4,-6,5))
cam=bpy.context.object; cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO'; cam.data.ortho_scale=4.7; scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(-3,-4,7))
bpy.context.object.data.energy=650; bpy.context.object.data.size=5
scene.render.image_settings.file_format='PNG'; scene.render.filepath=str(root/'vorschau.png')
bpy.ops.render.render(write_still=True)
