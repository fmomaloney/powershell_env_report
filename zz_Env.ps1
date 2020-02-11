# Powershell Script to get some TRP QA environment info
# Edited to supply zzservice3 user credentials for script actions

# Get some info for the report header
$reportdate = [System.DateTime]::Now
# Test-Path is just error handling
if (Test-Path \\zz\ARM1\Branches\Integration\IntegrationBuilds) 
{
  # I am getting the very latest CI application code from our build directory to report as a reference
  $LatestApp = Get-ChildItem \\zztsfiles\ARM1\Branches\Integration\IntegrationBuilds | Where-Object { $_.PSIsContainer } | Sort-Object CreationTime -desc | Select-Object -first 1
  $AppString = $LatestApp.Name.toString() + ' built ' + $LatestApp.LastWriteTime.toString()
} else {
    $AppString = 'could not connect to repo'
    }
      
if (Test-Path \\zz\ARM1\Branches\Integration\Databases\ScriptedDatabases ) 
{
  # get the most recent DB build from CI directory
  $LatestDB = Get-ChildItem \\zz\ARM1\Branches\Integration\Databases\ScriptedDatabases | Where-Object { $_.PSIsContainer } | Sort-Object CreationTime -desc | Select-Object -first 1
  $DBString = $LatestDB.Name.toString() + ' built ' + $LatestDB.LastWriteTime.toString()
} else {
    $DBString = 'could not connect to devshare'
    }

# create the zzservice3 credential - all this is obfuscated of course
$MyDomain="WOW-mydomain"
$ClearTextUsername="zzservice3"
$ClearTextPassword="not-a-password"
$UsernameDomain=$MyDomain+"\"+$ClearTextUsername
$SecurePassword=Convertto-SecureString $ClearTextPassword  -AsPlainText  -force
$zzCredentials=New-object System.Management.Automation.PSCredential $UsernameDomain,$SecurePassword

# CSV report headers, column names and latest CI for reference (many times users will want the latest)
Add-Content \\zztrp2\Environment_Reports\mylog3.csv "1,2,LatestApp=$AppString,LatestDB=$DBString,5,6,7,ReportTime=$reportdate"
Add-Content \\zztrp2\Environment_Reports\mylog3.csv "ENVIRONMENT,APP HOSTNAME,PRODUCT VERSION,DB VERSION,DB HOST,DB USED GB,DB FREE GB,ModelShare"

# These are the TRP env hosts we are looking at, in an array
$RemoteComputers = @("zzTSNTFRAS1","zzngp-ts-ap1","zzTRPACCPTAPP1","zzTRP-App1","zzTS2APP1","zzTS1APP1","zzTS3APP1","zztsp6as1","zzTS10app1","zzTSAPP1","zz-NGP-AS","zzTS2012APP1","zzTS-TPZ-APP","zzTSF12APP1")

# loop through hosts and get our environment info
foreach ($hostname in $RemoteComputers) { 
      # set the environment name for the app host
      Switch($hostname) {
      zzTSNTFRAS1 {$envname = "New QA CI"}
      zz-ngp-ts-ap1 {$envname = "QA Manual Env"}
      zzTRPACCPTAPP1 {$envname = "Acceptance Env"}
      zzTRP-App1 {$envname = "Regression Env"}
      zzTS2APP1 {$envname = "Functional Env"}
      zzTS1APP1 {$envname = "Functional 1"}
      zzTS3APP1 {$envname = "Functional 2"}
      zztsp6as1 {$envname = "Performance 6"}
      zzTSAPP1 {$envname = "Big Performance Env"}
      zzTS10app1 {$envname = "Performance 10"}
      zzNGP-AS {$envname = "Auto 1"}
      zzTS2012APP1 {$envname = "Multi-SQL"}
      zz-TS-TPZ-APP {$envname = "Topaz CI"}
      zzTSF12APP1 {$envname = "New Func 2008"}
      default {$envname = "unknown"} 
                       }
  
      if ( Invoke-Command -ComputerName $hostname -ScriptBlock { Test-Path "C:\Program Files\WOW\IIS\Web.config" } -Credential $zzCredentials )
      {
        # now get info from our XML config file
        [xml]$myconfig = Invoke-Command -ComputerName $hostname -ScriptBlock { Get-Content "C:\Program Files\WOW\IIS\Web.config" } -Credential $zzCredentials
        # Find the information by XPATH and write to variable
        $productVersion = $myconfig.SelectNodes("//appSettings/add[@key='TouchstoneRe\ProductVersion']").Value
        $dbVersion = $myconfig.SelectNodes("//appSettings/add[@key='DBPackage\Version']").Value
        $dbVersionCode = $myconfig.SelectNodes("//appSettings/add[@key='DBPackage\Code']").Value
        $dbVal = $dbVersion + '.' + $dbVersionCode
        $dbHost = $myconfig.SelectNodes("//appSettings/add[@key='Database\Project\Server']").Value
        $modelShare = $myconfig.SelectNodes("//appSettings/add[@key='Models.Catalog.Repository']").Value
        
          # Split out the SQL instance from hostname, if any
          $b = $dbHost.Split("\")
          $dbHostOnly = $b[0]
          # Go to the DB host for env and check on the disk space (we often run out)
          if ( Test-Connection -ComputerName $dbHostOnly -Quiet -Count 1 )
          {
            # PSDrive will show us details on the hard drive usage
            $dbDrive = Invoke-Command -ComputerName $dbHostOnly -ScriptBlock { Get-PSDrive C } -Credential $zzCredentials
            # Convert bytes to GB and round
            $free = [math]::Round($dbDrive.Free/1073741824)
            $used = [math]::Round($dbDrive.Used/1073741824)
          } else {
              # could not connect to DB host
              $free, $used = "cannot", "connect"
              }

          # write the info row out to CSV report
          Add-Content \\zztrp2\Environment_Reports\mylog3.csv "$envname,$hostname,$productVersion,$dbVal,$dbHost,$used,$free,$modelShare"
        } else {
            # could not connect to $remotecomputer
        Add-Content \\zztrp2\Environment_Reports\mylog3.csv "$envname,'cannot','connect','to','the','remote','host','sorry','!'"
          }
  } # close foreach loop

# All done. Running under windows task scheduler, so comment out desktop output below.
# Write-Host "See mylog.csv on Desktop for TRP environment details!" -foregroundcolor "magenta"
# Get-Content $env:userprofile\desktop\mylog.csv | ConvertFrom-CSV | Out-Gridview
# the end