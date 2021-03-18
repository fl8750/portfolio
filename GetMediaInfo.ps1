add-type -path 'C:\Program Files\MediaInfo\MediaInfo.dll'
$MediaInfo = New-Object VISE_MediaInfo.MediaInfo
#Display all codec info about this PC
$MediaInfo.Option("Info_Codecs")
#Display information avout a specific file
$MediaInfo.Open('C:\Users\username\Videos\capture0000.mov')
$MediaInfo.Inform()
