Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$jobs = Get-Content (Join-Path $PSScriptRoot 'ezmaps_asset_prompts.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$cube = Join-Path $root 'Assets/Generated/PixelQuest/cube'
$rug = Join-Path $root 'Assets/Generated/ToyTown/rug'
New-Item -ItemType Directory -Force $cube,$rug | Out-Null
function Resize-Png($source, $path, $width, $height, $opaque, $nearest) {
    $format = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    if ($opaque) { $format = [System.Drawing.Imaging.PixelFormat]::Format24bppRgb }
    $bmp = New-Object System.Drawing.Bitmap $width,$height,$format
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    if ($nearest) { $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor }
    $g.DrawImage($source,[System.Drawing.Rectangle]::new(0,0,$width,$height))
    $g.Dispose()
    $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}
foreach ($job in $jobs) {
    $im = [System.Drawing.Image]::FromFile($job.source)
    if ($job.name.StartsWith('px-')) {
        $grid=64; if ($job.name -eq 'px-cube-top') { $grid=128 }
        $small=Join-Path $root ('tmp/'+$job.name+'-grid.png')
        Resize-Png $im $small $grid $grid $true $true
        if ($job.name -eq 'px-cube-top') {
            # Quantize the sampled map to flat biome colors, including exactly two water blues.
            $pixels = [System.Drawing.Bitmap]::FromFile($small)
            $palette = @('#1558A6','#39A7DB','#79BC31','#19772D','#F3D574','#95958B','#F4F8FF','#A98A4B') | ForEach-Object { [System.Drawing.ColorTranslator]::FromHtml($_) }
            for ($y=0; $y -lt 128; $y++) { for ($x=0; $x -lt 128; $x++) {
                $c=$pixels.GetPixel($x,$y); $best=1000000; $chosen=$palette[0]
                foreach ($p in $palette) { $d=[math]::Pow(($c.R-$p.R),2)+[math]::Pow(($c.G-$p.G),2)+[math]::Pow(($c.B-$p.B),2); if ($d -lt $best) { $best=$d; $chosen=$p } }
                $pixels.SetPixel($x,$y,$chosen)
            } }
            $quantized=Join-Path $root 'tmp/px-cube-top-palette.png'
            $pixels.Save($quantized,[System.Drawing.Imaging.ImageFormat]::Png); $pixels.Dispose()
            $small=$quantized
        }
        $low=[System.Drawing.Image]::FromFile($small)
        Resize-Png $low (Join-Path $cube ($job.name+'.png')) 1024 1024 $true $true
        $low.Dispose()
    } else {
        $w=128; $h=128
        if ($job.name -eq 'toy-lot-p') { $w=64; $h=64 }
        if ($job.name -eq 'toy-fountain') { $w=96; $h=96 }
        if ($job.name -eq 'toy-crosswalk') { $w=64; $h=32 }
        foreach ($scale in 2,3) {
            Resize-Png $im (Join-Path $rug ($job.name+'@'+$scale+'x.png')) ($w*$scale) ($h*$scale) $false $false
        }
    }
    $im.Dispose()
}
$sheet=New-Object System.Drawing.Bitmap 1200,900
$g=[System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#69A83E'))
$rugJobs=@($jobs | Where-Object { $_.transparent })
for ($i=0; $i -lt $rugJobs.Count; $i++) {
    $im=[System.Drawing.Image]::FromFile((Join-Path $rug ($rugJobs[$i].name+'@3x.png')))
    $x=($i%3)*400+(400-$im.Width)/2
    $y=[math]::Floor($i/3)*300+(300-$im.Height)/2
    if ($im.Height -gt 280) { $g.DrawImage($im,[int](($i%3)*400+60),[int]([math]::Floor($i/3)*300+10),280,280) }
    else { $g.DrawImageUnscaled($im,[int]$x,[int]$y) }
    $im.Dispose()
}
$g.Dispose()
$sheet.Save((Join-Path $rug 'vorschau.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
