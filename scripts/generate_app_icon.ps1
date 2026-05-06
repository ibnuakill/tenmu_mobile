$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

function New-RoundedRectPath {
  param(
    [System.Drawing.RectangleF]$Rect,
    [float]$Radius
  )

  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $diameter = $Radius * 2

  $path.AddArc($Rect.X, $Rect.Y, $diameter, $diameter, 180, 90)
  $path.AddArc($Rect.Right - $diameter, $Rect.Y, $diameter, $diameter, 270, 90)
  $path.AddArc($Rect.Right - $diameter, $Rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
  $path.AddArc($Rect.X, $Rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
  $path.CloseFigure()

  return $path
}

function Save-ScaledPng {
  param(
    [System.Drawing.Bitmap]$Source,
    [int]$Width,
    [int]$Height,
    [string]$OutputPath
  )

  $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $graphics.DrawImage($Source, 0, 0, $Width, $Height)
  $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose()
  $bitmap.Dispose()
}

function Ensure-Directory {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function New-TenMuIconBitmap {
  param([int]$Size)

  $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.Clear([System.Drawing.Color]::FromArgb(255, 14, 35, 41))

  $gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.PointF(140, 80)),
    (New-Object System.Drawing.PointF(920, 980)),
    ([System.Drawing.Color]::FromArgb(255, 13, 18, 31)),
    ([System.Drawing.Color]::FromArgb(255, 19, 96, 98))
  )
  $graphics.FillRectangle($gradient, 0, 0, $Size, $Size)

  $glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(42, 129, 247, 255))
  $graphics.FillEllipse($glowBrush, 180, 180, 680, 680)

  $pinShadow = New-Object System.Drawing.Drawing2D.GraphicsPath
  $pinShadow.AddEllipse(278, 190, 468, 468)
  $pinShadow.AddPolygon(@(
      (New-Object System.Drawing.PointF(512, 862)),
      (New-Object System.Drawing.PointF(338, 514)),
      (New-Object System.Drawing.PointF(686, 514))
    ))
  $graphics.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(36, 0, 0, 0))), $pinShadow)

  $pinPath = New-Object System.Drawing.Drawing2D.GraphicsPath
  $pinPath.AddEllipse(288, 162, 448, 448)
  $pinPath.AddPolygon(@(
      (New-Object System.Drawing.PointF(512, 808)),
      (New-Object System.Drawing.PointF(352, 480)),
      (New-Object System.Drawing.PointF(672, 480))
    ))
  $graphics.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 243, 248, 250))), $pinPath)

  $innerCircle = New-Object System.Drawing.RectangleF(356, 234, 312, 312)
  $graphics.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 20, 30, 43))), $innerCircle)

  $awningPoints = @(
    (New-Object System.Drawing.PointF(405, 366)),
    (New-Object System.Drawing.PointF(445, 318)),
    (New-Object System.Drawing.PointF(579, 318)),
    (New-Object System.Drawing.PointF(619, 366))
  )
  $graphics.FillPolygon((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 88, 230, 213))), $awningPoints)

  $awningBand = New-Object System.Drawing.RectangleF(404, 364, 216, 42)
  $graphics.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 243, 248, 250))), $awningBand)

  $stripeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 88, 230, 213))
  foreach ($x in 418, 460, 502, 544, 586) {
    $graphics.FillRectangle($stripeBrush, $x, 364, 18, 42)
  }

  $storeBody = New-Object System.Drawing.RectangleF(426, 408, 172, 92)
  $graphics.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 243, 248, 250))), (New-RoundedRectPath -Rect $storeBody -Radius 24))

  $doorBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 20, 30, 43))
  $graphics.FillPath($doorBrush, (New-RoundedRectPath -Rect (New-Object System.Drawing.RectangleF(490, 432, 44, 68)) -Radius 14))
  $windowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 20, 30, 43))
  $graphics.FillPath($windowBrush, (New-RoundedRectPath -Rect (New-Object System.Drawing.RectangleF(442, 432, 34, 44)) -Radius 10))
  $graphics.FillPath($windowBrush, (New-RoundedRectPath -Rect (New-Object System.Drawing.RectangleF(548, 432, 34, 44)) -Radius 10))

  $sparkBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 255, 255, 255))
  $graphics.FillEllipse($sparkBrush, 714, 214, 54, 54)
  $graphics.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(170, 255, 255, 255))), 774, 270, 24, 24)

  $graphics.Dispose()
  $gradient.Dispose()
  $glowBrush.Dispose()
  $pinShadow.Dispose()
  $pinPath.Dispose()
  $stripeBrush.Dispose()
  $doorBrush.Dispose()
  $windowBrush.Dispose()
  $sparkBrush.Dispose()

  return $bitmap
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$brandingDir = Join-Path $projectRoot 'assets\branding'
Ensure-Directory $brandingDir

$masterPath = Join-Path $brandingDir 'app_icon.png'
$customPath = Join-Path $brandingDir 'app_icon_custom.png'
$size = 1024

if (Test-Path $customPath) {
  $sourceImage = [System.Drawing.Image]::FromFile($customPath)
  $bitmap = New-Object System.Drawing.Bitmap($size, $size)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
  $graphics.Dispose()
  $sourceImage.Dispose()
} else {
  $bitmap = New-TenMuIconBitmap -Size $size
}

$bitmap.Save($masterPath, [System.Drawing.Imaging.ImageFormat]::Png)

$androidTargets = @{
  'android\app\src\main\res\mipmap-mdpi\ic_launcher.png' = 48
  'android\app\src\main\res\mipmap-hdpi\ic_launcher.png' = 72
  'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' = 96
  'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' = 144
  'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' = 192
}

foreach ($item in $androidTargets.GetEnumerator()) {
  $path = Join-Path $projectRoot $item.Key
  Save-ScaledPng -Source $bitmap -Width $item.Value -Height $item.Value -OutputPath $path
}

$iosTargets = @{
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@1x.png' = 20
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@2x.png' = 40
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@3x.png' = 60
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@1x.png' = 29
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@2x.png' = 58
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@3x.png' = 87
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@1x.png' = 40
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@2x.png' = 80
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@3x.png' = 120
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@2x.png' = 120
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png' = 180
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@1x.png' = 76
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@2x.png' = 152
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-83.5x83.5@2x.png' = 167
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png' = 1024
}

foreach ($item in $iosTargets.GetEnumerator()) {
  $path = Join-Path $projectRoot $item.Key
  Save-ScaledPng -Source $bitmap -Width $item.Value -Height $item.Value -OutputPath $path
}

$launchImageDir = Join-Path $projectRoot 'ios\Runner\Assets.xcassets\LaunchImage.imageset'
Ensure-Directory $launchImageDir

$launchTargets = @{
  'LaunchImage.png' = 180
  'LaunchImage@2x.png' = 360
  'LaunchImage@3x.png' = 540
}

foreach ($item in $launchTargets.GetEnumerator()) {
  $path = Join-Path $launchImageDir $item.Key
  Save-ScaledPng -Source $bitmap -Width $item.Value -Height $item.Value -OutputPath $path
}

$bitmap.Dispose()

Write-Output "Generated app icon and splash assets at $masterPath"
