<#
  .SYNOPSIS
    A Simple PowerShell Backup script for creation of timestamped backups
    of files and folders as Zip archives.
  .DESCRIPTION
    The purpose of the script is to back up a whole folder or a single file
    from a Windows machine to a network share (Samba) as timestamped Zip
    archives. It's intended to be run regularly as a scheduled task or at
    system events like user log off or system shutdown.
  .NOTES
    Requires at least PowerShell 3.0 (for -Credential on network share).
#>

# Backup configuration
$bkp_date = Get-Date -Format yyyy-MM-dd # for once a day
#$bkp_for_user = "OTHER" # for Logoff event, uncomment if needed
$bkp_log_local = "$env:temp\$env:computername-backup-${bkp_date}.log"
$keep_local_bkps = $true
$bkp_path_local = "$env:temp"
$bkp_srcs = @{}
$bkp_srcs['src1'] = "C:\A\Directory\To\Backup"
$bkp_srcs['src2'] = "D:\A\File\To\Backup.txt"
# Add more backup sources here
Set-Variable MAX_ROTATIONS -Scope Script -option Constant -value 16

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

<#
  .SYNOPSIS
    Create versions (rotations) of the file provided as argument.
  .DESCRIPTION
    If the file exists, then the function creates a copy of it suffixed
    with number, but only op to MAX_ROTATIONS. If the limit is reached
    an error is thrown.
  .PARAMETER filename
    Full path to the file.
#>
function RotateFile($filename)
{
  if ( Test-Path -Path $filename ) # if file exits
  {
    $fnum = 0
    # rotate, but up to max number of rotations
    while ( (Test-Path -Path ($filename + "." + $fnum)) -and ($fnum -lt ($MAX_ROTATIONS - 1) ) ) {
      $fnum++
    }

    # test again and move
    if ( !(Test-Path -Path ($filename + "." + $fnum)) ) {
      Move-Item -Path $filename -Destination ($filename + "." + $fnum)
    }
    else { # or throw error
      Throw "ERROR: Reached maximum number of rotations ($max_rotations) for '$filename'."
    }
  }
}

<#
  .SYNOPSIS
    Creates the Zip archive provided as first argument of the file provided
    as second argument.
  .PARAMETER zipfilename
    Full path to the Zip archive.
  .PARAMETER file
    Full path to the file to archive.
#>
function ZipFile($zipfilename, $file) {
  try {
    RotateFile($zipfilename)
  }
  catch {
    Throw $_
  }

  Add-Type -Assembly System.IO.Compression
  Add-Type -Assembly System.IO.Compression.FileSystem

  [System.IO.Compression.ZipArchive]$ZipFile = [System.IO.Compression.ZipFile]::Open($zipfilename, ([System.IO.Compression.ZipArchiveMode]::Update))
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($ZipFile, $file, (Split-Path $file -Leaf))
  $ZipFile.Dispose()
}

<#
  .SYNOPSIS
    Creates the Zip archive provided as first argument of the directory
    provided as second argument.
  .PARAMETER zipfilename
    Full path to the Zip archive.
  .PARAMETER sourcedir
    Full path to the directory to archive.
#>
function ZipDir($zipfilename, $sourcedir) {
  try {
    RotateFile($zipfilename)
  }
  catch {
    Throw $_
  }

  Add-Type -Assembly System.IO.Compression
  Add-Type -Assembly System.IO.Compression.FileSystem

  $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
  [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcedir, $zipfilename, $compressionLevel, $false)
}

<#
  .SYNOPSIS
    Writes an event in the Event Log with the type, id and message provided
    as arguments.
  .PARAMETER Type
    Entry type (e.g. Error or Information).
  .PARAMETER Id
    Event identifier.
  .PARAMETER Message
    Free text message for the event.
#>
function LogEvent($Type, $Id, $Message) {
  if ( ![System.Diagnostics.EventLog]::SourceExists("Simple Backup Script") ) {
    # TODO: This requires elevated user rights. How?
    New-EventLog -LogName Application -Source "Simple Backup Script"
  }

  Write-EventLog -LogName Application -Source "Simple Backup Script" `
                 -EntryType $Type -EventID $id `
                 -Message $Message
}

function LogInfoEvent($Id, $Message) {
  LogEvent "Information" $Id $Message
}

function LogErrEvent($Id, $Message) {
  LogEvent "Error" $Id $Message
}

$start_time = Get-Date

if ( $null -ne $bkp_for_user ) {
  if ( $env:USERNAME -notlike $bkp_for_user ) {
    Write-Host "Expecting user '$bkp_for_user', but script ran as '$env:USERNAME'. Exiting."
    exit
  }
}

try {
  RotateFile($bkp_log_local)
}
catch {
  Write-Host "Too many rotations. Exiting."
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

$res_total = 0
foreach ($bsrc in $bkp_srcs.Keys) {
  try {
    if ( Test-Path -Path $bkp_srcs[$bsrc] -PathType Container ) {
      Write-Output "Backing up directory '$($bkp_srcs[$bsrc])'... "
      ZipDir  "$bkp_path_local\$bsrc-$bkp_date.zip" $bkp_srcs[$bsrc]
      if ( $keep_local_bkps ) {
        Copy-Item "$bkp_path_local\$bsrc-$bkp_date.zip" "$bkp_path_date\$bsrc-$bkp_date.zip"
      }
      else {
        Move-Item "$bkp_path_local\$bsrc-$bkp_date.zip" "$bkp_path_date\$bsrc-$bkp_date.zip"
      }
    }
    else {
      Write-Output "Backing up file '$($bkp_srcs[$bsrc])'... "
      ZipFile "$bkp_path_local\$bsrc-$bkp_date.zip" $bkp_srcs[$bsrc]
      if ( $keep_local_bkps ) {
        Copy-Item "$bkp_path_local\$bsrc-$bkp_date.zip" "$bkp_path_date\$bsrc-$bkp_date.zip"
      }
      else {
        Move-Item "$bkp_path_local\$bsrc-$bkp_date.zip" "$bkp_path_date\$bsrc-$bkp_date.zip"
      }
    }
    $res = 0
  }
  catch {
    $res = 1
    Write-Output $_
  }
  $res_total += $res
  Write-Output "Done ($res)"
}

) 2>&1 | Out-File $bkp_log_local

try {
  RotateFile("$bkp_path_date\backup-$bkp_date.log")
  Copy-Item $bkp_log_local "$bkp_path_date\backup-$bkp_date.log"
}
catch {
  Write-Output $_ | Out-File $bkp_log_local -Append
}

Remove-PSDrive "BKP"

$end_time = Get-Date
$used_time = $end_time - $start_time

if ($res_total -eq 0) {
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
