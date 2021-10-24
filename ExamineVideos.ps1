
function ExamineVideo {

    Param (
            [string] $SrcPath,
            [int] $rDepth = 0,
            [string] $DestPath,
            [string] $TempDir = "C:\Temp"
    )

 # -Recurse -file -include *.avi,*.divx,*.flv,*.m1v,*.m4v,*.mkv,*.mov,*.mp4,*.mpe,*.mpg,*.mpeg,*.rm,*.wmv

    Begin {
        $targetExtensions = @('.asf','.avi','.divx','.flv','.m1v','.m2v','.m4v','.mkv','.mov','.mp4','.mpe','.mpg','.mpeg','.rm',',ram','.wmv','.ts','.vob')
        $copyExtensions   = @('.jpg','.jpeg','.gif')
        Get-ChildItem -Path $SrcPath -File | Select-Object {
            $vFile = $_
            $vfExtension = (Split-Path $_.FullName -extension)
            if ($vfExtension -in $targetExtensions) {
                Write-Host "OK!   $($vFile.FullName)"
            }
            elseif ($vfExtension -in $copyExtensions) {
                Write-Host "Copy  $($vFile.FullName)"
                continue
            }
            else {
                Write-Host "No    $($vFile.FullName)"
                continue
            }

            #   Prepare the full source and destination path
            $OVideoPath = Join-Path -Path $DestPath -ChildPath (Split-Path $SrcPath -Leaf)
            $OVideoPath = $OVideoPath -replace (Split-Path $SrcPath -extension), '.mp4'



            #   Detect any interlacing in the video
            #
            $vInterlace = [PSCustomObject]@{
                Interlaced  = 0
                RepeatedNeither         = 0
                RepeatedTop             = 0
                RepeatedNBottom         = 0
                SingleFrameTFF          = 0
                SingleFrameBFF          = 0
                SingleFrameProgressive     = 0
                SingleFrameUndetermined = 0
                MultiFrameTFF           = 0
                MultiFrameBFF           = 0
                MultiFrameProgressive       = 0
                MultiFrameUndetermined  = 0
            }
            try {
                $iOut = (ffmpeg -hide_banner -i ""$($vFile.FullName)"" -vf idet,cropdetect  -frames:v 1000  -an -sn -f rawvideo -y nul 2>&1)
                $iOut | Where-Object {$_.ToString() -ilike '?Parsed_idet*'} | Select-Object {
                    #Write-Host $_.ToString()
                    if ($_.ToString() -match 'Parsed_idet.+?Repeated Fields: Neither: +?(\d+?) Top: +?(\d+?) Bottom: *?(\d+?)[!\d]*$') {
                        $vInterlace.RepeatedNeither = $Matches[1]
                        $vInterlace.RepeatedTop     = $Matches[2]
                        $vInterlace.RepeatedNBottom = $Matches[3]
                    }
                    elseif ($_.ToString() -match 'Parsed_idet.+?Single frame detection: TFF: +?(\d+?) BFF: +?(\d+?) Progressive: *?(\d+?) Undetermined: *?(\d+?)[!\d]*$') {
                        $vInterlace.SingleFrameTFF      = $Matches[1]
                        $vInterlace.SingleFrameBFF      = $Matches[2]
                        $vInterlace.SingleFrameProgressive = $Matches[3]
                        $vInterlace.SingleFrameUndetermined = $Matches[4]
                    }
                    elseif ($_.ToString() -match 'Parsed_idet.+?Multi frame detection: TFF: +?(\d+?) BFF: +?(\d+?) Progressive: *?(\d+?) Undetermined: *?(\d+?)[!\d]*$') {
                        $vInterlace.MultiFrameTFF           = $Matches[1]
                        $vInterlace.MultiFrameBFF           = $Matches[2]
                        $vInterlace.MultiFrameProgressive  = $Matches[3]
                        $vInterlace.MultiFrameUndetermined = $Matches[4]
                    }
                }

                if ((([int]$vInterlace.SingleFrameBFF + [int]$vInterlace.SingleFrameTFF) * 20) -gt [int]$vInterlace.SingleFrameProgressive ) {
                    $vInterlace.Interlaced = 1
                }
                elseif ((([int]$vInterlace.MultiFrameBFF + [int]$vInterlace.MultiFrameTFF) * 20) -gt [int]$vInterlace.MultiFrameProgressive ) {
                    $vInterlace.Interlaced = 1
                }
                if ($vInterlace.Interlaced -gt 0) {Write-Host "Interlaced!"}

                # Now look for any need for cropping a video
                #
                $CropAreas = @{}
                $iOut | Where-Object {$_.ToString() -ilike '?Parsed_cropdetect*'} | Select-Object {
                    $ca = $_.ToString().Split(" crop=")[1]
                    if ($ca.Length -gt 0 -and -not $CropAreas.ContainsKey($ca)) {
                        $CropAreas[$ca] = $ca
                    }
                }
           }
            catch {
                $vInterlace.Interlaced = -1
            }

            #  Use FFPROBE to inspect the file for its current makeup.  Results are placed into an object constructed from the
            #  resulting JSON  from FFPROBE
            #
            $STDOUT_Probe = Join-Path -Path $($TempDir) -ChildPath "so_probe.txt"
            $STDOUT_PJSON = Join-Path -Path $($TempDir) -ChildPath "so_json.txt"
            $ArgList_Probe = " -v error -hide_banner -of default=noprint_wrappers=0 -print_format json -show_streams -show_format `"$($vFile.FullName)`" "
            Start-Process -FilePath ffprobe -ArgumentList $ArgList_Probe -Wait -NoNewWindow -RedirectStandardOutput $STDOUT_PJSON
            $vinfo = ConvertFrom-Json ((Get-Content $STDOUT_PJSON) -join '')
            Remove-Item $STDOUT_PJSON

            # Now examine the video attributes

            $strmVideo = ($vInfo.streams | Where-Object codec_type -eq 'video')
            try {
                $vFileVideo = [PSCustomObject]@{
                    CodecName = $strmVideo.codec_name
                    CodecLongName = $strmVideo.codec_long_name
                    Width = $strmVideo.width
                    Height = $strmVideo.height
                    SampleAspectRatio = $strmVideo.sample_aspect_ratio
                    DispAspectRatio = $strmVideo.display_aspect_ratio
                    PixFmt = $strmVideo.pix_fmt
                    FieldOrder = $strmVideo.field_order
                    AvgFrameRate = $strmVideo.avg_frame_rate
                    FrameRate = (Invoke-Expression $strmVideo.avg_frame_rate)
                    Duration = $strmVideo.duration
                    BitRate = $strmVideo.bit_rate
                    NbFrames = $strmVideo.nb_frames
                }
            }
            catch {
                $a=1
            }

            $vFileAudio = $null
            $strmAudio = ($vInfo.streams | Where-Object codec_type -eq 'audio')
            if ($strmAudio) {
                $vFileAudio = [PSCustomObject]@{
                    CodecName = $strmAudio.codec_name
                    CodecLongName = $strmAudio.codec_long_name
                    CodecTimeBase = $strmAudio.time_base
                    SampleRate = $strmAudio.sample_rate
                    SampleFmt = $strmAudio.sample_fmt
                    Channels = $strmAudio.channels
                    ChannelLayout = $strmAudio.channel_layout
                    Duration = $strmAudio.duration
                    BitRate = $strmAudio.bit_rate
                    NbFrames = $strmAudio.nb_frames
                }
            }

            #  Now assemble global clip information
            try {
                # Get the full file attributes
                $vFileInfo = [PSCustomObject]@{
                    FileName = $vInfo.format.filename
                    FormatName = $vInfo.format.format_name
                    FormatLongName = $vInfo.format.format_long_name
                    Duration = $vInfo.format.duration
                    Size = $vInfo.format.size
                    BitRate = $vInfo.format.bit_rate
                    VideoInfo = $vFileVideo
                    AudioInfo = $vFileAudio
                }
            }
            catch {
                $e = $_
            }

            #   Start building the filter chain we will need for this video
            #
            $oFilters = @();


            #   Now test the video for any cropping needs
            #
            $FullSize = "$($vFileVideo.Width):$($vFileVideo.Height):0:0"
            if (-not $CropAreas.ContainsKey($FullSize)) {

            }

            $a = 1
        }








        #  Now use FFMPEG to scan portions of the video to find the cropping bounds
        #
        # $Flen = $vinfo.format.duration
        # $CLen = [Math]::Floor($Flen / 2)
        # if ($CLen -gt 120) { $Clen = 120}

        # $fps = (Invoke-expression $vinfo.streams[0].avg_frame_rate)

        # $STDOUT_FILE = Join-Path -Path $($tempDir) -ChildPath "stdout.txt"
        # $ArgumentList = "-i `"$($VideoPath)`" -ss $($Clen) -vframes 10 -vf cropdetect -f null out.mkv "
        # Start-Process -FilePath ffmpeg -ArgumentList $ArgumentList -Wait -NoNewWindow -RedirectStandardError $STDOUT_FILE

        # Get-Content -LiteralPath $STDOUT_FILE | Where-Object { $_.Length -gt 18 -and $_.Substring(0,18) -ieq '[Parsed_cropdetect' } | Select-Object {
        #         $global:cropSize = (($_.Split(" "))[13]).Split("=")[1]
        # }
        # Remove-Item $STDOUT_FILE

        #  Now build the options and parameters needed to do the final transcode operation
        #
        $oFilters = @();
        #$oFilters += 'yadif=1:-1:0'
        $oFilters += 'crop=' + $cropSize
        $oFilters += 'scale_cuda=w=1024:h=720:force_original_aspect_ratio=decrease'


    # yadif=1:-1:0,scale=w=1024:h=720:force_original_aspect_ratio=decrease,crop=' + $crop

        $OVideoPath = Join-Path -Path $DestPath -ChildPath (Split-Path $SrcPath -Leaf)
        $OVideoPath = $OVideoPath -replace (Split-Path $SrcPath -extension), '.mp4'
        $oFilter = '-vf "' + ($oFilters -join ',') + '" '
    }

}

ExamineVideo -SrcPath "X:\System\tmp\mpg\tmpg\A\Alexis Love" -rDepth 0 -DestPath "C:\Temp"
$a = "Stop"