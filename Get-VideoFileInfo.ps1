
function Get-VideoFileInfo {

    Param (
            [string] $SrcPath,
            [string] $InstanceName,
            [string] $Database,
            [string] $TempDir = "C:\Temp"
    )

      # -SrcPath "X:\System\tmp\mpg\tmpg\" -InstanceName "FLGARAGE\SQL2019" -Database "VideoLib"
 # -Recurse -file -include *.avi,*.divx,*.flv,*.m1v,*.m4v,*.mkv,*.mov,*.mp4,*.mpe,*.mpg,*.mpeg,*.rm,*.wmv

    Begin {

        function WriteToLogFile ($message)
        {
            $message +" - "+ (Get-Date).ToString() >> $LogFileName
        }

        $targetExtensions = @('.asf','.avi','.divx','.flv','.m1v','.m2v','.m4v','.mkv','.mov','.mp4','.mpe','.mpeg','.mpg','.rm',',ram','.wmv','.ts','.vob')
        #$copyExtensions   = @('.jpg','.jpeg','.gif')


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
        foreach ( $vFile in (Get-ChildItem -Path $SrcPath -File -Recurse)) {
            #$vFile = $_
            # $IVideo = $vFile
            # $IVideoFile = $IVideo.FullName.ToString()

            #   Test the source file extension and select oonly the true video types
            #
            $vfExtension = (Split-Path $vFile -extension)

            if ($vfExtension -in $targetExtensions) {
                Write-Host "OK!   $($vFile.FullName)"
                WriteToLogFile "OK!  $($vFile.FullName)"
            }
            # elseif ($vfExtension -in $copyExtensions) {
            #     Write-Host "Copy  $($vFile.FullName)"
            #     WriteToLogFile "Copy  $($vFile.FullName)"
            #     continue
            # }
            else {
            #    Write-Host "No    $($vFile.FullName)"
            #    WriteToLogFile "No    $($vFile.FullName)"
                continue
            }

            #   Build the information object
            #
            $vInfo = [PSCustomObject]@{
                DirPath = $vFile.DirectoryName
                FileName = $vFile.Name.Substring(0,($vFile.Name.length - $vfExtension.Length))
                Extension = $vfExtension
                ByteLen = $vFile.Length
                DateCreated = $vFile.CreationTime
                DateModified = $vFile.LastWriteTime
                Status = 0
                StatusMsg = ""
                RawInfoJson = ""
                AnalysisJson = ""
            }

            #$vfPathMid = $IVideo.DirectoryName.Substring($SPath.Length) -replace '^\\',''

            $IVideoJson = $TempDir + "\iVideoInfo.json"
            #$OVideoJson = $OVideoFile -replace "\$(Split-Path $OVideoFile -extension)", '.json'

            #  Use FFPROBE to inspect the file for its current makeup.  Results are placed into an object constructed from the
            #  resulting JSON  from FFPROBE
            #
            if (Test-Path -LiteralPath $IVideoJson -PathType Leaf ) { Remove-item -LiteralPath $IVideoJson }
            New-Item -path $IVideoJson -ItemType "file" | Out-Null
            $vName = $vFile.FullName # -replace '\[','`[') -replace '\]','`]'
            $ArgList_Probe = " -v error -hide_banner -of default=noprint_wrappers=0 -print_format json -show_streams -show_format `"$($vFile.FullName)`" "
            Start-Process -FilePath ffprobe -ArgumentList $ArgList_Probe -Wait -NoNewWindow -RedirectStandardOutput $IVideoJson
            $ivInfo = ConvertFrom-Json ((Get-Content -LiteralPath $IVideoJson) -join '')
            $vInfo.RawInfoJson = (((Get-Content -LiteralPath $IVideoJson) -join '') -replace '\s{2,20}',' ')

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

            $vInfo.AnalysisJson = ((ConvertTo-Json $ivFileInfo) -replace '\s{2,20}',' ')

            Remove-item -LiteralPath $IVideoJson

            #  Persist the info into the database
            #
            $colMap = @{
                DirPath = 'DirPath'
                FileName = 'FileName'
                Extension = 'Extension'
                ByteLen = 'ByteLen'
                DateCreated = 'DateCreated'
                DateModified = 'DateModified'
                RawInfoJson = 'RawInfoJson'
                AnalysisJson = 'AnalysisJson'
             }
            try {
                $vInfo | Write-DbaDbTableData -SqlInstance $InstanceName -Database $Database -Table "dbo.VideoInfo" -ColumnMap $colMap -EnableException
            }
            catch {
                Write-Host "Dup!  $($vFile.FullName)"
            }

        }

    }

}

Import-Module dbatools

Get-VideoFileInfo -SrcPath "Y:\System\tmp\" -InstanceName "FLGARAGE\SQL2019" -Database "VideoLib"
$a = "Stop"