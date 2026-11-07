"""Validate the saved anatomical character and actual GLB import. Failures exit nonzero."""
import bpy,json,struct,sys,traceback
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent

def coords(o):
 deps=bpy.context.evaluated_depsgraph_get();ev=o.evaluated_get(deps);mesh=ev.to_mesh()
 points=[ev.matrix_world@v.co for v in mesh.vertices];ev.to_mesh_clear();return points

def check():
 report=json.loads((P/'asset_report.json').read_text())
 bpy.ops.wm.open_mainfile(filepath=str(P/'resident_01.blend'))
 asset=bpy.data.collections['CHARACTER • Resident 01'];rig=bpy.data.objects['Resident01_RIG']
 scene=bpy.context.scene
 assert scene.frame_current==2,('Saved scene should open in slouched inspection pose',scene.frame_current)
 assert rig.animation_data and rig.animation_data.action,'Missing inspection action'
 scene.frame_set(1);bpy.context.view_layer.update()
 assert all(abs(pb.rotation_quaternion.angle)<.0001 for pb in rig.pose.bones),'Neutral frame contains nonidentity pose rotations'
 inspection_meshes=[o for o in asset.all_objects if o.type=='MESH'];neutral_coords={o.name:coords(o) for o in inspection_meshes}
 scene.frame_set(2);bpy.context.view_layer.update()
 slouch_delta={o.name:max((a-b).length for a,b in zip(coords(o),neutral_coords[o.name])) for o in inspection_meshes}
 assert slouch_delta['Resident01_BODY']>.05,slouch_delta
 assert slouch_delta['Workshirt, belt and denim trousers']>.05,slouch_delta
 scene.frame_set(1);bpy.context.view_layer.update()
 print('PASS: saved frame 2 is visibly slouched; frame 1 resets the rig to neutral.',json.dumps(slouch_delta))
 expected_weather={'Resident01_BODY':'skin','Workshirt, belt and denim trousers':'clothes','Worn practical shoes':'shoes','Short textured hair':'hair'}
 for objname,label in expected_weather.items():
  mat=bpy.data.objects[objname].material_slots[0].material
  imgs=[n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
  assert any(im.name.startswith('weathered_'+label) and im.packed_file for im in imgs),(objname,'Missing packed weathered map')
 print('PASS: skin, clothing, shoes and hair use packed weathered image maps.')
 meshes=[o for o in asset.all_objects if o.type=='MESH'];assert len(meshes)==report['mesh_objects']==5
 assert len(rig.data.bones)==report['bones']
 bones=set(rig.data.bones.keys())
 for o in meshes:
  assert o.data.uv_layers.active is not None,(o.name,'No UV map')
  assert any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers),(o.name,'No rig modifier')
  deform={g.index for g in o.vertex_groups if g.name in bones}
  for v in o.data.vertices:
   total=sum(g.weight for g in v.groups if g.group in deform)
   assert abs(total-1)<.005,(o.name,v.index,'Weight sum',total)
  for slot in o.material_slots:
   m=slot.material;images=[n.image for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
   assert images,(o.name,'No image textures')
   assert all(im.packed_file for im in images),(o.name,'Unpacked image')
 print('PASS: five textured UV-mapped meshes, packed images, normalized skeletal weights, one shared armature.')
 body=bpy.data.objects['Resident01_BODY'];before={o.name:coords(o) for o in meshes}
 # The body mask must hide the clothed trunk and legs, rather than exporting naked skin beneath it.
 torso=[v for v in before[body.name] if .25<v.z<1.37 and abs(v.x)<.19]
 assert not torso,('Covered skin still visible',len(torso))
 assert len(before[body.name])<len(body.data.vertices)*4,('Body mask not applied?',len(before[body.name]))
 print('PASS: covered trunk/leg skin is masked; visible body consists of exposed anatomy.')
 pb=rig.pose.bones['lowerarm01.L'];pb.rotation_mode='XYZ';pb.rotation_euler.x=.4;bpy.context.view_layer.update()
 deltas={}
 for o in meshes:
  after=coords(o);assert len(after)==len(before[o.name]);deltas[o.name]=max((a-b).length for a,b in zip(after,before[o.name]))
 assert deltas[body.name]>.01,deltas
 assert deltas['Workshirt, belt and denim trousers']>.01,deltas
 assert deltas['Anatomical eyes']<.001,deltas
 pb.rotation_euler=(0,0,0);bpy.context.view_layer.update()
 print('PASS: forearm test deforms exposed anatomy and clothing while eyes remain stationary.',json.dumps(deltas))
 raw=(P/'resident_01.glb').read_bytes();magic,version,length=struct.unpack_from('<4sII',raw)
 assert magic==b'glTF' and version==2 and length==len(raw)
 n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n])
 assert len(g['skins'])==1 and len(g['skins'][0]['joints'])==report['bones']
 assert len(g['meshes'])==5 and len(g['images'])>=8
 assert all(im.get('bufferView') is not None and not im.get('uri') for im in g['images'])
 assert not g.get('cameras') and not g.get('animations')
 for m in g['meshes']:
  for q in m['primitives']:
   assert all(a in q['attributes'] for a in ['POSITION','NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0'])
 for m in g['materials']:
  assert 'baseColorTexture' in m['pbrMetallicRoughness'],m.get('name')
 print('PASS: GLB has five skinned textured meshes, embedded image maps, UVs and no animation/camera payload.')
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(P/'resident_01.glb'))
 rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE'];assert len(rigs)==1
 imported=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
 assert len(imported)==5
 assert not any(o.type in {'CAMERA','LIGHT'} for o in bpy.context.scene.objects)
 for o in imported:
  assert len(o.data.vertices)>0 and o.data.uv_layers.active
 imported_body=bpy.data.objects['Resident01_BODY']
 exported_torso=[v for v in coords(imported_body) if .25<v.z<1.37 and abs(v.x)<.19]
 assert not exported_torso,('GLB did not preserve covered body mask',len(exported_torso))
 print('PASS: actual Blender GLB reimport retains all five skinned meshes, skeleton and covered-body mask; excludes studio.')
 print('CHARACTER_VALIDATION_COMPLETE',json.dumps(report))

if __name__=='__main__':
 try:check()
 except Exception:
  traceback.print_exc();sys.stdout.flush();sys.stderr.flush();sys.exit(1)
