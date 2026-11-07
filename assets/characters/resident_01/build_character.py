"""Rebuild grounded Resident 01. Anatomical CC0 MakeHuman sources in source_data/."""
import bpy, math, json, random
import numpy as np
from pathlib import Path
from mathutils import Vector, Quaternion
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent;SRC=OUT/'source_data';random.seed(51)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
 if c.name!='Collection':bpy.data.collections.remove(c)
asset=bpy.data.collections.new('CHARACTER • Resident 01');bpy.context.scene.collection.children.link(asset)
stage=bpy.data.collections.new('STUDIO • Excluded from GLB');bpy.context.scene.collection.children.link(stage)

def objread(path):
 verts=[];uv=[];faces=[];tfaces=[];groups=[];g=''
 for l in path.read_text().splitlines():
  t=l.split()
  if not t:continue
  if t[0]=='v':verts.append(list(map(float,t[1:4])))
  elif t[0]=='vt':uv.append(list(map(float,t[1:3])))
  elif t[0]=='g':g=' '.join(t[1:])
  elif t[0]=='f':
   a=[v.split('/') for v in t[1:]];faces.append([int(v[0])-1 for v in a]);tfaces.append([int(v[1])-1 if len(v)>1 and v[1] else 0 for v in a]);groups.append(g)
 return np.array(verts),uv,faces,tfaces,groups

V,UV,F,TF,G=objread(SRC/'base.obj')
for filename,factor in [('caucasian-male-young.target',.70),('caucasian-male-old.target',.30),('universal-male-young-averagemuscle-maxweight.target',.455),('universal-male-old-averagemuscle-maxweight.target',.195)]:
 for line in (SRC/filename).read_text().splitlines():
  t=line.split()
  if len(t)==4 and not t[0].startswith('#'):V[int(t[0])]+=np.array(list(map(float,t[1:])))*factor
bodyids=sorted({i for f,g in zip(F,G) if g=='body' for i in f});floor=min(V[i,1] for i in bodyids);height=max(V[i,1] for i in bodyids)-floor;SCALE=1.78/height
# Native MakeHuman Y-up, front +Z -> Blender Z-up, front -Y.
V=np.column_stack((V[:,0]*SCALE,-V[:,2]*SCALE,(V[:,1]-floor)*SCALE))
rawweights=json.loads((SRC/'default_weights.mhw').read_text())['weights'];VW=[{} for _ in V]
for name,weights in rawweights.items():
 for i,w in weights:
  if w>0:VW[i][name]=float(w)
for d in VW:
 s=sum(d.values())
 if s:
  for k in d:d[k]/=s
skel=json.loads((SRC/'default.mhskel').read_text());joints={name:Vector(np.mean(V[ids],axis=0)) for name,ids in skel['joints'].items()}
data=bpy.data.armatures.new('AnatomicalSkeleton');rig=bpy.data.objects.new('Resident01_RIG',data);asset.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for name,b in skel['bones'].items():
 eb=data.edit_bones.new(name);eb.head=joints[b['head']];eb.tail=joints[b['tail']]
 if (eb.tail-eb.head).length<.0001:eb.tail.z+=.005
for name,b in skel['bones'].items():
 if b['parent']:data.edit_bones[name].parent=data.edit_bones[b['parent']]
bpy.ops.object.mode_set(mode='OBJECT');data.display_type='STICK';rig.show_in_front=True
meshes=[]

def material(name,color,rough=.7):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;return m

