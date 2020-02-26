#Requires -Version 5
#Requires -RunAsAdministrator
#Requires -Module Hyper-V
#This command installed the Hyper-V Module. A restart is required
#Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
#Install-WindowsFeature -Name Hyper-V-PowerShell
#How-To for Hyper-V Module
#https://www.altaro.com/hyper-v/install-hyper-v-powershell-module/
<#
Rewrite by Manuel Winkel
Written by David Ott
This script will increase FSLogix VHD/VHDX profiles in the profile share.  It would also work for
any directory containing VHD/VHDX files.
Test before using!!
Search for "#####" to find the sections you need to edit for your environment
#>
Function Set-AlternatingRows {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]$Line,
       
        [Parameter(Mandatory)]
        [string]$CSSEvenClass,
       
        [Parameter(Mandatory)]
        [string]$CSSOddClass
    )
    Begin {
        $ClassName = $CSSEvenClass
    }
    Process {
        If ($Line.Contains("<tr><td>"))
        {   $Line = $Line.Replace("<tr>","<tr class=""$ClassName"">")
            If ($ClassName -eq $CSSEvenClass)
            {   $ClassName = $CSSOddClass
            }
            Else
            {   $ClassName = $CSSEvenClass
            }
        }
        Return $Line
    }
}
function checkFileStatus($filePath)
    {
            $fileInfo = New-Object System.IO.FileInfo $filePath
 
        try
        {
            $fileStream = $fileInfo.Open( [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read )
            $filestream.Close()
            return $false
        }
        catch
        {
           
            return $true
        }
    }
function vhdmount($v) {
try {
$DriveLetter = ""
#Mount-VHD -Path C:\Share\Container\manuel_S-1-5-21-628618687-1131549682-2054828346-500\Profile_manuel.VHDX -ReadOnly -ErrorAction Stop
Mount-VHD -Path $v -ErrorAction Stop
return "0"
} catch {
return "1"
}
}
function vhdincrease($v) {
try {
Resize-VHD $v -SizeBytes $MaxSize #-ErrorAction Ignore
Get-Partition -DiskNumber $Partition | Set-Partition -NewDriveLetter $DriveLetter
$Max = (Get-PartitionSupportedSize -DriveLetter $DriveLetter -ErrorAction Ignore).sizeMax
Resize-Partition -DriveLetter $DriveLetter -Size $Max -ErrorAction Ignore
return "0"
} catch {
return "1"
}
}

function vhddismount($v) {
try {
Dismount-VHD $v -ErrorAction stop
return "0"
} catch {
return "1"
}
}
$smtpserver = "smtpserver.fqdn" ##### SMTP Server
$to = "your email address" ##### email report to - "email1","email2" for multiple
$from = "fslogixreport@yourcompany.com" ##### email from
$rootfolder = "C:\Share\Container" ##### root path to vhd(x) files
$MaxSize = 60GB ##### Max VHDX Size
$vhds = (gci $rootfolder -recurse -Include *.vhd,*.vhdx).fullname
$Partition = 2 ##### Count of Disks
$DriveLetter = "z" ##### Free DriveLetter for temporary moun
[System.Collections.ArrayList]$info = @()
$t = 0
foreach ($vhd in $vhds) {
$locked = checkFileStatus -filePath $vhd
if ($locked -eq $true) {
"$vhd in use, skipping."
$info.add(($t | select @{n='VHD';e={Split-Path $vhd -Leaf}},@{n='Before_MB';e={0}},@{n='After_MB';e={0}},@{n='Reduction_MB';e={0}},@{n='Success';e={"Locked"}},@{n='VHD_Fullname';e={$vhd}})) | Out-Null
continue
}

$mount = vhdmount -v $vhd
if ($mount -eq "1") {
"Mounting $vhd failed "
$e = "Mounting $vhd failed "+(get-date).ToString()
#Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject "FSLogix VHD(X) ERROR" -Body "$e" -Priority High -BodyAsHtml
break
}else{"Mounting $vhd success with DriveLetter $DriveLetter"}
$vhdincrease = vhdincrease -v $vhd
if ($vhdincrease -eq "1") {
"Failed to increase $vhd "
}else{"Success to increase $vhd "}

$dismount = vhddismount -v $vhd
if ($dismount -eq "1") {
"Failed to dismount $vhd "
$e = "Failed to dismount $vhd "+(get-date).ToString()
#Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject "FSLogix VHD(X) ERROR" -Body "$e" -Priority High -BodyAsHtml
break
}else{"Success to dismount $vhd "}
}
$Header = @"
<style>
TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;width: 95%}
TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #6495ED;}
TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
.odd { background-color:#ffffff; }
.even { background-color:#dddddd; }
</style>
"@
$date = Get-Date
$timestamp = get-date $date -f MMddyyyyHHmmss
##### uncomment the next 2 lines if you would like to save a .htm report (also 2 more at the end)
#$out = Join-Path ([environment]::GetFolderPath("mydocuments")) ("FSLogix_Reports\VHD_Reduction_Report_$timestamp.htm")
#if (!(test-path (Split-Path $out -Parent))) {New-Item -Path (Split-Path $out -Parent) -ItemType Directory -Force | Out-Null}
$before = ($info.before_mb | measure -Sum).Sum
$after = ($info.after_mb | measure -Sum).Sum
$reductionmb = ($info.reduction_mb | measure -Sum).sum
$message = $info | sort After_MB -Descending | ConvertTo-Html -Head $header -Title "FSLogix VHD(X) Reduction Report" -PreContent "<center><h2>FSLogix VHD(X) Reduction Report</h2>" -PostContent "</center><br><h3>Pre-optimization Total MB: $before<br>Post-optimization Total MB: $after<br>Total Reduction MB: $reductionmb</h3>"| Set-AlternatingRows -CSSEvenClass even -CSSOddClass odd
##### comment the next line if you do not wish the report to be emailed
#Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject ("FSLogix VHD(X) Reduction Report "+($date).ToString()) -Body "$message" -BodyAsHtml
##### uncomment the next 2 lines to save the report to your My Documents\FSLogix_Reports directory, and open it in your default browser
#$message | Out-File $out
#Invoke-Item $out
