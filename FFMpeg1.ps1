$inFile = "X:\System\tmp\_download\Pandora Peaks\Pandora Peaks - A Peek of Pandora.avi"
$tempDir = "C:\Temp"



# [Parsed_cropdetect_0 @ 000001534c893a80] x1:0 x2:511 y1:0 y2:383 w:512 h:384 x:0 y:0 pts:3574 t:149.065732 crop=512:384:0:0
# [Parsed_cropdetect_0 @ 000001534c893a80] x1:0 x2:511 y1:0 y2:383 w:512 h:384 x:0 y:0 pts:3575 t:149.107441 crop=512:384:0:0


$STDOUT_Probe = Join-Path -Path $($tempDir) -ChildPath "so_probe.txt"
$STDOUT_PJSON = Join-Path -Path $($tempDir) -ChildPath "so_json.txt"
$ArgList_Probe = " -v error -hide_banner -of default=noprint_wrappers=0 -print_format json -show_streams -show_format `"$($inFile)`" "
Start-Process -FilePath ffprobe -ArgumentList $ArgList_Probe -Wait -NoNewWindow -RedirectStandardOutput $STDOUT_PJSON

$vinfo = ConvertFrom-Json ((Get-Content $STDOUT_PJSON) -join '')
Remove-Item $STDOUT_PJSON

$Flen = $vinfo.format.duration
$CLen = $Flen / 2
if ($CLen -gt 120) { $Clen = 120}

$STDOUT_FILE = Join-Path -Path $($tempDir) -ChildPath "stdout.txt"
$ArgumentList = "-i `"$($inFile)`" -ss $($Clen) -vframes 10 -vf cropdetect -f null out.mkv "
Start-Process -FilePath ffmpeg -ArgumentList $ArgumentList -Wait -NoNewWindow -RedirectStandardError $STDOUT_FILE

Get-Content -LiteralPath $STDOUT_FILE | Where-Object { $_.Length -gt 18 -and $_.Substring(0,18) -ieq '[Parsed_cropdetect' } | Select-Object {
        $global:crop = (($_.Split(" "))[13]).Split("=")[1]
}
#)


 #  -qmin:v 19 -qmax:v 14

 # -loglevel debug

$ArgumentList = '-hwaccel_output_format cuda -i ''' + $inFile + ''' -vf "yadif=1:-1:0,scale=w=1024:h=720:force_original_aspect_ratio=decrease,crop=' + $crop + `
        '" -c:v hevc_nvenc -preset slow -rc vbr -multipass fullres -b:v 1M -maxrate:v 6M  P:\_Captured\DVD-BLU\UNNAMED_DISC6\YourCroppedMovie.mp4'

$VerbosePreference="continue"
Write-Verbose "FFmpeyyg; $($ArgumentList)"

        Start-Process -FilePath ffmpeg -ArgumentList $ArgumentList -Wait -NoNewWindow