def noise_surface(m,scale=100,dist=.0005,strength=.2):
 n=m.node_tree.nodes;p=n.get('Principled BSDF');l=m.node_tree.links
 tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=scale;tex.inputs['Detail'].default_value=2
 coord=n.new('ShaderNodeTexCoord');l.new(coord.outputs['Object'],tex.inputs['Vector'])
 bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=dist;bump.inputs['Strength'].default_value=strength;l.new(tex.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
 return tex
skin=material('Skin • tone variation and fine pores',(.49,.29,.19),.48)
p=skin.node_tree.nodes.get('Principled BSDF');p.inputs['Subsurface Weight'].default_value=.075;p.inputs['Subsurface Radius'].default_value=(1,.45,.25);p.inputs['Subsurface Scale'].default_value=.009
attr=skin.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='skin_tone';skin.node_tree.links.new(attr.outputs['Color'],p.inputs['Base Color']);noise_surface(skin,1500,.00022,.22)
# Clothing uses small fiber bump and restrained color variation, not glossy plastic.
def cloth(name,c):
 m=material(name,c,.84);n=m.node_tree.nodes;p=n.get('Principled BSDF');l=m.node_tree.links
 p.inputs['Sheen Weight'].default_value=.14
 noise=noise_surface(m,1050,.00032,.25)
 tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=36;tex.inputs['Detail'].default_value=3
 coord=n.new('ShaderNodeTexCoord');l.new(coord.outputs['Object'],tex.inputs['Vector'])
 ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(*(v*.65 for v in c),1);ramp.color_ramp.elements[1].color=(*c,1);l.new(tex.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
 return m
jacketmat=cloth('Faded rust work jacket',(.26,.105,.045));jeansmat=cloth('Washed indigo denim',(.055,.09,.12));rib=cloth('Cuffs and collar • washed rib knit',(.13,.065,.031));stitch=material('Faded stitching',(.25,.17,.095));rubber=material('Scuffed rubber sole',(.22,.20,.16),.86);canvas=cloth('Dusty charcoal shoes',(.055,.058,.047));metal=material('Dull metal zipper',(.23,.22,.19),.4);metal.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value=.7
hairmat=material('Short dark hair',(.035,.026,.018),.8);noise_surface(hairmat,1700,.0004,.5)

def weighted_mesh(name,points,faces,mat,weights,uvcoords=None,uvfaces=None,subd=0):
 d=bpy.data.meshes.new(name);d.from_pydata(points,[],faces);d.update();o=bpy.data.objects.new(name,d);asset.objects.link(o);d.materials.append(mat)
 for f in d.polygons:f.use_smooth=True
 if uvcoords is not None:
  uv=d.uv_layers.new(name='UVMap')
  for poly,tf in zip(d.polygons,uvfaces):
   for loop,ti in zip(poly.loop_indices,tf):uv.data[loop].uv=uvcoords[ti]
 for i,ws in enumerate(weights):
  s=sum(ws.values())
  if not s:ws={'root':1};s=1
  for name,w in ws.items():
   if name not in data.bones:continue
   group=o.vertex_groups.get(name) or o.vertex_groups.new(name=name);group.add([i],w/s,'REPLACE')
 o.parent=rig;arm=o.modifiers.new('Skin deformation','ARMATURE');arm.object=rig
 if subd:
  su=o.modifiers.new('Surface refinement','SUBSURF');su.levels=subd;su.render_levels=subd
 meshes.append(o);return o

def part(name,faceids,mat,offset=0,subd=1,modify=None):
 ids=sorted({v for fi in faceids for v in F[fi]});mp={v:i for i,v in enumerate(ids)};points=V[ids].copy();faces=[[mp[v] for v in F[i]] for i in faceids]
 if modify is not None:points=modify(points)
 o=weighted_mesh(name,points,faces,mat,[VW[i] for i in ids],UV,[TF[i] for i in faceids],subd)
 if offset:
  # Inflate in the actual anatomical surface-normal direction.
  for vertex in o.data.vertices:vertex.co+=vertex.normal*offset
  o.data.update()
 return o,ids
# Keep source anatomy complete beneath clothes. Clothing-specific body masking happens below.
bodyfaces=[i for i,g in enumerate(G) if g=='body']
body,bodymap=part('Resident01_BODY',bodyfaces,skin,subd=1)
headz=float(max(V[i,2] for i in bodyids));headweights={i:sum(w for n,w in VW[i].items() if n=='head' or n=='jaw' or n.startswith(('special','orbicularis','levator','oris','risorius','temporalis','oculi'))) for i in bodyids}
# Authored skin diffuse replaces the provisional vertex colors.
PACK=SRC/'system_assets'
def image_node(mat,path,noncolor=False):
 node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=bpy.data.images.load(str(path),check_existing=True)
 if noncolor:node.image.colorspace_settings.name='Non-Color'
 return node
skintex=image_node(skin,PACK/'skins/middleage_caucasian_male/middleage_lightskinned_male_diffuse.png')
skin.node_tree.links.new(skintex.outputs['Color'],skin.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
# Native proxy coordinates are barycentric body positions plus measured, scaled offsets.
def fit_proxy(path):
 raw,uv,faces,tfaces,groups=objread(path.with_suffix('.obj'))
 axes={};mapping=[];delete=set();mode=''
 for line in path.read_text().splitlines():
  t=line.split()
  if not t or t[0].startswith('#'):continue
  if t[0] in ('x_scale','y_scale','z_scale'):
   a,b=int(t[1]),int(t[2]);axis={'x_scale':0,'y_scale':2,'z_scale':1}[t[0]]
   axes[t[0][0]]=abs(V[a,axis]-V[b,axis])/float(t[3])
  elif t[0]=='verts':mode='verts'
  elif t[0]=='delete_verts':mode='delete'
  elif mode=='verts' and (len(t)==1 or len(t)==9) and t[0].lstrip('-').isdigit():mapping.append(t)
  elif mode=='delete':
   i=0
   while i<len(t):
    if i+2<len(t) and t[i+1]=='-':delete.update(range(int(t[i]),int(t[i+2])+1));i+=3
    elif t[i].isdigit():delete.add(int(t[i]));i+=1
    else:i+=1
 assert len(mapping)==len(raw),(path,len(mapping),len(raw))
 pts=[];weights=[]
 for row in mapping:
  if len(row)==1:
   i=int(row[0]);pts.append(V[i]);weights.append(dict(VW[i]));continue
  ids=list(map(int,row[:3]));bary=np.array(list(map(float,row[3:6])));off=list(map(float,row[6:9]))
  pts.append(sum((V[i]*w for i,w in zip(ids,bary)),np.zeros(3))+np.array((off[0]*axes.get('x',SCALE),-off[2]*axes.get('z',SCALE),off[1]*axes.get('y',SCALE))))
  d={}
  for i,w in zip(ids,bary):
   for n,weight in VW[i].items():d[n]=d.get(n,0)+w*weight
  d={n:max(0,w) for n,w in d.items()};total=sum(d.values());weights.append({n:w/total for n,w in d.items() if total and w>0})
 return np.array(pts),uv,faces,tfaces,weights,delete

def textured_material(name,folder,diffuse,normal=None,rough=.75,alpha=False,tint=None):
 m=material(name,(.18,.22,.24),rough);n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');im=image_node(m,folder/diffuse)
 color=im.outputs['Color']
 if tint:
  mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(*tint,1);l.new(color,mix.inputs[1]);color=mix.outputs[0]
 l.new(color,p.inputs['Base Color'])
 if normal:
  nm=image_node(m,folder/normal,True);normalnode=n.new('ShaderNodeNormalMap');normalnode.inputs['Strength'].default_value=.55;l.new(nm.outputs['Color'],normalnode.inputs['Color']);l.new(normalnode.outputs['Normal'],p.inputs['Normal'])
 if alpha:
  l.new(im.outputs['Alpha'],p.inputs['Alpha']);m.surface_render_method='DITHERED';p.inputs['Roughness'].default_value=.66
 return m
clothdir=PACK/'clothes/male_casualsuit01'
clothmat=textured_material('Workshirt and jeans • diffuse + tangent normal',clothdir,'male_casualsuit01_diffuse.png','male_casualsuit01_normal.png',.8)
shoeDir=PACK/'clothes/shoes01';shoemat=textured_material('Worn shoes • diffuse + tangent normal',shoeDir,'shoes01_diffuse.png','shoes01_normal.png',.78)
hairDir=PACK/'hair/short02';hairmat=textured_material('Short hair • textured cards',hairDir,'short02_diffuse.png','short02_normal.png',.66,True,(.22,.13,.075))
covered=set()
for name,path,mat,subd in [('Workshirt, belt and denim trousers',clothdir/'male_casualsuit01.mhclo',clothmat,1),('Worn practical shoes',shoeDir/'shoes01.mhclo',shoemat,1),('Short textured hair',hairDir/'short02.mhclo',hairmat,0)]:
 pts,uv,faces,tfaces,weights,delete=fit_proxy(path);garment=weighted_mesh(name,pts,faces,mat,weights,uv,tfaces,subd);covered.update(delete)
 # Prevent subdivision from collapsing open collar/cuff edges.
 if subd:
  su=garment.modifiers.get('Surface refinement');su.boundary_smooth='PRESERVE_CORNERS'
# Authored proxy masks retain hands/neck while hiding the skin under clothing/shoes.
mask=body.vertex_groups.new(name='Visible skin outside fitted garments')
visible=[j for j,i in enumerate(bodymap) if i not in covered];mask.add(visible,1,'REPLACE')
mo=body.modifiers.new('Mask covered body','MASK');mo.vertex_group=mask.name
bpy.context.view_layer.objects.active=body;bpy.ops.object.modifier_move_up(modifier=mo.name)
# Iris mesh is separately skinned and retains its authored UVs.
EV,EU,EF,ETF,EG=objread(SRC/'low-poly.obj');mapping=[];reading=False
for line in (SRC/'low-poly.mhclo').read_text().splitlines():
 if line.startswith('verts '):reading=True;continue
 if reading:
  t=line.split()
  if len(t)==1 and t[0].isdigit():mapping.append(int(t[0]))
eyeMat=material('Eyes • authored brown iris texture',(.5,.45,.35),.21);tex=image_node(eyeMat,SRC/'brown_eye.png');eyeMat.node_tree.links.new(tex.outputs['Color'],eyeMat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
assert len(mapping)==len(EV)
eyes=weighted_mesh('Anatomical eyes',V[mapping],EF,eyeMat,[VW[i] for i in mapping],EU,ETF,1)
# Fine eyebrows are authored as tapered strands, following the actual brow surface.
# Merge into body to retain five skinned mesh objects and use its head/visibility weights.
bvh=BVHTree.FromPolygons([v.co for v in body.data.vertices],[list(f.vertices) for f in body.data.polygons])
bverts=[];bfaces=[]
for side in (-1,1):
 ec=joints[skel['bones']['eye.L' if side>0 else 'eye.R']['head']]
 for k in range(170):
  t=random.random();x=ec.x+side*(-.028+.061*t)
  z=ec.z+.025+.004*math.sin(t*math.pi)-.009*t+random.uniform(-.0028,.0028)
  hit=bvh.ray_cast(Vector((x,-1,z)),Vector((0,1,0)),2)[0]
  if hit is None:continue
  a=hit+Vector((0,-.0007,0));b=a+Vector((side*random.uniform(.0015,.0035),0,random.uniform(.002,.004)))
  radius=random.uniform(.00009,.00016)*(1-.5*t);direction=(b-a).normalized();u=Vector((0,-1,0));v=direction.cross(u).normalized();base=len(bverts)
  for center,r in ((a,radius),(b,radius*.2)):
   for j in range(4):bverts.append(center+r*(u*math.cos(j*math.pi/2)+v*math.sin(j*math.pi/2)))
  for j in range(4):bfaces.append((base+j,base+(j+1)%4,base+(j+1)%4+4,base+j+4))
browmat=material('Eyebrows • fine dark strands',(.028,.018,.010),.85)
# An explicit tiny image keeps the authored brow color portable in the GLB.
(OUT/'textures').mkdir(exist_ok=True)
browimage=bpy.data.images.new('Eyebrow strand color generated',width=4,height=4,alpha=False);browimage.pixels.foreach_set(list((.16,.12,.08,1))*16);browimage.update();browimage.filepath_raw=str(OUT/'textures/eyebrow_color.png');browimage.file_format='PNG';browimage.save();bpy.data.images.remove(browimage)
browimage=bpy.data.images.load(str(OUT/'textures/eyebrow_color.png'));browimage.pack()
brownode=browmat.node_tree.nodes.new('ShaderNodeTexImage');brownode.image=browimage;browmat.node_tree.links.new(brownode.outputs['Color'],browmat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
d=bpy.data.meshes.new('Eyebrow hair strands');d.from_pydata(bverts,[],bfaces);d.materials.append(browmat);brows=bpy.data.objects.new('Eyebrows temporary',d);asset.objects.link(brows)
d.uv_layers.new(name='UVMap')
for u in d.uv_layers.active.data:u.uv=(.5,.5)
for name in ('head','Visible skin outside fitted garments'):
 group=brows.vertex_groups.new(name=name);group.add(list(range(len(bverts))),1,'REPLACE')
bpy.ops.object.select_all(action='DESELECT');brows.select_set(True);body.select_set(True);bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
# Eye moisture is a subtle specular surface, not a dull painted sphere.
eyep=eyeMat.node_tree.nodes.get('Principled BSDF');eyep.inputs['Roughness'].default_value=.11;eyep.inputs['Coat Weight'].default_value=.3;eyep.inputs['Coat Roughness'].default_value=.08
# Hair should read matte under daylight, without a plastic highlight.
hairmat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.88
hairmat.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.25

# Authored CC0 texture maps are packed below and exported with the character.
hairmat.diffuse_color=(.045,.028,.016,1);shoemat.diffuse_color=(.24,.11,.045,1)
rig['asset']='Resident 01 • rough middle-aged resident';rig['source']='MakeHuman CC0 hm08; source_data licenses and manifest';rig['forward']='-Y; Z up; meters';rig['limitations']='FK skeleton with neutral/slouched inspection frames; no locomotion clips, IK controls or collision.'
# Actual weathered image maps: generated locally from UVs, portable to GLB.
weather_scope={'__name__':'resident_weather_module','__file__':str(OUT/'weather_materials.py')}
exec(compile((OUT/'weather_materials.py').read_text(),str(OUT/'weather_materials.py'),'exec'),weather_scope)
weather_scope['apply_weathering'](asset,OUT)
# Workbench/Solid texture display shows the actual diffuse maps without Material Preview.
for obj in asset.objects:
 if obj.type!='MESH':continue
 for slot in obj.material_slots:
  mat=slot.material
  if not mat or not mat.use_nodes:continue
  candidates=[n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and n.image.colorspace_settings.name!='Non-Color']
  if candidates:
   chosen=next((n for n in candidates if n.image.name.startswith('weathered_')),candidates[0])
   for node in mat.node_tree.nodes:node.select=False
   chosen.select=True;mat.node_tree.nodes.active=chosen

# Break the freshly combed hair silhouette without distorting anatomy.
for v in bpy.data.objects['Short textured hair'].data.vertices:
 p=v.co
 if p.z>1.65:
  p.x+=.0018*math.sin(p.z*213+p.y*31)
  p.z+=.0013*math.sin(p.x*149+p.y*63)
# Keep the engine export neutral; inspection poses are added afterward.
# Consistent rest-pose weighted export, material nodes and all sources packed.
for image in bpy.data.images:
 if image.source=='FILE':image.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in asset.objects:o.hide_set(False);o.select_set(True)
bpy.context.view_layer.objects.active=body
bpy.ops.export_scene.gltf(filepath=str(OUT/'resident_01.glb'),use_selection=True,export_format='GLB',export_animations=False,export_all_influences=False,export_apply=True)
# Two inspection frames: frame 1 is neutral; frame 2 is a tired, uneven stance.
scene=bpy.context.scene
for pb in rig.pose.bones:
 pb.rotation_mode='QUATERNION';pb.rotation_quaternion=(1,0,0,0);pb.keyframe_insert(data_path='rotation_quaternion',frame=1)
def world_turn(name,axis,angle):
 pb=rig.pose.bones[name];q=pb.bone.matrix_local.to_quaternion();pb.rotation_quaternion=q.inverted()@Quaternion(axis,angle)@q
for name,amount in [('spine05',.025),('spine04',.03),('spine03',.025),('spine02',.025),('spine01',.025)]:world_turn(name,(1,0,0),amount)
world_turn('head',(1,0,0),.055)
# Let the arms hang unevenly instead of a model-sheet A-pose.
world_turn('upperarm01.L',(0,1,0),.40);world_turn('upperarm01.R',(0,1,0),-.46)
world_turn('upperarm02.L',(0,1,0),.08);world_turn('upperarm02.R',(0,1,0),-.08)
world_turn('lowerarm01.L',(0,0,1),-.08);world_turn('lowerarm01.R',(0,0,1),.11)
world_turn('clavicle.L',(0,1,0),.035)
for pb in rig.pose.bones:pb.keyframe_insert(data_path='rotation_quaternion',frame=2)
if rig.animation_data and rig.animation_data.action:rig.animation_data.action.name='Inspection only • 1 neutral, 2 slouched'
scene.frame_start=1;scene.frame_end=2;scene.frame_set(2)
rig['inspection']='Frame 1: neutral A-pose. Frame 2: tired slouched presentation. GLB exported neutral without animation.'
# Human-scale soft daylight studio.
def stage_link(o):
 for c in list(o.users_collection):c.objects.unlink(o)
 stage.objects.link(o)
bpy.ops.mesh.primitive_plane_add(size=200);ground=bpy.context.object;stage_link(ground);ground.name='Studio floor';ground.data.materials.append(material('Neutral studio floor',(.16,.175,.17)))
scene=bpy.context.scene;scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.78,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
for name,pos,power,size in [('Window key',(-3,-4,4),220,3),('Soft fill',(3,-1,2.5),95,2.5),('Rim',(1,3,3.5),200,2)]:
 bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;stage_link(o);o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.0,-5.5,2.0));camera=bpy.context.object;stage_link(camera);camera.name='Full body inspection';camera.data.type='ORTHO';camera.data.ortho_scale=2.17;camera.rotation_euler=(Vector((0,0,.91))-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
scene.unit_settings.system='METRIC';scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.render.threads_mode='FIXED';scene.render.threads=4;scene.render.resolution_x=1100;scene.render.resolution_y=1400;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body;rig.hide_set(True)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   sp=area.spaces.active;sp.shading.type='SOLID';sp.shading.color_type='TEXTURE';sp.overlay.show_relationship_lines=False;sp.overlay.show_floor=False;sp.overlay.show_extras=False
   sp.region_3d.view_distance=3.2;sp.region_3d.view_location=(0,0,.93);sp.region_3d.view_rotation=camera.rotation_euler.to_quaternion();sp.region_3d.view_perspective='PERSP'
scene.render.filepath=str(OUT/'preview.png');bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'resident_01.blend'))
report={'character':'Resident 01 • rough middle-aged resident','height_m':1.78,'presentation_frames':{'1':'neutral reference','2':'tired slouched stance'},'body_morph':{'young':.70,'old':.30,'maxweight':.65},'mesh_objects':len(meshes),'base_triangles':sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons),'bones':len(data.bones),'body_source':'MakeHuman hm08 and CC0 system assets; see source_data licenses and manifests','materials':'Weathered UV diffuse maps with stains, dirt, uneven skin and stubble; clothing/shoe/hair tangent normal maps; all used images packed','limitations':['CC0 clothing adapted to the morphed body using authored fitting proxies','Inspection poses only; no locomotion clips or IK controls','No collision or LODs','Fine procedural skin pores remain Blender-only; image textures export to GLB']}
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
bpy.ops.render.render(write_still=True)
# Head close-up exposes anatomy/material problems that a full-body thumbnail can hide.
eyez=sum(joints[skel['bones'][n]['head']].z for n in ('eye.L','eye.R'))/2
camera.location=(.55,-2.0,1.80);target=Vector((0,0,eyez-.025));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=.39;scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.filepath=str(OUT/'preview_face.png');bpy.ops.render.render(write_still=True)
camera.location=(-2,5.5,2);camera.rotation_euler=(Vector((0,0,.91))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=2.17;scene.render.resolution_x=1100;scene.render.resolution_y=1400;scene.cycles.samples=32;scene.render.filepath=str(OUT/'preview_back.png');bpy.ops.render.render(write_still=True)
scene.frame_set(1);camera.location=(2,-5.5,2);camera.rotation_euler=(Vector((0,0,.91))-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/'preview_reference.png');bpy.ops.render.render(write_still=True)
print('REALISTIC_REBUILD_COMPLETE',json.dumps(report))
