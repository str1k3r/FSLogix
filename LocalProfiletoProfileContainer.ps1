#### EDIT ME
$newprofilepath = "\\domain.com\share\path"

#### Don't edit me
$ENV:PATH=”$ENV:PATH;C:\Program Files\fslogix\apps\”
$oldprofiles = gci c:\users | ?{$_.psiscontainer -eq $true} | select -Expand fullname | sort | out-gridview -OutputMode Multiple -title "Select profile(s) to convert"

# foreach old profile
foreach ($old in $oldprofiles) {

$sam = ($old | split-path -leaf)
$sid = (New-Object System.Security.Principal.NTAccount($sam)).translate([System.Security.Principal.SecurityIdentifier]).Value

# set the nfolder path to \\newprofilepath\username_sid
$nfolder = join-path $newprofilepath ($sam+"_"+$sid)
# if $nfolder doesn't exist - create it with permissions
if (!(test-path $nfolder)) {New-Item -Path $nfolder -ItemType directory | Out-Null}
& icacls $nfolder /setowner "$env:userdomain\$sam" /T /C
& icacls $nfolder /grant $env:userdomain\$sam`:`(OI`)`(CI`)F /T

# sets vhd to \\nfolderpath\profile_username.vhdx (you can make vhd or vhdx here)
$vhd = Join-Path $nfolder ("Profile_"+$sam+".vhdx")

frx.exe copy-profile -filename $vhd -sid $sid
} 