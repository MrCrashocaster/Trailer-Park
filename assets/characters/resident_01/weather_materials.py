"""Deterministic UV-image weathering for the resident; source images remain untouched.
Call apply_weathering(asset_collection, OUT) after meshes/materials exist and before export.
All changes are saved image maps, not render-only shader effects.
"""
import bpy
import numpy as np
from pathlib import Path


def _image_node(mat):
    # Materials contain both diffuse and tangent-normal images. Only touch color images.
    choices=[n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image
             and n.image.colorspace_settings.name!='Non-Color']
    if not choices:return None
    return next((n for n in choices if 'diffuse' in n.image.name.lower()),choices[0])


def _position_atlas(obj, material_index, width, height):
    """Rasterize undeformed/rest mesh XYZ at each texture pixel using authored UVs."""
    mesh=obj.data; mesh.calc_loop_triangles(); uv=mesh.uv_layers.active.data
    pos=np.zeros((height,width,3),dtype=np.float32); valid=np.zeros((height,width),dtype=bool)
    for tri in mesh.loop_triangles:
        if tri.material_index!=material_index:continue
        tex=np.array([uv[i].uv[:] for i in tri.loops],np.float32)
        tex[:,0]*=width-1;tex[:,1]*=height-1
        lo=np.floor(tex.min(axis=0)).astype(int);hi=np.ceil(tex.max(axis=0)).astype(int)
        lo=np.maximum(lo,0);hi=np.minimum(hi,(width-1,height-1))
        if np.any(hi<lo):continue
        xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1,dtype=np.float32)+.5,
                          np.arange(lo[1],hi[1]+1,dtype=np.float32)+.5)
        a,b,c=tex;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(float(den))<1e-7:continue
        wa=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den
        wb=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den
        wc=1-wa-wb;mask=(wa>=-.005)&(wb>=-.005)&(wc>=-.005)
        verts=np.array([obj.matrix_world@mesh.vertices[i].co for i in tri.vertices],np.float32)
        xyz=wa[...,None]*verts[0]+wb[...,None]*verts[1]+wc[...,None]*verts[2]
        region=pos[lo[1]:hi[1]+1,lo[0]:hi[0]+1];region[mask]=xyz[mask]
        valid[lo[1]:hi[1]+1,lo[0]:hi[0]+1]|=mask
    return pos,valid


def _smooth(a,b,x):
    t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)


def _blend(rgb,color,amount):
    amount=np.clip(amount,0,.9)[...,None]
    return rgb*(1-amount)+np.asarray(color,dtype=np.float32)*amount


