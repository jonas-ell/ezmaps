Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
public static class TerrainMaterialExport {
  static Color Blend(Color a, Color b, double t) {
    return Color.FromArgb((int)Math.Round(a.R*(1-t)+b.R*t), (int)Math.Round(a.G*(1-t)+b.G*t), (int)Math.Round(a.B*(1-t)+b.B*t));
  }
  public static void Export(string source, string target, string preview) {
    const int n=1024, band=48;
    using(var original=new Bitmap(source))
    using(var tile=new Bitmap(n,n,PixelFormat.Format24bppRgb)) {
      using(var g=Graphics.FromImage(tile)) {
        g.InterpolationMode=InterpolationMode.HighQualityBicubic;
        using(var attrs=new ImageAttributes()) {
          attrs.SetWrapMode(WrapMode.TileFlipXY);
          g.DrawImage(original,new Rectangle(0,0,n,n),0,0,original.Width,original.Height,GraphicsUnit.Pixel,attrs);
        }
      }
      // Smoothly reconcile opposing boundary samples; interiors retain generated brushwork.
      for(int y=0;y<n;y++) for(int d=0;d<band;d++) {
        var a=tile.GetPixel(d,y); var b=tile.GetPixel(n-1-d,y);
        double t=0.5*Math.Pow(1.0-d/(double)band,3);
        tile.SetPixel(d,y,Blend(a,b,t)); tile.SetPixel(n-1-d,y,Blend(b,a,t));
      }
      for(int x=0;x<n;x++) for(int d=0;d<band;d++) {
        var a=tile.GetPixel(x,d); var b=tile.GetPixel(x,n-1-d);
        double t=0.5*Math.Pow(1.0-d/(double)band,3);
        tile.SetPixel(x,d,Blend(a,b,t)); tile.SetPixel(x,n-1-d,Blend(b,a,t));
      }
      for(int p=0;p<n;p++) {
        if(tile.GetPixel(0,p)!=tile.GetPixel(n-1,p) || tile.GetPixel(p,0)!=tile.GetPixel(p,n-1)) throw new Exception("Boundary mismatch");
      }
      tile.Save(target,ImageFormat.Png);
      using(var grid=new Bitmap(3*n,3*n,PixelFormat.Format24bppRgb)) {
        using(var g=Graphics.FromImage(grid)) for(int y=0;y<3;y++) for(int x=0;x<3;x++) g.DrawImageUnscaled(tile,x*n,y*n);
        grid.Save(preview,ImageFormat.Png);
      }
    }
  }
}
'@
$manifest = Get-Content (Join-Path $PSScriptRoot 'prompts.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$previewDir = Join-Path $PSScriptRoot 'vorschau'
New-Item -ItemType Directory -Force $previewDir | Out-Null
foreach ($item in $manifest.PSObject.Properties) {
  $source = [regex]::Match($item.Value.source, 'as (.+?\.png) by default').Groups[1].Value
  $target = Join-Path $PSScriptRoot ($item.Name + '.png')
  $preview = Join-Path $previewDir ($item.Name + '.png')
  [TerrainMaterialExport]::Export($source, $target, $preview)
  Write-Output ($item.Name + ': 1024x1024 RGB; matching opposing edges; 3072x3072 preview')
}
