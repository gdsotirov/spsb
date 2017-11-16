# Simple PowerShell backup script
# Requires at least PowerShell 3.0 (for -Credential on network share)

# Backup configuration
$bkp_date = Get-Date -Format yyyy-MM-dd # for once a day
$bkp_src1 = "C:\A\Directory\To\Backup"
$bkp_src2 = "D:\A\File\To\Backup.txt"

# Backup server
$bkp_host = "a_backup_host"
$bkp_user = "a_user"
$bkp_pass = "a_password" | ConvertTo-SecureString -AsPlainText -Force
$bkp_cred = New-Object System.Management.Automation.PsCredential($bkp_user, $bkp_pass)
$bkp_path = "\\$bkp_host\$bkp_user"

# Mail variables
$mail_host = "a_mail_host"
$mail_from = "user@mail.host"
$mail_to   = "admin@other_mail.host"
$mail_subj = "Backup report from $env:computername on $bkp_date"

function ZipFile($zipfilename, $file)
{
  Add-Type -assembly System.IO.Compression
  Add-Type -Assembly System.IO.Compression.FileSystem

  [System.IO.Compression.ZipArchive]$ZipFile = [System.IO.Compression.ZipFile]::Open($zipfilename, ([System.IO.Compression.ZipArchiveMode]::Update))
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($ZipFile, $file, (Split-Path $file -Leaf))
  $ZipFile.Dispose()
}

function ZipDir($zipfilename, $sourcedir)
{
  Add-Type -Assembly System.IO.Compression.FileSystem
  $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
  [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcedir, $zipfilename, $compressionLevel, $false)
}

echo "Backup path = $bkp_path"
echo "Backup sources = $bkp_src1, $bkp_src2"

New-PSDrive -Name "BKP" -PSProvider FileSystem -Root $bkp_path -Credential $bkp_cred

# Do backup

$host_path = "$bkp_path\$env:computername"
if ( !(Test-Path "$host_path" -PathType Container) ) {
  mkdir $host_path
}

$bkp_path_date = "$host_path\$bkp_date"
if ( !(Test-Path "$bkp_path_date" -PathType Container) ) {
  mkdir $bkp_path_date
}

ZipDir  "$bkp_path_date\Bkp1-$bkp_date.zip" $bkp_src1
ZipFile "$bkp_path_date\Bkp2-$bkp_date.zip" $bkp_src2
#copy-Item  -Recurse $bkp_src1 -Destination $bkp_path_date\$bkp_src1

$mail_body = @"
Hello Administrator,

Backup of $env:computername on $bkp_date has completed successfully.


--
Your backup script at $env:computername

"@

send-MailMessage -SmtpServer $mail_host `
                 -From       $mail_from `
                 -To         $mail_to   `
                 -Subject    $mail_subj `
                 -Body       $mail_body

Remove-PSDrive "BKP"