def _weather_shirt(rgb,p,valid,rng):
    x,y,z=p[...,0],p[...,1],p[...,2]
    shirt=_smooth(.985,1.035,z)
    lum=(rgb*np.array([.2126,.7152,.0722],np.float32)).sum(axis=-1)
    # The original blue work shirt becomes a cheap sun-faded brown/burgundy garment.
    recolor=lum[...,None]*np.array([1.26,.76,.49],np.float32)+np.array([.040,.022,.012])
    rgb=rgb*(1-shirt[...,None])+np.clip(recolor,0,1)*shirt[...,None]
    # Original earthy flannel: broad faded rust blocks crossed with olive/charcoal.
    # The old diffuse luminance retains fabric folds rather than replacing it with flat paint.
    period=.087
    warp_x=x+.003*np.sin(z*71+y*29)
    warp_z=z+.003*np.sin(x*81-y*41)
    def bar(coord,width):
        distance=np.abs((coord+period*.5)%period-period*.5)
        return 1-_smooth(width,width+.004,distance)
    vertical=bar(warp_x,.016);horizontal=bar(warp_z,.016)
    plaid=1-(1-vertical*.46)*(1-horizontal*.46)
    rgb=_blend(rgb,(.085,.098,.061),plaid*shirt)
    # Broken, thin cotton pinstripes sit off-center inside each broad block.
    pin_x=bar(warp_x+period*.31,.0010)
    pin_z=bar(warp_z+period*.31,.0010)
    pins=np.maximum(pin_x,pin_z)*shirt*.31
    rgb=_blend(rgb,(.49,.43,.29),pins)
    shoulder=np.exp(-((np.abs(x)-.18)/.13)**2-((z-1.43)/.065)**2)*shirt
    rgb=_blend(rgb,(.35,.29,.20),shoulder*.11)
    field=.5+.22*np.sin(x*117+z*41)*np.sin(y*103-z*67)+.15*np.sin(x*245+y*81+z*159)
    field=np.clip(field,0,1)
    front=1-_smooth(-.05,.025,y)
    collar=np.exp(-((z-1.49)/.065)**2)*np.exp(-(x/.115)**4)
    pits=np.exp(-((np.abs(x)-.205)/.082)**2-((z-1.37)/.095)**2)
    sweat=(collar*.76+pits*.53)*shirt*(.65+.35*field)
    rgb=_blend(rgb,(.055,.044,.022),sweat)
    spill=(np.exp(-((x+.065)/.052)**2-((z-1.275)/.083)**2)*.69
           +np.exp(-((x-.105)/.043)**2-((z-1.155)/.070)**2)*.66
           +np.exp(-((x+.13)/.028)**2-((z-1.10)/.031)**2)*.59)*front*shirt
    spill*=np.clip((field-.15)*1.8,0,1)
    rgb=_blend(rgb,(.065,.047,.021),spill)
    drip=np.exp(-((x+.055)/.009)**2-((z-1.20)/.09)**2)*front*shirt*.27*(.35+.65*field)
    rgb=_blend(rgb,(.12,.075,.029),drip)
    hem=np.exp(-((z-1.025)/.05)**2)*shirt*(.25+.25*field)
    rgb=_blend(rgb,(.16,.105,.055),hem)
    jeans=(1-shirt)*_smooth(.08,.15,z)
    knee=np.exp(-((z-.50)/.085)**2)*front*jeans
    rgb=_blend(rgb,(.36,.33,.25),knee*.35*(.5+.5*field))
    mud=(1-_smooth(.13,.33,z))*jeans*(.34+.54*field)
    rgb=_blend(rgb,(.18,.125,.067),mud)
    # Tone down the pale stock-fabric ankle marks into dirty, worn repairs.
    pale=_smooth(.40,.65,np.max(rgb,axis=-1))*(1-shirt)*(1-_smooth(.27,.37,z))
    rgb=_blend(rgb,(.17,.145,.11),pale*.84)
    # Scattered, irregular old marks stay small enough to read as dirt rather than camouflage.
    flecks=(rng.random(z.shape)>.997).astype(np.float32)*shirt*.20
    rgb=_blend(rgb,(.11,.07,.035),flecks)
    return rgb


def _weather_skin(rgb,p,valid,rng,eye_z):
    x,y,z=p[...,0],p[...,1],p[...,2]
    front=np.exp(-((y+.11)/.085)**2)
    face=_smooth(eye_z-.155,eye_z-.12,z)*(1-_smooth(eye_z+.085,eye_z+.12,z))
    cheeks=np.exp(-((np.abs(x)-.058)/.036)**2-((z-(eye_z-.034))/.035)**2)*front
    nose=np.exp(-(x/.023)**2-((z-(eye_z-.038))/.027)**2)*front
    # Uneven sun/wind exposure and nose/cheek flush, not an infection/makeup mask.
    flush=np.clip(.30*cheeks+.27*nose,0,.45)*face
    rgb=_blend(rgb,(.64,.245,.18),flush)
    eyes=np.exp(-((np.abs(x)-.036)/.029)**2-((z-(eye_z-.011))/.010)**2)*front
    rgb=_blend(rgb,(.26,.19,.165),eyes*.32)
    jaw=np.exp(-(x/.092)**4-((z-(eye_z-.106))/.040)**4)*front
    lipline=np.exp(-(x/.045)**4-((z-(eye_z-.072))/.009)**2)*front
    moustache=np.exp(-(x/.039)**4-((z-(eye_z-.058))/.008)**2)*front
    # Short patchy beard: tonal shadow plus individual UV-pixel follicles, with lips protected.
    patches=.55+.25*np.sin(x*79+z*83)+.15*np.sin(x*233-z*61)
    beard=np.clip(jaw*(1-lipline)*patches+moustache*.45,0,1)
    rgb=_blend(rgb,(.19,.16,.125),beard*.24)
    follicles=(rng.random(z.shape)>.82).astype(np.float32)*beard*.50
    rgb=_blend(rgb,(.12,.105,.08),follicles)
    grimefield=np.clip(.5+.3*np.sin(x*131+z*103)*np.sin(y*157-z*79),0,1)
    hands=_smooth(.40,.48,np.abs(x))*(1-_smooth(1.17,1.29,z))
    rgb=_blend(rgb,(.20,.145,.08),hands*(.18+.18*grimefield))
    neck=np.exp(-((z-1.48)/.045)**2)*front
    rgb=_blend(rgb,(.28,.20,.12),neck*.12*grimefield)
    # Tiny skin variation preserves the source pores instead of painting flat colors over them.
    mottling=(rng.random(z.shape)-.5)*.018*face
    rgb=np.clip(rgb+mottling[...,None],0,1)
    return rgb


