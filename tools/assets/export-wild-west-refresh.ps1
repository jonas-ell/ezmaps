param([string]$Sources = 'Assets/Generated/WildWest/refresh-sources.json')
$ErrorActionPreference = 'Stop'
# Reuse the established RGBA resampler; never run its export loop here.
$exporter = Get-Content "$PSScriptRoot/export-map-assets.ps1" -Raw
$definitions = $exporter.Substring($exporter.IndexOf('Add-Type'), $exporter.IndexOf('$specs =') - $exporter.IndexOf('Add-Type'))
Invoke-Expression $definitions
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System.Drawing;
using System.Drawing.Imaging;
public static class WestTexture {
 public static void Ink(Bitmap image, int r, int g, int b, double gain) {
  for(int y=0;y<image.Height;y++) for(int x=0;x<image.Width;x++) {
   var c=image.GetPixel(x,y);
   image.SetPixel(x,y,Color.FromArgb(System.Math.Min(255,(int)System.Math.Round(c.A*gain)),r,g,b));
  }
 }
 public static Bitmap Repeat(Bitmap source, double opacity) {
  int w=source.Width,h=source.Height;
  var result=new Bitmap(w,h,PixelFormat.Format32bppArgb);
  // Reflect one quadrant without averaging separate pen strokes together.
  for(int y=0;y<h;y++) for(int x=0;x<w;x++) {
   var c=source.GetPixel(x<w/2?x:w-1-x,y<h/2?y:h-1-y);
   result.SetPixel(x,y,Color.FromArgb((int)System.Math.Round(c.A*opacity),c.R,c.G,c.B));
  }
  return result;
 }
}
'@
$records = Get-Content $Sources -Raw | ConvertFrom-Json
$folder = Join-Path $PWD 'Assets/Generated/WildWest'
foreach ($record in $records) {
 $source = [System.Drawing.Bitmap]::FromFile($record.source)
 $master = [MapAssetExport]::Resize($source,1024,1024)
 $source.Dispose()
 if ($record.name -like 'forest-stamp-*') { [WestTexture]::Ink($master,58,45,32,1.5) }
 if ($record.name -eq 'waypoint-x') { [WestTexture]::Ink($master,168,38,31,1.0) }
 if ($record.tile) {
  # Reflection makes the whole field periodic without fading the ink through averaging.
  $opacity = switch ($record.name) { 'paper-tile' {0.48} 'hill-hatch' {0.52} 'water-edge' {0.41} }
  $periodic = [WestTexture]::Repeat($master,$opacity)
  $master.Dispose()
  $master = $periodic
  [MapAssetExport]::MatchEdges($master)
 }
 $master.Save((Join-Path $folder ($record.name+'-master.png')),[System.Drawing.Imaging.ImageFormat]::Png)
 foreach ($scale in 1,2,3) {
  $suffix = if ($scale -eq 1) {''} else {'@'+$scale+'x'}
  $export = [MapAssetExport]::Resize($master,($record.size*$scale),($record.size*$scale))
  if ($record.tile) { [MapAssetExport]::MatchEdges($export) }
  $export.Save((Join-Path $folder ($record.name+$suffix+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)
  $export.Dispose()
 }
 $master.Dispose()
 Write-Output ('Exported '+$record.name)
}
