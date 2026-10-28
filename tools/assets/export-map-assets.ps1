param([string]$Sources = 'Assets/Generated/map-asset-sources.json', [switch]$Force)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
public static class MapAssetExport {
 public static void MatchEdges(Bitmap image) {
  int w=image.Width,h=image.Height;
  for(int y=0;y<h;y++) image.SetPixel(w-1,y,image.GetPixel(0,y));
  for(int x=0;x<w;x++) image.SetPixel(x,h-1,image.GetPixel(x,0));
 }
 public static Bitmap Resize(Image src, int w, int h) {
  var dst = new Bitmap(w,h,PixelFormat.Format32bppArgb);
  using(var g=Graphics.FromImage(dst)) {
   g.CompositingMode=CompositingMode.SourceCopy;
   g.InterpolationMode=InterpolationMode.HighQualityBicubic;
   g.PixelOffsetMode=PixelOffsetMode.HighQuality;
   using(var attrs=new ImageAttributes()) {
    attrs.SetWrapMode(WrapMode.TileFlipXY);
    g.DrawImage(src,new Rectangle(0,0,w,h),0,0,src.Width,src.Height,GraphicsUnit.Pixel,attrs);
   }
  }
  return dst;
 }
 public static Bitmap Periodic(Bitmap src, double opacity) {
  int w=src.Width,h=src.Height;
  var dst=new Bitmap(w,h,PixelFormat.Format32bppArgb);
  for(int y=0;y<h;y++) for(int x=0;x<w;x++) {
   Color[] c={src.GetPixel(x,y),src.GetPixel(w-1-x,y),src.GetPixel(x,h-1-y),src.GetPixel(w-1-x,h-1-y)};
   double a=0,r=0,g=0,b=0;
   foreach(var p in c){a+=p.A;r+=p.R*p.A;g+=p.G*p.A;b+=p.B*p.A;}
   dst.SetPixel(x,y,a==0?Color.Transparent:Color.FromArgb((int)Math.Round(a/4*opacity),(int)Math.Round(r/a),(int)Math.Round(g/a),(int)Math.Round(b/a)));
  }
  return dst;
 }
}
'@
$specs = Get-Content 'Assets/Generated/map-asset-prompts.json' -Raw | ConvertFrom-Json
$sourceMap = Get-Content $Sources -Raw | ConvertFrom-Json
$report = @()
foreach ($asset in $specs) {
 $property = $sourceMap.PSObject.Properties[$asset.name]
 if (-not $property) { continue }
 $folder = Join-Path ('Assets/Generated/' + $asset.style) $asset.group
 New-Item -ItemType Directory -Force -Path $folder | Out-Null
 $masterPath = Join-Path $folder ($asset.name + '-master.png')
 if ((Test-Path -LiteralPath $masterPath) -and -not $Force) { continue }
 $source = [System.Drawing.Bitmap]::FromFile($property.Value)
 $master = [MapAssetExport]::Resize($source,1024,1024)
 $source.Dispose()
 if ($asset.tile) {
  $opacity = if ($asset.name -eq 'paper-tile') {0.16} elseif ($asset.name -eq 'hill-hatch') {0.45} elseif ($asset.name -eq 'water-edge') {0.32} else {0.85}
  $periodic = [MapAssetExport]::Periodic($master,$opacity)
  $master.Dispose()
  $master = $periodic
 }
 $master.Save($masterPath,[System.Drawing.Imaging.ImageFormat]::Png)
 foreach ($scale in 1,2,3) {
  $suffix = if ($scale -eq 1) {''} else {'@' + $scale + 'x'}
  $file = Join-Path $folder ($asset.name + $suffix + '.png')
  $exportSource = $master
  if ($asset.w -ne $asset.h) {
   $cropHeight = [int](1024 * $asset.h / $asset.w)
   $cropRect = New-Object System.Drawing.Rectangle(0,([int]((1024-$cropHeight)/2)),1024,$cropHeight)
   $exportSource = $master.Clone($cropRect,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  }
  $bitmap = [MapAssetExport]::Resize($exportSource,($asset.w*$scale),($asset.h*$scale))
  if ($exportSource -ne $master) { $exportSource.Dispose() }
  if ($asset.tile) { [MapAssetExport]::MatchEdges($bitmap) }
  $bitmap.Save($file,[System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
 }
 $master.Dispose()
 $report += $asset.name
}
Write-Output ('Exported ' + $report.Count + ' asset families.')
