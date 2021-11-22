
function Compare-OldNewVideos {

    Param (
            [string] $SrcPath,
            [int] $rDepth = 0,
            [string] $DestPath,
            [string] $TempDir = "C:\Temp"
    )

 # -Recurse -file -include *.avi,*.divx,*.flv,*.m1v,*.m4v,*.mkv,*.mov,*.mp4,*.mpe,*.mpg,*.mpeg,*.rm,*.wmv

    Begin {

        function WriteToLogFile ($message)
        {
            $message +" - "+ (Get-Date).ToString() >> $LogFileName
        }

        $targetExtensions = @('.asf','.avi','.divx','.flv','.m1v','.m2v','.m4v','.mkv','.mov','.mp4','.mpe','.mpeg','.mpg','.rm',',ram','.wmv','.ts','.vob')
        $copyExtensions   = @('.jpg','.jpeg','.gif')


        #   Prepare the log file
        #
        $LogFileName = $TempDir + "\CompareOldNewVideos-$(Get-Date -Format "yyyyMMdd-HHmm").txt"
        if(Test-Path -Path $LogFileName)
        {
            Remove-Item $LogFileName
        }
        $logFile = New-Item -itemType File -Path $TempDir -Name (Split-Path -path $LogFileName -leaf)

        WriteToLogFile "Start Logging"

        #   Get info on the input/output directories
        #
        $SPathInfo = Get-ItemProperty -path $SrcPath
        $SPath = $SPathInfo.FullName
        $DPathInfo = Get-ItemProperty -path $DestPath
        $DPath = $DPathInfo.FullName

        fcon  in (Get-ChildItem -Path $SrcPath -File -Recurse)) {
            #$vFile = $_
            $IVideo = $vFile
            $IVideoFile = $IVideo.FullName.ToString()

            #   Test the source file extension and select oonly the true video types
            #
            $vfExtension = (Split-Path $IVideoFile -extension)
            if ($vfExtension -in $targetExtensions) {
                Write-Host "OK!   $($IVideo.FullName)"
                WriteToLogFile "OK!   $($IVideo.FullName)"
            }
            elseif ($vfExtension -in $copyExtensions) {
                Write-Host "Copy  $($vFile.FullName)"
                WriteToLogFile "Copy  $($vFile.FullName)"
                continue
            }
            else {
                Write-Host "No    $($vFile.FullName)"
                WriteToLogFile "No    $($vFile.FullName)"
                continue
            }


            $vfPathMid = $IVideo.DirectoryName.Substring($SPath.Length) -replace '^\\',''
            $OVideoFile = $DPath+'\'+$vfPathMid+'\'+$IVideo.Name
            $OVideoFile = $OVideoFile -replace "\$(Split-Path $OVideoFile -extension)", '.mp4'
            $OVideo = $null
            $OVideo = Get-ItemProperty -path $OVideoFile -ErrorAction continue

            if ($OVideo -eq $null) {
                Write-Verbose "--- Output file NOT Found: $($OVideoFile)"
                WriteToLogFile "--- Output file NOT Found: $($OVideoFile)"
                continue
            }

            if ($OVideo -eq $null) {
                $a = 1
            }

            $IVideoJson = $IVideoFile -replace "\$(Split-Path $IVideoFile -extension)", '.json'
            $OVideoJson = $OVideoFile -replace "\$(Split-Path $OVideoFile -extension)", '.json'

            #  Use FFPROBE to inspect the file for its current makeup.  Results are placed into an object constructed from the
            #  resulting JSON  from FFPROBE
            #
            #$STDOUT_IProbe = Join-Path -Path $($TempDir) -ChildPath "so_probe.txt"
            $ArgList_Probe = " -v error -hide_banner -of default=noprint_wrappers=0 -print_format json -show_streams -show_format `"$($IVideoFile)`" "
            Start-Process -FilePath ffprobe -ArgumentList $ArgList_Probe -Wait -NoNewWindow -RedirectStandardOutput $IVideoJson
            $ivInfo = ConvertFrom-Json ((Get-Content $IVideoJson) -join '')
            #Remove-item -path $STDOUT_IProbe

            #
            #$STDOUT_IProbe = Join-Path -Path $($TempDir) -ChildPath "so_probe.txt"
            $ArgList_Probe = " -v error -hide_banner -of default=noprint_wrappers=0 -print_format json -show_streams -show_format `"$($OVideoFile)`" "
            Start-Process -FilePath ffprobe -ArgumentList $ArgList_Probe -Wait -NoNewWindow -RedirectStandardOutput $OVideoJson
            $ovInfo = ConvertFrom-Json ((Get-Content $OVideoJson) -join '')
            #Remove-item -path $STDOUT_IProbe

            # Now examine the video attributes

            $ivFileVideo = $null
            $strmVideo = ($ivInfo.streams | Where-Object codec_type -eq 'video' | Sort-Object -Descending bit_rate | Select-Object  ) # -First 1
            try {
                $ivFileVideo = [PSCustomObject]@{
                    Index = $strmVideo.index
                    Mapping = "-map 0:$($strmVideo.index)"
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

            $ivFileAudio = $null
            $strmAudio = ($ivInfo.streams | Where-Object codec_type -eq 'audio')
            if ($strmAudio) {
                $ivFileAudio = [PSCustomObject]@{
                    Index = $strmAudio.index
                    Mapping = "-map 0:$($strmAudio.index)"
                    NewCodec = "mp3"
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
            $ivFileInfo = $null
            try {
                # Get the full file attributes
                $ivFileInfo = [PSCustomObject]@{
                    FileName = $ivInfo.format.filename
                    FormatName = $ivInfo.format.format_name
                    FormatLongName = $ivInfo.format.format_long_name
                    Duration = $ivInfo.format.duration
                    Size = $ivInfo.format.size
                    BitRate = $ivInfo.format.bit_rate
                    VideoInfo = $ivFileVideo
                    AudioInfo = $ivFileAudio
                }
            }
            catch {
                $e = $_
            }

            #  Output file

            $ovFileVideo = $null
            $strmVideo = ($ivInfo.streams | Where-Object codec_type -eq 'video' | Sort-Object -Descending bit_rate | Select-Object  ) # -First 1
            try {
                $ovFileVideo = [PSCustomObject]@{
                    Index = $strmVideo.index
                    Mapping = "-map 0:$($strmVideo.index)"
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

            $ovFileAudio = $null
            $strmAudio = ($ivInfo.streams | Where-Object codec_type -eq 'audio')
            if ($strmAudio) {
                $ovFileAudio = [PSCustomObject]@{
                    Index = $strmAudio.index
                    Mapping = "-map 0:$($strmAudio.index)"
                    NewCodec = "mp3"
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
                $ovFileInfo = $null
                # Get the full file attributes
                $ovFileInfo = [PSCustomObject]@{
                    FileName = $ovInfo.format.filename
                    FormatName = $ovInfo.format.format_name
                    FormatLongName = $ovInfo.format.format_long_name
                    Duration = $ovInfo.format.duration
                    Size = $ovInfo.format.size
                    BitRate = $ovInfo.format.bit_rate
                    VideoInfo = $ovFileVideo
                    AudioInfo = $ovFileAudio
                }
            }
            catch {
                $e = $_
            }

            if ($ivFileVideo.Count -ne $ovFileVideo.Count) {
                WriteToLogFile "---- Mismatch Video Streams --  $($IVideoFile)"
                Write-Verbose "---- Mismatch Video Streams --  $($IVideoFile)"
            }

            if ($ivFileAudio.Count -ne $ovFileAudio.Count) {
                WriteToLogFile "---- Mismatch Audio Streams --  $($IVideoFile)"
                Write-Verbose "---- Mismatch Audio Streams --  $($IVideoFile)"
            }

            if ($IVideo.Length -lt $OVideo.Length) {
                WriteToLogFile "---- Output file is larger --  $($IVideoFile)"
                Write-Verbose "---- Output file is larger --  $($IVideoFile)"
            }

            $a = 1
        }

    }

}

Compare-OldNewVideos -SrcPath "X:\System\tmp\mpg\tmpg\" -rDepth 0 -DestPath "Y:\system\tmp\X\mpgNew\"
#ExamineVideo -SrcPath "X:\System\tmp\mpg\tmpgFlat" -rDepth 0 -DestPath "Y:\system\tmp\X\mpgNew"
$a = "Stop"