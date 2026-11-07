"""Rebuild with: blender -b --python build_asset.py"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector
random.seed(17)
OUT=Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
 if c.name!='Collection': bpy.data.collections.remove(c)
asset=bpy.data.collections.new('ASSET • Weathered Singlewide'); bpy.context.scene.collection.children.link(asset)
stage=bpy.data.collections.new('PRESENTATION • excluded from GLB'); bpy.context.scene.collection.children.link(stage)
active=asset

def mat(name,color,rough=.7,metal=0,noise=False):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 n=m.node_tree.nodes; p=n.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
 if noise:
  tex=n.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value=6; tex.inputs['Detail'].default_value=3
  ramp=n.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].position=.15; ramp.color_ramp.elements[0].color=(*(v*.62 for v in color),1); ramp.color_ramp.elements[1].position=.85; ramp.color_ramp.elements[1].color=(*color,1)
  m.node_tree.links.new(tex.outputs['Fac'],ramp.inputs[0]); m.node_tree.links.new(ramp.outputs['Color'],p.inputs['Base Color'])
  bump=n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.18; bump.inputs['Distance'].default_value=.025; m.node_tree.links.new(tex.outputs['Fac'],bump.inputs['Height']); m.node_tree.links.new(bump.outputs[0],p.inputs['Normal'])
 return m
ivory=[mat('Chalked aluminum %02d'%i,(.61+i*.012,.59+i*.011,.49+i*.009),noise=True) for i in range(5)]
mint=[mat('Faded sage %02d'%i,(.29+i*.012,.39+i*.013,.33+i*.011),noise=True) for i in range(4)]
trim=mat('Dirty warm white trim',(.73,.71,.62),noise=True)
wood=mat('Dry aged porch timber',(.29,.24,.18),noise=True)
roof=mat('Oxidized galvanized roof',(.42,.44,.42),.85,.25,True)
rust=mat('Oxidized steel',(.24,.115,.055),.9,.15,True)
dark=mat('Chassis charcoal',(.065,.073,.068),.8,.4)
glass=mat('Dusty blue grey window glass',(.12,.19,.205),.24,.35)
curtain=mat('Yellowed curtains',(.57,.49,.34),noise=True)
skirt=mat('Weathered skirting',(.35,.38,.34),noise=True)
black=mat('Dark recesses',(.035,.04,.035))
handle=mat('Dull door hardware',(.39,.4,.36),.35,.65)

def link(o):
 for c in list(o.users_collection): c.objects.unlink(o)
 active.objects.link(o)
 return o

def box(name,loc,scale,material,bevel=.0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=link(bpy.context.object); o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(material)
 if bevel:
  mod=o.modifiers.new('Soft worn edges','BEVEL'); mod.width=bevel; mod.segments=2
  o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
 return o

def cylinder(name,loc,radius,depth,material,rotation=(0,0,0),vertices=16):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc,rotation=rotation); o=link(bpy.context.object); o.name=name; o.data.materials.append(material); return o

def beam(name,a,b,width,material):
 mid=(Vector(a)+Vector(b))/2; o=box(name,mid,(width,width,(Vector(b)-Vector(a)).length),material,.008); o.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler(); return o

# Real-world meters. Floor height .82m, 12m x 3.5m shell.
box('Sealed exterior shell',(0,0,2.09),(12,3.5,2.54),ivory[2])
for x in (-4.8,0,4.8):
 for y in (-1.2,1.2): box('Concrete support pier',(x,y,.3),(.42,.4,.6),skirt,.025)
for y in (-1.15,1.15): box('Steel chassis rail',(0,y,.63),(12,.14,.24),dark)
# Horizontal siding has physical overlap and uneven fading, with seams.
for j in range(17):
 z=.92+j*.145
 for s in (-1,1):
  for k in range(6):
   x=-5+k*2
   material=random.choice(mint if j<5 else ivory)
   box('Long wall lap siding %s %02d %02d'%(s,j,k),(x,s*1.772,z),(1.992,.044,.151),material,.006)
 for s in (-1,1):
  box('End lap siding',(s*6.016,0,z),(.044,3.5,.151),random.choice(mint if j<5 else ivory),.006)
# Vertical skirting panels with narrow visible ribs.
for s in (-1,1):
 for i in range(40):
  x=-5.85+i*.3
  box('Skirting panel',(x,s*1.73,.48),(.294,.035,.66),skirt)
  box('Skirting rib',(x+.14,s*1.756,.48),(.018,.02,.66),trim)
for s in (-1,1):
 for i in range(12): box('End skirting',(s*6.002,-1.6+i*.29,.48),(.03,.282,.66),skirt)
for s in (-1,1):
 box('Lower trim rail',(0,s*1.81,.85),(12.12,.075,.09),trim,.008)
 box('Upper eave trim',(0,s*1.84,3.36),(12.35,.12,.12),trim,.01)
 for x in (-6.04,6.04): box('Corner flashing',(x,s*1.8,2.1),(.095,.08,2.6),trim,.008)
# Low pitched metal roof, both surfaces and seams.
for s in (-1,1):
 o=box('Shallow pitched roof',(0,s*.94,3.49),(12.4,1.91,.07),roof,.008); o.rotation_euler.x=-s*math.atan2(.2,1.87)
 for i in range(25):
  x=-6+i*.5
  beam('Standing roof seam',(x,0,3.63),(x,s*1.9,3.43),.017,roof)
box('Roof ridge cap',(0,0,3.64),(12.45,.12,.055),roof,.01)
# Opaque windows: intentionally no interior, game exterior asset.
def window(x,y,z,w=1.4,h=1.04):
 s=1 if y>0 else -1
 box('Window dark gasket',(x,y,z),(w+.12,.07,h+.12),black,.012)
 box('Window pane',(x,y+s*.045,z),(w,.035,h),glass,.01)
 # curtain panels behind frame, suitable for closed shell
 for dx in (-w*.36,w*.36): box('Closed curtain edge',(x+dx,y+s*.069,z),(.21,.012,h-.06),curtain)
 for dx in (-w/2,w/2): box('Window jamb',(x+dx,y+s*.09,z),(.065,.08,h+.1),trim,.006)
 for dz in (-h/2,h/2): box('Window head and sill',(x,y+s*.1,z+dz),(w+.13,.11,.065),trim,.006)
 box('Window center sash',(x,y+s*.12,z),(.045,.06,h),trim)
 box('Window horizontal sash',(x,y+s*.13,z),(w,.06,.04),trim)
 box('Projecting drip sill',(x,y+s*.16,z-h/2-.035),(w+.2,.2,.055),trim,.008)
for x in (-4.65,-2.6,3.55,5.05): window(x,-1.82,2.37,1.18 if x>4 else 1.4)
for x in (-4.1,0,4.0): window(x,1.82,2.35)
# Entry door and screen frame.
box('Door recess',(.6,-1.823,1.86),(1.03,.075,2.08),black)
box('Faded entry door',(.6,-1.874,1.86),(.91,.055,2.0),mint[1],.01)
for dx in (-.51,.51):box('Door casing',(.6+dx,-1.926,1.86),(.075,.1,2.13),trim,.006)
box('Door lintel',(.6,-1.93,2.91),(1.12,.1,.075),trim)
box('Door upper glass',(.6,-1.915,2.32),(.56,.025,.52),glass)
for x in (.30,.9):box('Door glass frame',(x,-1.94,2.32),(.035,.03,.59),trim)
for z in (2.04,2.6):box('Door glass frame',(.6,-1.94,z),(.63,.03,.035),trim)
cylinder('Door knob',(.94,-1.982,1.77),.035,.055,handle,(math.pi/2,0,0))
box('Door lower kickplate',(.6,-1.925,.99),(.8,.023,.16),roof)
# Porch at entry, plank gaps, three steps, handrail.
for i in range(9):box('Porch deck board',(.6,-2.09-i*.132,.78),(2.0,.123,.075),wood,.012)
for x in (-.25,1.45):
 for y in (-2.13,-3.07):box('Porch support',(x,y,.39),(.13,.13,.78),wood,.01)
for i in range(3):
 z=.61-i*.2; y=-3.31-i*.29
 for j in range(2):box('Step tread',(.6,y-j*.13,z),(1.28,.122,.07),wood,.012)
 for x in (.06,1.14):box('Step support',(x,y,z/2),(.1,.25,z),wood)
for x in (-.36,1.56):
 for y in (-2.12,-3.08):box('Porch rail post',(x,y,1.19),(.095,.095,1.0),wood,.01)
 beam('Side porch handrail',(x,-2.12,1.68),(x,-3.08,1.68),.085,wood)
 beam('Sloped stair rail',(x,-3.08,1.65),(x,-3.98,.88),.07,wood)
box('Front guard short',(-.15,-3.09,1.42),(.42,.065,.08),wood)
# Modest metal rain hood; no elaborate deck or props.
box('Entry rain hood',(.6,-2.16,3.04),(1.7,.85,.06),roof,.012)
for x in (-.15,1.35):beam('Rain hood bracket',(x,-1.86,2.65),(x,-2.51,3.0),.035,rust)
# End ventilation, small utility boxes, roof vent.
box('Utility meter cabinet',(6.07,.65,1.57),(.13,.42,.52),roof,.015)
cylinder('Round meter',(6.17,.65,1.64),.115,.09,glass,(0,math.pi/2,0),24)
beam('Utility conduit',(6.12,.65,.67),(6.12,.65,2.57),.035,roof)
for i in range(8):box('Skirt vent slot',(-4.3+i*.065,-1.801,.48),(.036,.012,.16),dark)
cylinder('Plumbing vent',(3.1,.4,3.84),.07,.45,roof)
cylinder('Vent cap',(3.1,.4,4.075),.12,.045,roof)
# End window: AC occupies the lower sash, with glass above and infill beside it.
box('AC window gasket',(-6.062,.25,2.37),(.055,1.38,1.27),black,.008)
box('AC upper window glass',(-6.103,.25,2.69),(.025,1.22,.54),glass,.006)
for y in (-.37,.87):
 box('AC window side jamb',(-6.137,y,2.37),(.09,.075,1.29),trim,.006)
for z in (1.76,2.985):
 box('AC window head and sill',(-6.14,.25,z),(.12,1.4,.075),trim,.006)
box('AC lowered sash rail',(-6.15,.25,2.395),(.095,1.25,.065),trim,.006)
box('AC upper glass center stile',(-6.14,.25,2.69),(.07,.035,.54),trim,.004)
box('AC projecting window sill',(-6.19,.25,1.725),(.27,1.47,.055),trim,.008)
for y in (-.275,.775):
 box('AC accordion side infill',(-6.112,y,2.075),(.035,.23,.55),skirt)
 for j in range(6):
  box('AC accordion rib',(-6.143,y-.095+j*.038,2.075),(.025,.012,.52),trim)
# AC body passes through the lower window opening.
box('Window AC housing',(-6.19,.25,2.05),(.42,.82,.49),trim,.025)
for i in range(10):box('AC grille fin',(-6.412,.25,1.87+i*.038),(.015,.72,.013),dark)
# Rust freckles at fastening edges, sparse and subtle.
for i in range(64):
 x=random.uniform(-5.9,5.9); z=random.choice((.99,1.57,3.2))+random.uniform(-.05,.05)
 if abs(x-.6)<.6:continue
 box('Small siding wear',(x,-1.801,z),(random.uniform(.012,.045),.006,random.uniform(.025,.09)),rust)
# Useful custom properties and root.
bpy.ops.object.empty_add(type='PLAIN_AXES',location=(0,0,0)); root=link(bpy.context.object); root.name='TRAILER_SINGLEWIDE_A_ROOT'
root['asset_id']='trailer_singlewide_a'; root['units']='meters'; root['purpose']='Exterior only; no interior, collision or LODs'; root['nominal_shell_dimensions']='12.0 x 3.5 meters'
for o in list(asset.objects):
 if o!=root:o.parent=root
# Stage and studio render, separate from exported asset.
active=stage
ground=mat('Presentation ground',(.27,.29,.255),noise=True)
box('Presentation ground',(0,0,-.08),(200,200,.12),ground)
world=bpy.context.scene.world; world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(.68,.73,.78,1); world.node_tree.nodes['Background'].inputs[1].default_value=.65
bpy.ops.object.light_add(type='AREA',location=(-3,-8,14)); light=link(bpy.context.object); light.name='Large overcast softbox'; light.data.energy=2000; light.data.shape='DISK'; light.data.size=10
bpy.ops.object.camera_add(location=(-15,-18,10)); camera=link(bpy.context.object); camera.rotation_euler=(Vector((0,-.55,1.65))-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.type='ORTHO';camera.data.ortho_scale=18
scene=bpy.context.scene;scene.camera=camera;scene.unit_settings.system='METRIC';scene.render.engine='CYCLES';scene.cycles.samples=64;scene.cycles.use_denoising=False
scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
# Add furnished interior, export full geometry, then save/render cutaway presentation.
interior_scope={'__name__':'trailer_interior_module','__file__':str(OUT/'build_interior.py')}
exec(compile((OUT/'build_interior.py').read_text(),str(OUT/'build_interior.py'),'exec'),interior_scope)
interior_scope['save_and_render']()
