
$action = 'Rebuild'
$oldRoot = "X:\System\tmp\mpg\tmpgFlat"
$newRoot = "X:\System\tmp\mpg\tmpg"

Get-ChildItem -Path $oldRoot -Recurse -file -include *.avi,*.divx,*.flv,*.m1v,*.m4v,*.mkv,*.mov,*.mp4,*.mpe,*.mpg,*.mpeg,*.rm,*.wmv | Select-Object -ExpandProperty FullName {
    if ($action -ieq 'Flatten') {
        $Newdir = $_.FullName -replace 'X:\\System\\tmp\\mpg\\tmpg\\', '<root>\'
        $Newdir2 = $Newdir -replace '\\','__'
        $Newdir3 = $Newdir2 -replace '<root>', $newRoot
        $Newdir3
        Move-Item -path $_.FullName -Destination $Newdir3
    }

    elseif ($action -ieq 'Rebuild') {
        $Newdir = $newRoot + '\' + $_.Name
        $Newdir2 = $Newdir -replace '___',''
        $Newdir3 = $Newdir2 -replace '__error','_error'
        $Newdir4 = $Newdir3 -replace '__','\'
        $Newdir4
        Move-Item -path $_.FullName -Destination $Newdir4
    }


}
