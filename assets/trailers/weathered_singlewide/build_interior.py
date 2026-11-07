"""Add interior to an exterior file; callable via populate() during a full rebuild."""
import bpy, math, json, random
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent

def populate():
 random.seed(34)
 asset=bpy.data.collections['ASSET • Weathered Singlewide']
 if 'INTERIOR • Rooms and furnishings' in bpy.data.collections:
  raise RuntimeError('Interior already exists; rebuild from build_asset.py instead of layering another interior.')
 inside=bpy.data.collections.new('INTERIOR • Rooms and furnishings');asset.children.link(inside)
 upper=bpy.data.collections.new('CUTAWAY • Upper partitions — toggle to restore');asset.children.link(upper)
 shell=bpy.data.collections.new('CUTAWAY • Roof and front wall — toggle to restore');asset.children.link(shell)
 active=inside; root=bpy.data.objects['TRAILER_SINGLEWIDE_A_ROOT']
 def material(name,color,rough=.7,noise=False):
  m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
  p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
  if noise:
   n=m.node_tree.nodes.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=16;n.inputs['Detail'].default_value=2
   r=m.node_tree.nodes.new('ShaderNodeValToRGB');r.color_ramp.elements[0].color=(*(c*.63 for c in color),1);r.color_ramp.elements[1].color=(*color,1)
   m.node_tree.links.new(n.outputs['Fac'],r.inputs[0]);m.node_tree.links.new(r.outputs['Color'],p.inputs['Base Color'])
   b=m.node_tree.nodes.new('ShaderNodeBump');b.inputs['Strength'].default_value=.22;b.inputs['Distance'].default_value=.008;m.node_tree.links.new(n.outputs['Fac'],b.inputs['Height']);m.node_tree.links.new(b.outputs[0],p.inputs['Normal'])
  return m
 def cube(name,loc,size,mat,bevel=0,collection=None):
  x,y,z=(v/2 for v in size)
  verts=[(-x,-y,-z),(-x,-y,z),(-x,y,-z),(-x,y,z),(x,-y,-z),(x,-y,z),(x,y,-z),(x,y,z)]
  faces=[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
  mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(mat)
  o=bpy.data.objects.new(name,mesh);(collection or active).objects.link(o);o.location=loc;o.parent=root
  if bevel:
   mod=o.modifiers.new('Soft edges','BEVEL');mod.width=bevel;mod.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
  return o
 def cyl(name,loc,r,depth,mat):
  vs=[];n=24
  for z in (-depth/2,depth/2):vs.extend([(r*math.cos(i*2*math.pi/n),r*math.sin(i*2*math.pi/n),z) for i in range(n)])
  fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
  mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.materials.append(mat);o=bpy.data.objects.new(name,mesh);active.objects.link(o);o.location=loc;o.parent=root;return o
 panel=material('Interior • Faded honey woodgrain',(.34,.235,.145),noise=True)
 edge=material('Interior • Dark wood molding',(.20,.125,.07),noise=True)
 lino=material('Interior • Yellowed vinyl flooring',(.43,.36,.24),noise=True)
 carpet=material('Interior • Worn oatmeal carpet',(.33,.27,.20),noise=True)
 cream=material('Interior • Aged appliance enamel',(.73,.69,.55),noise=True)
 counter=material('Interior • Beige laminate',(.50,.43,.31),noise=True)
 fabric=material('Interior • Brown couch fabric',(.25,.15,.085),noise=True)
 sage=material('Interior • Old green upholstery',(.23,.27,.16),noise=True)
 blue=material('Interior • Faded blue blanket',(.15,.23,.28),noise=True)
 rose=material('Interior • Faded floral bedding',(.42,.26,.23),noise=True)
 linen=material('Interior • Pillow cotton',(.68,.61,.49),noise=True)
 porcelain=material('Interior • Porcelain',(.76,.74,.64),.3)
 metal=material('Interior • Dull stainless',(.34,.37,.36),.3)
 dark=bpy.data.materials['Dark recesses'];glass=bpy.data.materials['Dusty blue grey window glass'];timber=bpy.data.materials['Dry aged porch timber'];trim=bpy.data.materials['Dirty warm white trim']
 # Replace solid proxy with a floor and actual walls around framed openings.
 old=bpy.data.objects.get('Sealed exterior shell')
 if old:bpy.data.objects.remove(old,do_unlink=True)
 cube('Structural subfloor',(0,0,.79),(12,3.5,.16),timber)
 cube('Living room carpet',(-4.02,0,.882),(3.78,3.25,.025),carpet)
 cube('Kitchen and corridor linoleum',(1.94,0,.88),(8.1,3.25,.02),lino)
 for i in range(17):
  x=-2.04+i*.47
  cube('Vinyl seam longitudinal',(x,0,.893),(.006,3.24,.003),counter)
 for y in [-1.6+i*.47 for i in range(8)]:cube('Vinyl seam transverse',(1.94,y,.893),(8.08,.006,.003),counter)
 front=[(-5.35,-3.95,1.85,2.89),(-3.3,-1.9,1.85,2.89),(2.85,4.25,1.85,2.89),(4.46,5.64,1.85,2.89),(.09,1.11,.85,2.91)]
 back=[(-4.8,-3.4,1.83,2.87),(-.7,.7,1.83,2.87),(3.3,4.7,1.83,2.87)]
 end=[(-.4,.9,1.76,2.99)]
 def segments(name,a,b,zlo,zhi,holes,axis,fixed,depth,mat,col=None):
  aa=sorted({a,b}|{max(a,min(b,v)) for h in holes for v in h[:2]})
  zz=sorted({zlo,zhi}|{max(zlo,min(zhi,v)) for h in holes for v in h[2:]})
  for l,r in zip(aa,aa[1:]):
   for bot,top in zip(zz,zz[1:]):
    if r-l<.001 or top-bot<.001:continue
    mid=(l+r)/2;zm=(bot+top)/2
    if any(h[0]<mid<h[1] and h[2]<zm<h[3] for h in holes):continue
    loc=(mid,fixed,zm) if axis=='X' else (fixed,mid,zm)
    size=(r-l,depth,top-bot) if axis=='X' else (depth,r-l,top-bot)
    cube(name,loc,size,mat,collection=col)
 segments('Front wall with real openings',-6,6,.87,3.35,front,'X',-1.69,.11,panel,shell)
 segments('Rear paneled wall',-6,6,.87,3.35,back,'X',1.69,.11,panel)
 segments('Left end wall with AC window',-1.7,1.7,.87,3.35,end,'Y',-5.95,.1,panel)
 segments('Right end paneled wall',-1.7,1.7,.87,3.35,[],'Y',5.95,.1,panel)
 # Clip physical siding boards at the window/door holes; no phantom solid wall behind glass.
 for o in list(asset.objects):
  if not (o.name.startswith('Long wall lap siding') or o.name.startswith('End lap siding')):continue
  axis='X' if o.name.startswith('Long') else 'Y'
  if axis=='X':holes=front if o.location.y<0 else back;fixed=o.location.y;u=o.location.x;w=o.dimensions.x;d=o.dimensions.y
  else:holes=end if o.location.x<0 else [];fixed=o.location.x;u=o.location.y;w=o.dimensions.y;d=o.dimensions.x
  z=o.location.z;h=o.dimensions.z
  if any(q[0]<u+w/2 and q[1]>u-w/2 and q[2]<z+h/2 and q[3]>z-h/2 for q in holes):
   segments(o.name+' cut',u-w/2,u+w/2,z-h/2,z+h/2,holes,axis,fixed,d,o.data.materials[0],shell if axis=='X' and fixed<0 else inside)
   bpy.data.objects.remove(o,do_unlink=True)
 # Remove opaque black window backplates; replace with hollow perimeter gaskets.
 for o in list(bpy.data.objects):
  if o.name.startswith('Window dark gasket'):
   x,y,z=o.location;w=o.dimensions.x;h=o.dimensions.z
   for dx in (-w/2,w/2):cube('Hollow window gasket jamb',(x+dx,y,z),(.045,.05,h),dark,collection=shell if y<0 else inside)
   for dz in (-h/2,h/2):cube('Hollow window gasket rail',(x,y,z+dz),(w,.05,.045),dark,collection=shell if y<0 else inside)
   bpy.data.objects.remove(o,do_unlink=True)
 ac=bpy.data.objects.get('AC window gasket')
 if ac:bpy.data.objects.remove(ac,do_unlink=True)
 # Roof and front facade are present in full export; independently toggleable for cutaway.
 for o in list(asset.objects):
  n=o.name
  front_obj=(o.type=='MESH' and o.location.y < -1.72 and o.location.z>.86 and not n.startswith(('Porch','Step','Side porch','Sloped stair','Front guard','Rain hood')))
  roof_obj=n.startswith(('Shallow pitched roof','Standing roof seam','Roof ridge cap','Plumbing vent','Vent cap','Upper eave trim'))
  if front_obj or roof_obj:
   for c in list(o.users_collection):c.objects.unlink(o)
   shell.objects.link(o)
 ceiling=cube('Removable ceiling',(0,0,3.31),(11.8,3.24,.065),cream,collection=shell)
 # Interior wall panel seams on rear wall.
 for i in range(48):
  x=-5.86+i*.245
  if any(h[0]<x<h[1] for h in back):continue
  cube('Rear paneling groove',(x,1.625,2.08),(.009,.008,2.38),edge)
 cube('Rear baseboard',(0,1.62,.96),(11.8,.045,.12),edge)
 # Partition lower and upper segments: visible doorway openings, upper walls hidden only for cutaway.
 def partition(name,axis,fixed,a,b,door=None):
  holes=[] if door is None else [(door[0],door[1],.87,2.87)]
  segments(name+' lower',a,b,.9,1.72,holes,axis,fixed,.085,panel)
  segments(name+' upper',a,b,1.72,3.3,holes,axis,fixed,.085,panel,upper)
  if door:
   for u in door:
    loc=(u,fixed,1.91) if axis=='X' else (fixed,u,1.91)
    size=(.065,.11,2.02) if axis=='X' else (.11,.065,2.02)
    cube(name+' door jamb',loc,size,trim,collection=upper)
   loc=((door[0]+door[1])/2,fixed,2.9) if axis=='X' else (fixed,(door[0]+door[1])/2,2.9)
   size=(door[1]-door[0]+.12,.11,.065) if axis=='X' else (.11,door[1]-door[0]+.12,.065)
   cube(name+' door head',loc,size,trim,collection=upper)
 # Hall is y=.73..1.63 (~.90m), x=.86..4.10: no entrance partition beside fridge.
 partition('Bathroom west','Y',.95,-1.62,.68)
 partition('Bathroom east','Y',2.55,-1.62,.68)
 partition('Bathroom hallway','X',.68,.95,2.55,(1.66,2.43))
 partition('Spare east','Y',4.1,-1.62,.68)
 partition('Spare hallway','X',.68,2.55,4.1,(3.19,3.99))
 partition('Main bedroom entry','Y',4.1,.68,1.63,(.77,1.57))
 # Furniture on living-room end: easy conversation circle with middle walking route.
 cube('Sofa plinth',(-4.15,1.03,1.10),(2.35,.78,.36),edge,.06)
 cube('Sofa back',(-4.15,1.37,1.55),(2.35,.2,1.0),fabric,.09)
 for x in (-5.22,-3.08):cube('Sofa rounded arm',(x,1.02,1.4),(.23,.82,.62),fabric,.08)
 for x in (-4.85,-4.15,-3.45):
  cube('Sofa seat cushion',(x,.94,1.34),(.65,.58,.22),fabric,.07)
  cube('Sofa back cushion',(x,1.25,1.67),(.65,.19,.54),fabric,.065)
  for dx in (-.22,0,.22):cube('Faded couch stripe',(x+dx,.94,1.455),(.025,.52,.006),counter)
 cube('Recliner base',(-5.1,-.75,1.21),(.83,.84,.55),sage,.1)
 cube('Recliner back',(-5.42,-.75,1.65),(.22,.85,.95),sage,.1)
 for y in (-1.15,-.35):cube('Recliner arm',(-5.07,y,1.44),(.9,.16,.38),sage,.065)
 def table(name,x,y,z,w,d,mat):
  cube(name+' top',(x,y,z),(w,d,.065),mat,.025)
  for dx in (-w/2+.07,w/2-.07):
   for dy in (-d/2+.07,d/2-.07):cube(name+' leg',(x+dx,y+dy,(z+.88)/2),(.055,.055,z-.88),edge)
 table('Coffee table',-3.96,-.26,1.3,1.25,.58,edge)
 cube('TV stand',(-3.0,-1.25,1.12),(.95,.48,.47),edge,.015)
 cube('Old television housing',(-3.0,-1.24,1.65),(.72,.39,.58),dark,.045)
 cube('Old television screen',(-3.0,-1.025,1.66),(.58,.025,.41),glass,.02)
 # Kitchen runs along back, refrigerator stops short of unobstructed hall entrance.
 for x in (-1.66,-1.06,-.46):
  cube('Kitchen cabinet body',(x,1.30,1.31),(.58,.61,.84),panel,.01)
  cube('Kitchen cabinet front',(x,.98,1.29),(.53,.032,.68),edge,.01)
  cube('Cabinet pull',(x,.952,1.53),(.17,.025,.018),metal)
 cube('Countertop',(-1.36,1.3,1.76),(1.2,.67,.055),counter,.014)
 # Sink bowl inset and rim.
 cube('Sink rim',(-1.43,1.29,1.79),(.61,.44,.025),metal,.025)
 cube('Sink dark well',(-1.43,1.29,1.805),(.50,.33,.015),dark,.035)
 cube('Sink bowl base',(-1.43,1.29,1.814),(.39,.23,.012),metal,.035)
 cyl('Faucet riser',(-1.43,1.54,1.91),.018,.25,metal)
 cube('Faucet spout',(-1.43,1.47,2.03),(.035,.17,.035),metal,.01)
 cube('Old white stove',(-.46,1.27,1.33),(.60,.65,.86),cream,.02)
 cube('Stovetop',(-.46,1.27,1.78),(.60,.65,.045),cream,.01)
 for x in (-.61,-.31):
  for y in (1.1,1.43):cyl('Black electric burner',(x,y,1.812),.10,.017,dark)
 cube('Oven window',(-.46,.932,1.32),(.43,.018,.32),dark,.012)
 cube('Oven handle',(-.46,.903,1.55),(.43,.03,.028),metal)
 cube('Refrigerator body',(.31,1.27,1.79),(.69,.68,1.80),cream,.035)
 for z,h in ((2.37,.55),(1.46,1.20)):
  cube('Refrigerator door',(.31,.907,z),(.66,.055,h),cream,.025)
  cube('Fridge door handle',(.55,.859,z),(.025,.03,.25),metal,.008)
 for x in (-1.65,-1.05):
  cube('Upper kitchen cabinet',(x,1.43,2.68),(.59,.36,.68),panel,.01)
  cube('Upper cabinet inset',(x,1.235,2.68),(.51,.025,.58),edge,.01)
 cube('Stove hood',(-.46,1.35,2.54),(.68,.48,.17),cream,.02)
 table('Dining table',-1.05,-.46,1.63,.95,.68,counter)
 for y in (-1.04,.13):
  cube('Dining chair seat',(-1.05,y,1.34),(.43,.43,.06),sage,.025)
  for dx in (-.16,.16):
   for dy in (-.16,.16):cube('Dining chair leg',(-1.05+dx,y+dy,1.11),(.032,.032,.44),edge)
  cube('Dining chair back',(-1.05,y+(-.20 if y<0 else .20),1.66),(.43,.04,.55),sage,.02)
 # Bathroom. No fixture projects into corridor or door opening.
 cube('Shower tray',(1.46,-1.09,.98),(.85,.90,.17),porcelain,.05)
 cube('Shower wall back',(1.45,-1.55,1.82),(.85,.03,1.65),cream)
 cube('Shower wall side',(1.02,-1.1,1.82),(.03,.9,1.65),cream)
 cube('Shower frame header',(1.45,-.63,2.66),(.87,.035,.04),metal,collection=upper)
 cyl('Toilet pedestal',(2.20,-1.02,1.10),.16,.4,porcelain)
 seat=cyl('Toilet bowl',(2.20,-.95,1.31),.23,.19,porcelain);seat.scale.y=1.25
 hole=cyl('Toilet seat opening',(2.20,-.93,1.414),.15,.008,dark);hole.scale.y=1.25
 cube('Toilet cistern',(2.20,-1.36,1.48),(.44,.20,.55),porcelain,.04)
 cube('Bathroom vanity',(2.24,.15,1.27),(.48,.52,.76),panel,.015)
 cube('Vanity sink',(2.24,.15,1.68),(.52,.56,.08),porcelain,.04)
 cube('Vanity basin',(2.24,.15,1.725),(.32,.34,.015),metal,.04)
 cube('Bath mat',(1.76,-.14,.916),(.63,.65,.025),linen,.02)
 # Beds run front-to-back, keeping hall clear. Floor finish changes at bedroom openings.
 def bed(name,x,y,w,length,blanket):
  cube(name+' carpet',(x,-.48,.907),(w+.24,2.12,.025),carpet)
  cube(name+' frame',(x,y,1.10),(w,length,.35),edge,.035)
  cube(name+' mattress',(x,y,1.36),(w-.04,length-.04,.25),linen,.085)
  cube(name+' blanket',(x,y+.18,1.50),(w-.06,length-.48,.08),blanket,.045)
  cube(name+' pillow',(x,y-length/2+.30,1.56),(w*.74,.40,.12),linen,.07)
  for dy in [i*.16 for i in range(8)]:cube(name+' blanket stitch',(x,y-.35+dy,1.543),(w-.12,.012,.006),counter)
 bed('Spare single bed',3.05,-.43,.72,1.91,blue)
 table('Spare narrow desk',3.76,-.60,1.65,.42,.83,edge)
 cube('Desk old monitor',(3.76,-.55,1.91),(.34,.25,.32),dark,.02)
 cube('Desk monitor glass',(3.76,-.405,1.93),(.26,.015,.20),glass)
 bed('Main double bed',5.02,-.40,1.35,1.95,rose)
 cube('Main wardrobe',(5.50,1.25,1.95),(.63,.58,2.10),panel,.015)
 for x in (5.34,5.65):cube('Wardrobe door',(x,.944,1.95),(.30,.025,1.98),edge,.01)
 # Small-scale clutter and evidence of daily life.
 paper=material('Interior • Crumpled paper',(.76,.72,.60),noise=True)
 card=material('Interior • Packing cardboard',(.42,.29,.15),noise=True)
 for i in range(5):
  o=cube('Bill on coffee table',(-4.3+random.random()*.65,-.35+random.random()*.2,1.338+i*.001),(.14,.10,.002),paper);o.rotation_euler.z=random.uniform(-.8,.8)
 for x,y,z in [(-3.68,-.25,1.38),(-1.22,-.38,1.72)]:
  cyl('Coffee mug',(x,y,z),.044,.085,cream);cyl('Coffee surface',(x,y,z+.044),.035,.002,dark)
 for i in range(3):
  cube('Secondhand stereo',(-4.32+i*.30,-.2,1.02),(.25,.22,.13),dark,.008)
  for j in range(2):cube('Stereo dial',(-4.4+i*.30+j*.14,-.316,1.02),(.035,.01,.035),metal)
 cube('Box under spare desk',(3.77,.12,1.08),(.39,.35,.38),card,.01)
 cube('Kitchen paperwork',(-1.1,-.45,1.671),(.28,.21,.005),paper)
 # Wall pictures are original abstract landscapes made from simple colored insets.
 picture=material('Interior • Muted landscape print',(.25,.34,.30))
 for x in (-5.3,1.5,5.0):
  cube('Picture frame',(x,1.61,2.58),(.50,.035,.35),edge)
  cube('Landscape print',(x,1.585,2.58),(.43,.012,.28),picture)
 root['purpose']='Furnished interior and exterior; static doors, no collision or LODs'
 root['hallway_clear_width_m']=.90
 root['hallway_path']='Kitchen beside refrigerator -> rear hall -> bathroom, spare room, main bedroom'
 return asset,inside,upper,shell

def save_and_render():
 asset,inside,upper,shell=populate()
 root=bpy.data.objects['TRAILER_SINGLEWIDE_A_ROOT']
 bpy.ops.object.select_all(action='DESELECT')
 for o in asset.all_objects:o.select_set(True)
 bpy.context.view_layer.objects.active=root
 bpy.ops.export_scene.gltf(filepath=str(OUT/'trailer_singlewide_a.glb'),use_selection=True,export_format='GLB',export_apply=True)
 # Presentation-only cutaway omits roof, facade, upper partition portions; full pieces retained.
 upper.hide_render=True;shell.hide_render=True
 for o in list(upper.objects)+list(shell.objects):o.hide_set(True)
 scene=bpy.context.scene
 camera=scene.camera;camera.location=(-11,-16,17)
 camera.rotation_euler=(Vector((0,0,1.25))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=16
 scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
 scene.cycles.samples=32;scene.cycles.use_denoising=False;scene.render.threads_mode='FIXED';scene.render.threads=4
 scene.world.node_tree.nodes['Background'].inputs[1].default_value=.8
 # Add broad overhead light to keep the interior readable under overcast presentation lighting.
 stage=bpy.data.collections['PRESENTATION • excluded from GLB']
 data=bpy.data.lights.new('Interior soft daylight','AREA');data.energy=1100;data.shape='RECTANGLE';data.size=10;data.size_y=5
 light=bpy.data.objects.new('Interior soft daylight',data);stage.objects.link(light);light.location=(0,0,9)
 for area in bpy.context.screen.areas if bpy.context.screen else []:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_perspective='CAMERA'
 scene.render.filepath=str(OUT/'preview.png')
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'trailer_singlewide_a.blend'))
 meshes=[o for o in asset.all_objects if o.type=='MESH']
 report={'asset':'trailer_singlewide_a','mesh_objects':len(meshes),'base_triangles':sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons),'meters':True,'exterior_only':False,'hallway_clear_width_m':.90,'door_openings_m':{'bathroom':.77,'spare':.80,'main':.80},'clear_framed_doorways_m':{'bathroom':.705,'spare':.735,'main':.735},'cutaway_collections':[upper.name,shell.name],'glb_materials':'Base colors export; procedural wear is not baked.','limitations':['Static closed exterior door','No collision or LODs','No baked texture atlas','Art prototype; not engine optimized']}
 (OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
 bpy.ops.render.render(write_still=True)
 print('INTERIOR_COMPLETE',json.dumps(report))

if __name__=='__main__':save_and_render()