def _weather_shoes(rgb,p,valid,rng):
    z=p[...,2];field=np.clip(.5+.24*np.sin(p[...,0]*131+p[...,1]*171)+.20*np.sin(p[...,1]*333-z*51),0,1)
    mud=(1-_smooth(.035,.145,z))*(.39+.46*field)
    rgb=_blend(rgb,(.17,.125,.075),mud)
    rgb=_blend(rgb,(.37,.31,.22),field*.20)
    return rgb


def _weather_hair(rgb,p,valid,rng):
    # Keep the authored strand texture, but desaturate it and introduce gray strays.
    lum=(rgb*np.array([.2126,.7152,.0722],np.float32)).sum(axis=-1)
    gray=lum[...,None]*np.array([.85,.82,.75],np.float32)
    rgb=rgb*.36+gray*.64
    x,y,z=p[...,0],p[...,1],p[...,2]
    streak=np.maximum(0,np.sin(x*172+y*33+z*15))**18
    side=_smooth(.055,.115,np.abs(x))
    rgb=_blend(rgb,(.54,.51,.45),streak*(.09+.25*side))
    return rgb


def _save_map(array,path,name):
    h,w=array.shape[:2];im=bpy.data.images.new(name+' generated',width=w,height=h,alpha=True)
    im.pixels.foreach_set(np.ascontiguousarray(np.clip(array,0,1),dtype=np.float32).ravel())
    im.update();im.filepath_raw=str(path);im.file_format='PNG';im.save();bpy.data.images.remove(im)
    out=bpy.data.images.load(str(path),check_existing=False);out.name=name;out.pack();return out


def apply_weathering(asset_collection, OUT):
    """Apply deterministic dirty/faded maps; returns generated-map paths for audit."""
    OUT=Path(OUT);texture_dir=OUT/'textures';texture_dir.mkdir(exist_ok=True)
    meshes={o.name:o for o in asset_collection.all_objects if o.type=='MESH'}
    eye=meshes.get('Anatomical eyes')
    eye_z=float(np.mean([v.co.z for v in eye.data.vertices])) if eye else 1.66
    specs=[('Workshirt, belt and denim trousers','clothes',_weather_shirt),
           ('Resident01_BODY','skin',None),('Worn practical shoes','shoes',_weather_shoes),
           ('Short textured hair','hair',_weather_hair)]
    result=[]
    for object_name,label,operation in specs:
        obj=meshes.get(object_name)
        if obj is None:continue
        # BODY's second slot is eyebrow color; do not soil/tint the eyebrow atlas.
        material_index=0;mat=obj.material_slots[material_index].material;node=_image_node(mat)
        if node is None:continue
        original=node.image
        if original.name.startswith('weathered_'):
            # Called on an already-weathered file: prefer packed original source nodes when available.
            continue
        width,height=original.size[:];pixels=np.empty(width*height*4,np.float32);original.pixels.foreach_get(pixels)
        pixels=pixels.reshape((height,width,4));pos,valid=_position_atlas(obj,material_index,width,height)
        rgb=pixels[...,:3].copy();rng=np.random.default_rng(6100+len(result))
        altered=_weather_skin(rgb,pos,valid,rng,eye_z) if label=='skin' else operation(rgb,pos,valid,rng)
        pixels[...,:3]=np.where(valid[...,None],np.clip(altered,0,1),rgb)
        # Fill a narrow image-space bleed around UV islands so seams do not reveal clean pixels.
        for _ in range(3):
            expanded=valid.copy()
            for dy,dx in ((0,1),(0,-1),(1,0),(-1,0)):
                neighbor=np.roll(valid,(dy,dx),(0,1));take=neighbor&~expanded
                shifted=np.roll(pixels,(dy,dx),(0,1));pixels[take]=shifted[take];expanded|=take
            valid=expanded
        path=texture_dir/('weathered_'+label+'.png');image=_save_map(pixels,path,'weathered_'+label)
        node.image=image
        if label=='hair':
            for n in mat.node_tree.nodes:
                if n.type=='MIX_RGB' and n.blend_type=='MULTIPLY':n.inputs[2].default_value=(.30,.27,.23,1)
        if label=='clothes':mat.diffuse_color=(.25,.15,.115,1)
        if label=='shoes':mat.diffuse_color=(.17,.105,.055,1)
        if label=='skin':mat.diffuse_color=(.48,.27,.18,1)
        result.append(str(path))
        print('WEATHER_MAP',label,width,height,'covered pixels',int(valid.sum()))
    return result
