"""Use the existing EzMaps SSH build gate to export and retrieve native SceneKit assets."""
import base64,io,re,subprocess,tarfile
from pathlib import Path

root=Path(__file__).resolve().parent.parent
folder=root/'Assets/Generated/PixelQuest/3d'
files=[root/'tools/mac_build.sh',root/'tools/export_villager_scn.swift',*folder.glob('villager-house*.usdz')]
archive=io.BytesIO()
with tarfile.open(fileobj=archive,mode='w') as tar:
    for path in files:
        data=path.read_bytes()
        if path.suffix in ('.sh','.swift'): data=data.replace(b'\r\n',b'\n')
        info=tarfile.TarInfo(path.relative_to(root).as_posix()); info.size=len(data)
        tar.addfile(info,io.BytesIO(data))
    info=tarfile.TarInfo('tools/.do_scene_assets'); info.size=0
    tar.addfile(info,io.BytesIO())
ssh=['ssh','-o','BatchMode=yes','-o','ConnectTimeout=10','mac-ezmaps']
subprocess.run(ssh+['extract'],input=archive.getvalue(),check=True)
result=subprocess.run(ssh+['build'],capture_output=True)
output=result.stdout.decode('utf-8',errors='replace')
matches=list(re.finditer(r'SCN_ASSET_BEGIN (villager-house(?:-(?:oak|spruce|birch|sand))?\.scn)\s+([A-Za-z0-9+/=\s]+?)SCN_ASSET_END',output))
summary=re.sub(r'SCN_ASSET_BEGIN .*?SCN_ASSET_END','[asset payload retrieved]',output,flags=re.S)
print(summary[-10000:])
if result.stderr: print(result.stderr.decode('utf-8',errors='replace')[-2000:])
if len(matches)!=5: raise RuntimeError('Expected five validated SCN files; received %d'%len(matches))
for match in matches:
    data=base64.b64decode(re.sub(r'\s','',match[2]),validate=True)
    assert data.startswith(b'bplist00'), 'Not a native archived SceneKit scene'
    (folder/match[1]).write_bytes(data)
    print('Saved',match[1],len(data),'bytes')
