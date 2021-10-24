
Get-ChildItem -Path "X:\System\tmp\mpg\tmpg" -Recurse -file -include *.avi,*.divx,*.flv,*.m1v,*.m4v,*.mkv,*.mov,*.mp4,*.mpe,*.mpg,*.mpeg,*.rm,*.wmv | Select-Object -ExpandProperty FullName {
    #$_
    $Newdir = $_.FullName -replace 'X:\\System\\tmp\\mpg\\tmpg\\', '<root>\'
    $Newdir2 = $Newdir -replace '\\','__'
    $Newdir3 = $Newdir2 -replace '<root>', 'X:\System\tmp\mpg\tmpgFlat\_'
    $Newdir3
    #Out-File -FilePath $Newdir3
    Move-Item -path $_.FullName -Destination $Newdir3
}
