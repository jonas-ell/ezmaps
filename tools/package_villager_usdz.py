"""Package static Blender-baked geometry and textures using OpenUSD."""
import sys,json,shutil,zipfile
from pathlib import Path
sys.path.insert(0,str(Path('tmp/usd-python').resolve()))
from pxr import Usd,UsdGeom,UsdShade,UsdUtils,Sdf,Gf,Vt
work=Path('tmp/villager-house/export').resolve()
out=Path('Assets/Generated/PixelQuest/3d').resolve()
geometry=json.loads((work/'geometry.json').read_text())
for variant in ['oak','spruce','birch','sand']:
    folder=work/variant
    stage=Usd.Stage.CreateNew(str(folder/'house.usdc'))
    root=UsdGeom.Xform.Define(stage,'/House')
    stage.SetDefaultPrim(root.GetPrim())
    UsdGeom.SetStageUpAxis(stage,UsdGeom.Tokens.y)
    UsdGeom.SetStageMetersPerUnit(stage,1)
    mats={}
    for file in sorted(folder.glob('texture_*.png')):
        i=int(file.stem.split('_')[1]); path='/House/Materials/M%d'%i
        mat=UsdShade.Material.Define(stage,path)
        pbr=UsdShade.Shader.Define(stage,path+'/Surface'); pbr.CreateIdAttr('UsdPreviewSurface')
        pbr.CreateInput('roughness',Sdf.ValueTypeNames.Float).Set(1)
        pbr.CreateInput('metallic',Sdf.ValueTypeNames.Float).Set(0)
        pbr.CreateInput('opacityThreshold',Sdf.ValueTypeNames.Float).Set(.05)
        tex=UsdShade.Shader.Define(stage,path+'/Texture'); tex.CreateIdAttr('UsdUVTexture')
        tex.CreateInput('file',Sdf.ValueTypeNames.Asset).Set(Sdf.AssetPath(file.name))
        tex.CreateInput('sourceColorSpace',Sdf.ValueTypeNames.Token).Set('sRGB')
        tex.CreateInput('wrapS',Sdf.ValueTypeNames.Token).Set('repeat')
        tex.CreateInput('wrapT',Sdf.ValueTypeNames.Token).Set('repeat')
        # Filtering is renderer-specific; the SceneKit exporter enforces nearest.
        tex.GetPrim().SetCustomDataByKey('requestedMinFilter','nearest')
        tex.GetPrim().SetCustomDataByKey('requestedMagFilter','nearest')
        st=UsdShade.Shader.Define(stage,path+'/UV'); st.CreateIdAttr('UsdPrimvarReader_float2')
        st.CreateInput('varname',Sdf.ValueTypeNames.Token).Set('st')
        tex.CreateInput('st',Sdf.ValueTypeNames.Float2).ConnectToSource(st.ConnectableAPI(),'result')
        pbr.CreateInput('diffuseColor',Sdf.ValueTypeNames.Color3f).ConnectToSource(tex.ConnectableAPI(),'rgb')
        pbr.CreateInput('opacity',Sdf.ValueTypeNames.Float).ConnectToSource(tex.ConnectableAPI(),'a')
        mat.CreateSurfaceOutput().ConnectToSource(pbr.ConnectableAPI(),'surface')
        mats[i]=mat
    for i,g in enumerate(geometry):
        m=UsdGeom.Mesh.Define(stage,'/House/Mesh_%03d'%i)
        m.CreatePointsAttr(g['points']); m.CreateFaceVertexCountsAttr([3]*(len(g['points'])//3))
        m.CreateFaceVertexIndicesAttr(list(range(len(g['points']))))
        m.CreateSubdivisionSchemeAttr('none'); m.CreateDoubleSidedAttr(True)
        uv=UsdGeom.PrimvarsAPI(m).CreatePrimvar('st',Sdf.ValueTypeNames.TexCoord2fArray,UsdGeom.Tokens.faceVarying)
        uv.Set(g['uv'])
        normals=[]
        for t in range(0,len(g['points']),3):
            a,b,c=[Gf.Vec3f(*p) for p in g['points'][t:t+3]]
            n=Gf.Cross(b-a,c-a).GetNormalized(); normals.extend([n]*3)
        m.CreateNormalsAttr(normals); m.SetNormalsInterpolation('faceVarying')
        UsdShade.MaterialBindingAPI.Apply(m.GetPrim()).Bind(mats[g['material']])
    stage.GetRootLayer().Save()
    dest=out/('villager-house-'+variant+'.usdz')
    assert UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(folder/'house.usdc')),str(dest))
    check=Usd.Stage.Open(str(dest)); assert check
    assert not any(a.GetNumTimeSamples() for p in check.Traverse() for a in p.GetAttributes())
    with zipfile.ZipFile(dest) as z:
        assert len([n for n in z.namelist() if n.endswith('.png')])==14
    print(variant,dest.stat().st_size,'bytes, embedded textures, static')
shutil.copyfile(out/'villager-house-oak.usdz',out/'villager-house.usdz')
