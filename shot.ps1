Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile("D:\MileLogV2_cross_platform\milelog_flutter\screen.png")
$ratio = 1200 / $img.Height
$newW = [int]($img.Width * $ratio)
$bmp = New-Object System.Drawing.Bitmap($newW, 1200)
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.DrawImage($img, 0, 0, $newW, 1200)
$bmp.Save("D:\MileLogV2_cross_platform\milelog_flutter\screen_small.png")
$img.Dispose()
$bmp.Dispose()
