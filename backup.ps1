# Simple PowerShell backup script
# Requires at least PowerShell 3.0 (for -Credential on network share)

# Backup configuration
$bkp_date = Get-Date -Format yyyy-MM-dd # for once a day
$bkp_for_user = "OTHER" # for Logoff event
$bkp_log_local = "$env:temp\$env:computername-backup-${bkp_date}.log"
$bkp_srcs = @{}
$bkp_srcs['src1'] = "C:\A\Directory\To\Backup"
$bkp_srcs['src2'] = "D:\A\File\To\Backup.txt"
# Add more backup sources here

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
  Add-Type -Assembly System.IO.Compression
  Add-Type -Assembly System.IO.Compression.FileSystem

  [System.IO.Compression.ZipArchive]$ZipFile = [System.IO.Compression.ZipFile]::Open($zipfilename, ([System.IO.Compression.ZipArchiveMode]::Update))
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($ZipFile, $file, (Split-Path $file -Leaf))
  $ZipFile.Dispose()
}

function ZipDir($zipfilename, $sourcedir)
{
  Add-Type -Assembly System.IO.Compression
  Add-Type -Assembly System.IO.Compression.FileSystem

  $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
  [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcedir, $zipfilename, $compressionLevel, $false)
}

function LogEvent($Type, $Id, $Message) {
  if ( ![System.Diagnostics.EventLog]::SourceExists("Simple Backup Script") ) {
    New-EventLog   –LogName Application –Source “Simple Backup Script”
  }

  Write-EventLog –LogName Application –Source “Simple Backup Script” `
                 –EntryType $Type –EventID $id `
                 –Message $Message
}

function LogInfoEvent($Id, $Message) {
  LogEvent "Information" $Id $Message
}

function LogErrEvent($Id, $Message) {
  LogEvent "Error" $Id $Message
}

$start_time = Get-Date

if ( $env:USERNAME -notlike $bkp_for_user ) {
  Write-host "Expecting user '$bkp_for_user', but script ran as '$env:USERNAME'. Exiting."
  exit
}

# Do backup
$(
New-PSDrive -Name "BKP" -PSProvider FileSystem -Root $bkp_path -Credential $bkp_cred

$host_path = "$bkp_path\$env:computername"
if ( !(Test-Path "$host_path" -PathType Container) ) {
  mkdir $host_path
}

$bkp_path_date = "$host_path\$bkp_date"
if ( !(Test-Path "$bkp_path_date" -PathType Container) ) {
  mkdir $bkp_path_date
}

foreach ($bsrc in $bkp_srcs.Keys) {
  Write-Output "Backing up '$bkp_srcs[$bsrc]'... "
  try {
    ZipDir  "$bkp_path_date\$bsrc-$bkp_date.zip" $bkp_srcs[$bsrc]
    $res1 = 0
  }
  catch {
    $res1 = 1
    Write-Output $_
  }
  Write-Output "Done ($res1)"
}

) 2>&1 | Out-File $bkp_log_local

Copy-Item $bkp_log_local "$bkp_path_date\backup-$bkp_date.log"

Remove-PSDrive "BKP"

$end_time = Get-Date
$used_time = $end_time - $start_time

if ($res1 -eq 0 -and $res2 -eq 0) {
  $mail_subj = $mail_subj + " [OK]"
  $mail_msg = "Backup of $env:computername on $bkp_date has completed successfully in $($used_time.TotalSeconds) seconds."

  LogInfoEvent 999 $mail_msg
}
else {
  $mail_subj = $mail_subj + " [KO]"
  $mail_msg = @"
Backup of $env:computername on $bkp_date has *failed* after $($used_time.TotalSeconds) seconds.
See attachment for more details.
"@

  LogErrEvent 888 $mail_msg
}

  $mail_body = @"
Hello Administrator,

$mail_msg


--
Your backup script at $env:computername
"@

send-MailMessage -SmtpServer  $mail_host `
                 -From        $mail_from `
                 -To          $mail_to   `
                 -Subject     $mail_subj `
                 -Body        $mail_body `
                 -Attachments $bkp_log_local
