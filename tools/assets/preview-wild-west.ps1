$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$folder = Join-Path $PWD 'Assets/Generated/WildWest'
$specs = Get-Content (Join-Path $folder 'manifest.json') -Raw | ConvertFrom-Json
$preview = New-Object System.Drawing.Bitmap(1200,1050)
$g = [System.Drawing.Graphics]::FromImage($preview)
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#E4C9A8'))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = New-Object System.Drawing.Font('Segoe UI',10)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#3A2D20'))
$i = 0
foreach ($a in ($specs | Where-Object { -not $_.tile })) {
 $path = Join-Path $folder ($a.name+'.png')
 if (-not (Test-Path -LiteralPath $path)) { continue }
 $x=20+($i%6)*200; $y=20+[Math]::Floor($i/6)*125
 $im=[System.Drawing.Image]::FromFile($path)
 $g.DrawImage($im,[int]$x,[int]($y+20),[int]$a.w,[int]$a.h)
 $large=[System.Drawing.Image]::FromFile((Join-Path $folder ($a.name+'@2x.png')))
 $g.DrawImage($large,[int]($x+70),[int]$y,[int]($a.w*2),[int]($a.h*2))
 $g.DrawString($a.name,$font,$brush,[single]$x,[single]($y+100))
 $im.Dispose(); $large.Dispose(); $i++
}
$i=0
foreach ($a in ($specs | Where-Object tile)) {
 $im=[System.Drawing.Image]::FromFile((Join-Path $folder ($a.name+'.png')))
 $g.DrawString($a.name+' / repeated at native size',$font,$brush,[single](20+$i*400),[single]550)
 $texture=New-Object System.Drawing.TextureBrush($im)
 $texture.TranslateTransform((20+$i*400),580)
 $g.FillRectangle($texture,(20+$i*400),580,380,440)
 $texture.Dispose(); $im.Dispose(); $i++
}
$preview.Save((Join-Path $folder 'refresh-check.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $font.Dispose(); $brush.Dispose(); $preview.Dispose()
