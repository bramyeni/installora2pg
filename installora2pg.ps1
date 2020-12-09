# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $Id: installora2pg.ps1 32 2020-09-01 23:11:39Z bpahlawa $
# $Date: 2020-09-02 07:11:39 +0800 (Wed, 02 Sep 2020) $
# $Revision: 32 $
# $Author: bpahlawa $
# 

# Parameter to be passed by this program when running as administrator
param (
    [string]$Flag = 0
)

#url basic and sdk instantclient for oracle 19c now doesnt require to accept license agreement
$global:basicoraurl = "https://download.oracle.com/otn_software/nt/instantclient/19800/instantclient-basic-windows.x64-19.8.0.0.0dbru.zip?xd_co_f=2c63df9ae28e0d298571597729961548"
$global:sdkoraurl = "https://download.oracle.com/otn_software/nt/instantclient/19800/instantclient-sdk-windows.x64-19.8.0.0.0dbru.zip"
#vc 2015-2019 redistributable link
$global:vc201519 = "https://aka.ms/vs/16/release/vc_redist.x64.exe"
#vc 2010 redistributable link
$global:vc2013 = "https://aka.ms/highdpimfc2013x64enu"
#pgsql client
$global:pgsqlclient="https://sbp.enterprisedb.com/getfile.jsp?fileid=12653&_ga=2.123215491.987018253.1596767913-1111948235.1596767913"
# root directory ora2pg
$Global:ora2pg = "c:\localora2pg";
# location to install git
$GitFolder="C:\github";
# repository location to clone ora2pg source
$ora2pgGit="https://github.com/darold/ora2pg.git";
# temp directory to install ora2pg
$ora2pgTemp="C:\ora2pgTemp";
# location to install ORACLE_HOME instant client
$Global:oraclehome="C:\localora2pg\instantclient";
# location to write a log file
$Global:Logfile = "c:\installora2pg.log"
# location to install strawberry perl
$Global:Perl = "c:\localora2pg\strawberry";


#Accepting all certificates, when you un-comment the following lines then use at your own risk
#
#add-type @"
#using System.Net;
#using System.Security.Cryptography.X509Certificates;
#public class TrustAllCertsPolicy : ICertificatePolicy {
#    public bool CheckValidationResult(
#        ServicePoint srvPoint, X509Certificate certificate,
#        WebRequest request, int certificateProblem) {
#        return true;
#    }
#}
#"@
#$AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
#[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
#[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


[Net.ServicePointManager]::SecurityProtocol = "Tls,Tls11,Tls12"


# function to display message and also write to a logfile
Function Write-OutputAndLog
{
   Param ([string]$Message)
   write-host "$message"
   Add-content "$Global:Logfile" -value "$message"
}

# function download file from internet
Function Download-File {
    Param(
        [Parameter(Mandatory)]
        [string] $name,
        [Parameter(Mandatory)]
        [string] $url
    )

  # Display message of downloading file
  Write-OutputAndLog "Downloading $name client..."
  $RetVal = Invoke-WebRequest $url -usebasicparsing -outfile "$global:ora2pg\temp\$name"
  if ( $Retval.StatusCode -eq 200 )
  {
     Write-OutputAndLog "Url '$url' has been downloaded into '$global:ora2pg\temp\$name'"
  }
  else
  {
     Write-OutputAndLog "Failed to download '$url'"
     Write-OutputAndLog "Check url $url may have changed !!, if this is the case please change url variable in this script!!"
     Write-OutputAndLog "will not install $name..."
     write-outputAndLog "........Press any key to exit............"
	 $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
     exit
  }
}

# Function to install pgsql client
Function Install-pgsqlclient {
  Param(
    [string] $installationPath
  )

    $name="pgsqlclient.zip"
    
    write-outputAndLog "Finding $name ..."
    $thedownloadedfile = Get-ChildItem -Filter "$name" -LiteralPath "$global:ora2pg\temp"

     # if the $installerpath file isnt available then download the file
    if ( $thedownloadedfile.FullName -eq $null )
    {
        write-outputAndLog "Downloading file $name from '$global:pgsqlclient' ..."
        Download-file $name -url $global:pgsqlclient
        $thedownloadedfile = Get-ChildItem -Filter "$name" -LiteralPath "$global:ora2pg\temp"
    }

    #check if pgsql client is already installed
    write-outputAndLog "Searching pg_config.exe from directory $global:ora2pg  ..."
    $thefile = Get-ChildItem -Filter pg_config.exe -LiteralPath "$global:ora2pg" -ErrorAction silentlycontinue -Recurse -Force
    

    
    if ( $thefile.fullname -eq $null )
    {

    write-outputAndLog "Extracting file '$name' ..."
    try {
            Extract-Archive -LiteralPath "$($thedownloadedfile.Fullname)" -DestinationPath "$Global:ora2pg"
        }
    catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-OutputAndLog ("Item: $Faileditem, Error: $ErrorMessage")
            remove-item $thedownloadedfile.FullName -confirm
            write-outputAndLog "........Press any key to exit............"
		    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
            exit
          }
    
    }

}


# function to install perl
Function Install-Perl {
  # installation path parameter
  Param(
    [string] $installationPath
  )

  # Browse the web where perl is downloaded
  $urlperl="http://strawberryperl.com/"
  Write-OutputAndLog "Browsing $urlperl"
  

  # Get version of latest strawberry perl from the web
  Write-OutputAndLog "Getting version of strawberry-perl..."
  $RetVal = ( Invoke-WebRequest $urlperl -usebasicparsing ) -Match "href=.*strawberry-perl-([0-9.]+).*" 
  $Version = $Matches.1

  # check whether perl version can be gathered from the web
  if ($retval -eq $true)
  {
      Write-OutputAndLog "Latest version is $Version"
	  # url link where the perl installation file can be downloaded
      $url = ("http://strawberryperl.com/download/$Version/strawberry-perl-$Version-64bit.msi" -f $Version);
      
  }
  else
  {
      # unable to get the file from web or website may be down
      Write-OutputAndLog "Unable to get the strawberry perl version from strawberryperl website..."
	  write-outputAndLog "........Press any key to exit............"
	  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
      exit
  }

  # initialize options as an array
  $options = @();

  # check whether installationPath is available, if it is then install perl
  $options += ('TARGETDIR="{0}"' -f $global:ora2pg);

  if ($installationPath) {
    $options += ('INSTALLDIR="{0}"' -f $installationPath);
  }
  # execute install perl
  Install-FromMsi -Name "perl" -Url $url -Options $options;
}

# function to install msi application
Function Install-FromMsi {
    # required parameters are name and url
    Param(
        [Parameter(Mandatory)]
        [string] $name,
        [Parameter(Mandatory)]
        [string] $url,
        [Parameter()]
        [switch] $noVerify = $false,
        [Parameter()]
        [string[]] $options = @()
    )

    # once it is downloaded it will be stored in the location that is assigned to this variable
    $installerPath = ( "$global:ora2pg\temp\{0}.msi" -f $name );


    # check whether msi application has been installed
	# Supress error
    $ErrorActionPreference = 'SilentlyContinue'

    # Execute the command even if it doesnt exist
    $result = Invoke-Expression -command "$name --version"
    $ErrorActionPreference = 'Continue'

    # if the $result variable is null then the command isnt installed 
	# otherwise it will display $name has been installed and return to main program
    if ($result -ne $null)
    {
        write-outputAndLog "$name has been installed.."
       # return;
    }
    else
    {
        Write-OutputAndLog "Will be downloading $name from $url"
    }

    # if the $installerpath file isnt available then download the file
    if (  ( Test-Path -path $installerPath ) -eq  $false)
    {
       Write-OutputAndLog ('Downloading {0} installer from {1} ..' -f $name, $url);
       Invoke-WebRequest -Uri $url -Outfile $installerPath -usebasicparsing;
       Write-OutputAndLog ('Downloaded {0} bytes' -f (Get-Item $installerPath).length);
    }
    else
    {
       Write-OutputAndLog "File $InstallerPath has been downloaded..." 
    }

    # add necessary arguments to install quietly

    

    $args = @('/i',"`"$installerPath`"", '/quiet', '/qn','/passive','/log c:\windows\temp\installperl.log');
    $args += $options;

    # check whether perl has been installed
    $thefile = Get-ChildItem -LiteralPath $Global:ora2pg -Filter perl.exe -Recurse -force -ErrorAction SilentlyContinue

    if ( $thefile.Fullname -ne $null )
    {
       Write-OutputAndLog ('Uninstalling {0} ...' -f $name);
       Write-OutputAndLog ("msiexec /uninstall '$installerPath' /passive /norestart");
       $argsu = @('/uninstall',"`"$installerPath`"", '/passive','/norestart');
       Start-process msiexec -wait -ArgumentList $argsu  
    }

    # display message
    Write-OutputAndLog ('Installing {0} ...' -f $name);
    Write-OutputAndLog ('msiexec {0}' -f ($args -Join ' '));

    # execute installation
    Start-Process msiexec -Wait -ArgumentList $args;

    #  Update path
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine);

    # verify whether the application is installed successfully
    if (!$noVerify) {
        Write-OutputAndLog ('Verifying {0} install ...' -f $name);
        $verifyCommand = (' {0} --version' -f $name);
        Write-OutputAndLog $verifyCommand;
        Invoke-Expression $verifyCommand;
    }

    # remove the installation file
    Write-OutputAndLog ('Removing {0} installer ...' -f $name);
    Remove-Item $installerPath -Force;

    Write-OutputAndLog ('{0} install complete.' -f $name);
}


# function to install from Exe file
Function Install-FromExe {
    Param(
        [Parameter(Mandatory)]
        [string] $name,
        [Parameter(Mandatory)]
        [string] $url,
        [Parameter()]
        [switch] $noVerify = $false,
        [Parameter(Mandatory)]
        [string[]] $options = @()
    )

    # download file will be store in the location that is pointed by $installerPath
    $installerPath = Join-Path ([System.IO.Path]::GetTempPath()) ('{0}.exe' -f $name);

    # if this is git installation then check whether the destination folder is set
    if ( (Test-path -path $GitFolder) -eq $True) 
    {
	    # goto $gitfolder\bin
        Set-location "$GitFolder\bin"
		# supress error
        $ErrorActionPreference = 'SilentlyContinue';
        # check whether git has been installed
		$result = Invoke-Expression -command ".\$name --version"

        write-outputAndLog "result is $result"
        $ErrorActionPreference = 'Continue';
        

        if ($result -ne $null)
        {
            write-outputAndLog "$name has been installed.."
            return;
        }
        else
        {
           write-outputAndLog "$name does not exist..."
        }
    }
    # check whether the file is available, if it is not then download the file from the given url
    if (  ( Test-Path -path $installerPath ) -eq  $false)
    {
        Write-OutputAndLog ('Downloading {0} installer from {1} ..' -f $name, $url);
        Invoke-WebRequest -Uri $url -outFile $installerPath -usebasicparsing;
        Write-OutputAndLog ('Downloaded {0} bytes' -f (Get-Item $installerPath).length);

        Write-OutputAndLog ('Installing {0} ...' -f $name);
        Write-OutputAndLog ('{0} {1}' -f $installerPath, ($options -Join ' '));

    }
    else
    {
	   # display message that file has been downloaded 
       Write-OutputAndLog "File $InstallerPath has been downloaded..."
    }

    # execute installation process
    Start-Process $installerPath -Wait -ArgumentList $options;

    #  Update path
     $env:PATH = "$([Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine));{0}\bin" -f $GitFolder;

    # verify whether the installation is successfull
    if (!$noVerify) {
        Write-OutputAndLog ('Verifying {0} install ...' -f $name);
        $verifyCommand = (' {0} --version' -f $name);
        Write-OutputAndLog $verifyCommand;
        Invoke-Expression $verifyCommand;
    }

    # Remove temp file
    Write-OutputAndLog ('Removing {0} installer ...' -f $name);
    Remove-Item $installerPath -Force;

    Write-OutputAndLog ('{0} install complete.' -f $name);
}

# function to remove all tempfiles under $global:ora2pg\temp
Function Remove-TempFiles {
    $tempFolders = @($env:temp, '$global:ora2pg\temp')

    Write-OutputAndLog 'Removing temporary files';
    $filesRemoved = 0;
  
    foreach ($folder in $tempFolders) {
        $files = Get-ChildItem -Recurse -Force -ErrorAction SilentlyContinue $folder;

        foreach ($file in $files) {
            try {
                Remove-Item $file.FullName -Recurse -Force -ErrorAction Stop
                $filesRemoved++;
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Write-OutputAndLog ("Item: $Faileditem, Error: $ErrorMessage")
            }

            
        }
    }

    Write-OutputAndLog ('Removed {0} files from temporary directories' -f $filesRemoved)
}

# function to check internet connection
Function Check-Internet()
{

    $ErrorActionPreference = 'SilentlyContinue'
	# check connection to microsoft.com, this is to ensure that the location where the script is run has internet connection
    $Result = (Invoke-WebRequest "http://microsoft.com" -ErrorAction SilentlyContinue -usebasicparsing)
    $ErrorActionPreference = 'Continue'

    # if $result isnt null then internet is available, otherwise exit out
    if ($Result -eq $null)
    {
    
        write-outputAndLog "Internet is not available..."
		write-outputAndLog "........Press any key to exit............"
		$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        exit
    }

}

Function Extract-Archive()
{
   Param(
        [Parameter(Mandatory)]
        [string] $LiteralPath,
        [Parameter(Mandatory)]
        [string] $DestinationPath
    )

    Write-OutputAndLog "Extracting Archive from $LiteralPath to $DestinationPath"

    if ( $psversiontable.PSVersion.Major -lt 5 )
    {
        [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($LiteralPath, $DestinationPath)
    }
    else
    {
        Expand-Archive -LiteralPath $LiteralPath -DestinationPath $DestinationPath -force
    }
}

Function Check-InstantClientVersion()
{

    Param(
        [Parameter(Mandatory)]
        [string] $OracleInstantClientFile
        )


   $File = Get-ChildItem -Filter "$OracleInstantClientFile" -ErrorAction SilentlyContinue
   if ( $File.Fullname -ne $null )
   {
       $Retval = $File -match '-([0-9]+).'
       if ( $Retval -eq $True )
       {
           if ( $Matches[1] -le 12 )
           {
               Write-OutputAndLog "Using Oracle instantclient 12c or earlier..."
               if ( ( Get-ChildItem C:\windows\system32\msvcr120.dll -ErrorAction SilentlyContinue  ).Fullname -eq $null )
               {
                   if ( ( Get-ChildItem $Global:ora2pg\instantclient\msvcr120.dll -ErrorAction SilentlyContinue ).Fullname -eq $null )
                   {
                       Write-OutputAndLog "msvcr120.dll is not available, therefore installing Visual C++ redistributable library from $($global:vc2013)"
                       Write-OutputAndLog "You are using oracle instantclient version $($Matches[1])"
                       Download-File "VC_redist2013.exe" -url $global:vc2013
                       try {
                             Start-Process -Wait -FilePath "$global:ora2pg\temp\VC_redist2013.exe" -ArgumentList '/S','/v','/qn' -passthru
                           }
                        catch {
                                $ErrorMessage = $_.Exception.Message
                                $FailedItem = $_.Exception.ItemName
                                Write-OutputAndLog ("Item: $Faileditem, Error: $ErrorMessage")
                                remove-item $thedownloadedfile.FullName -confirm
                                write-outputAndLog "........Press any key to exit............"
		                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
                                exit
                           }

                       
          
                   }
                }

            }
            else
            {
                 Write-OutputAndLog "Using Oracle instantclient 18c or later..."
                 if ( ( Get-ChildItem C:\windows\system32\vcruntime140.dll -ErrorAction SilentlyContinue  ).Fullname -eq $null )
                 {
                   if ( ( Get-ChildItem $Global:ora2pg\instantclient\vcruntime140.dll -ErrorAction SilentlyContinue ).Fullname -eq $null )
                   {
                       Write-OutputAndLog "vcruntime140.dll is not available on either c:\windows\system32 or $global:ora2pg\instantclient"
                       Write-OutputAndLog "therefore installing Visual C++ redistributable library from $($global:vc201519)"
                       Download-File "VC_redist2019.exe" -url $global:vc201519
                       try {
                             Start-Process -Wait -FilePath "$global:ora2pg\temp\VC_redist2019.exe" -ArgumentList '/S','/v','/qn' -passthru
                           }
                        catch {
                                $ErrorMessage = $_.Exception.Message
                                $FailedItem = $_.Exception.ItemName
                                Write-OutputAndLog ("Item: $Faileditem, Error: $ErrorMessage")
                                remove-item $thedownloadedfile.FullName -confirm
                                write-outputAndLog "........Press any key to exit............"
		                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
                                exit
                           }
                   }
                }
                write-outputAndLog "NOTE: You are using instantclient 18c or later, which means $($global:ora2pg) directory CANNOT be used in windwos 2008 R2 or earlier!!"
            }
        }
     }
     else
     {
        Write-OutputAndLog "Using Oracle instantclient 18c or later..."
        if ( ( Get-ChildItem C:\windows\system32\vcruntime140.dll -ErrorAction SilentlyContinue  ).Fullname -eq $null )
        {

            if ( ( Get-ChildItem $Global:ora2pg\instantclient\vcruntime140.dll -ErrorAction SilentlyContinue ).Fullname -eq $null )
            {
                Write-OutputAndLog "vcruntime140.dll is not available on either c:\windows\system32 or $global:ora2pg\instantclient"
                Write-OutputAndLog "therefore installing Visual C++ redistributable library from $($global:vc201519)"
                Download-File "VC_redist2019.exe" -url $global:vc201519
                try {
                        Start-Process -Wait -FilePath "$global:ora2pg\temp\VC_redist2019.exe" -ArgumentList '/S','/v','/qn' -passthru
                    }
                catch {
                        $ErrorMessage = $_.Exception.Message
                        $FailedItem = $_.Exception.ItemName
                        Write-OutputAndLog ("Item: $Faileditem, Error: $ErrorMessage")
                        remove-item $thedownloadedfile.FullName -confirm
                        write-outputAndLog "........Press any key to exit............"
		                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
                        exit
                    }
            }
        }
      } 
        
}

# function to check oracleclient
Function Check-OracleClient()
{
     # parameter for instant client path
     Param(
        [String] $OracleInstallPath
      )

    
		
    # check whether oracle instant client/oracle client has been installed by searching oci.dll
	if ($OracleInstallPath -ne $null)
    {
	   # search oci.dll from location $oracleinstallpath
       write-outputAndLog "Searching oci.dll from Directory $oracleinstallpath..."
       $result = Get-Childitem –Path "$oracleinstallpath" -Include oci.dll -Recurse -ErrorAction SilentlyContinue 
       
    }
    else
    {
	   # Search oci.dll from all logical drives recursively
       write-outputAndLog "Searching oci.dll from all Logical drives..."
       foreach ( $Disk in (Get-Volume | where { $_.DriveLetter -ne $null })) {
           $result = Get-childitem -path "$($Disk.DriveLetter):\" -include oci.dll -recurse -erroraction SilentlyContinue 
       }

       

    }

	# if no oci.dll to be found, then this script will display message where to download the oracle instant client
	if ($result -eq $null)
    {
	    # url of base oracle instant client and sdk
		$urlinstantclient = "https://www.oracle.com/database/technologies/instant-client/winx64-64-downloads.html"
        $baseoracle = "https://download.oracle.com/otn/nt/instantclient/122010/instantclient-basic-windows.x64-12.2.0.1.0.zip"
        $sdkoracle = "https://download.oracle.com/otn/nt/instantclient/122010/instantclient-sdk-windows.x64-12.2.0.1.0.zip"

        # get the file name
        #$baseoraclezipfile=split-path -path $baseoracle -leaf
        #$sdkoraclezipfile=Split-Path -path $sdkoracle -leaf
		$baseoraclezipfile="*-basic-*"
		$sdkoraclezipfile="*-sdk-*"
		
		
		
		# check if those 2 files are available
        if ( (Get-ChildItem -Filter "$baseoraclezipfile" -Path "$Global:ScriptDir" -ErrorAction silentlycontinue) -eq $null -or (Get-ChildItem -Filter "$sdkoraclezipfile" -Path "$Global:ScriptDir" -ErrorAction silentlycontinue) -eq $null  )
        {
            Write-OutputAndLog "Downloading oracle instantclient ver 19c...."
            Write-OutputAndLog "`n`n=====================ATTENTION!!==================ATTENTION!!======================================`n"
            Write-OutputAndLog "This will only work with oracle database 12c or later !!"
            write-outputAndLog "oracle 11g or earlier, requires oracle instantclient ver 12c or earlier!!..."
            write-outputAndlog "if you are using oracle database 11g or earler, please cancel this installation by pressing ctrl+c"
            Write-OutputAndLog "then Please download basic and sdk oracle Instantclients 12c from:`n$urlinstantclient"
            Write-OutputAndLog "`n`n=============================WILL BE INSTALLING oracle instantclient v19c============================"
            Download-File "instantclient-basic-file.zip" -url $global:basicoraurl
            Download-file "instantclient-sdk-file.zip" -url $global:sdkoraurl

            $thebaseoraclezipfile = Get-ChildItem -Filter "$baseoraclezipfile" -Path "$Global:ora2pg\temp"
            write-outputAndLog "Extracting file $($thebaseoraclezipfile.fullname) ..."
            Extract-Archive -LiteralPath $thebaseoraclezipfile.fullname -DestinationPath $Global:ora2pg
			$thesdkoraclezipfile = Get-ChildItem -Filter "$sdkoraclezipfile" -Path "$Global:ora2pg\temp"
            write-outputAndLog "Extracting file $($thesdkoraclezipfile.Fullname) ..."
            Extract-Archive -Literalpath $thesdkoraclezipfile.fullname -DestinationPath $Global:ora2pg 
			$ExtractedInstantclient = (Get-ChildItem -Filter "instantclient*" -Path $Global:ora2pg -directory).fullname
			

        }
        else
        {
		    # those files exist, therefore extract them
			
			$thebaseoraclezipfile = Get-ChildItem -Filter "$baseoraclezipfile" -Path "$Global:ScriptDir"
            write-outputAndLog "Extracting file $($thebaseoraclezipfile.fullname) ..."
            Extract-Archive -LiteralPath $thebaseoraclezipfile.fullname -DestinationPath $Global:ora2pg
			$thesdkoraclezipfile = Get-ChildItem -Filter "$sdkoraclezipfile" -Path "$Global:ScriptDir"
            write-outputAndLog "Extracting file $($thesdkoraclezipfile.Fullname) ..."
            Extract-Archive -Literalpath $thesdkoraclezipfile.fullname -DestinationPath $Global:ora2pg
			$ExtractedInstantclient = (Get-ChildItem -Filter "instantclient*" -Path $Global:ora2pg -directory).fullname
			
        }
        Rename-Item $ExtractedInstantclient $OracleInstallPath

    }
    else
    {
	    # found oci.dll somewhere which means that oracle client is installed
        write-outputAndLog "Found OCI.dll in $($result.FullName)"
        $Global:oraclehome = Split-Path -path $result.FullName
    }


}

# Function get dll file from exec file
 Function get-dllfile()
 {
    param(  [Parameter(Mandatory)]
        [string] $Pattern,
        [Parameter(Mandatory)]
        [string] $FileName
        )

      $FileContent = Get-Content  -Path $Filename -ErrorAction SilentlyContinue
      
      if ( $FileContent -ne $null )
      {
          $FileContent = $filecontent.tolower() | select-string "($Pattern)"  

          try {
             $Thefile = [regex]::Match($FileContent, "($Pattern)").groups[1].value
              }
           catch {
               $thefile=""
              }
          return $thefile
       }
       return ""
}

# function to install ora2pg
Function install-Ora2Pg()
{
    # set parent directory to c:\
    write-outputAndLog "Setting environment variable..."
    cd c:\
	# Add $gitfolder to path environment variable so git can be run
    $env:PATH = "$([Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine));{0}\bin" -f $GitFolder;
   


    write-outputAndLog "Checking whether ora2pg has been installed..."
	# supress error
    $ErrorActionPreference = 'SilentlyContinue'
	# execute ora2pg --version even if it doesnt exist
    if ( (Invoke-expression "ora2pg --version") -eq $null)
    {
	    # unsupress error
        $ErrorActionPreference = 'Continue'
        write-outputAndLog "ora2pg does not exist..."
		
		# if there is ora2pg on tempfile then delete it
        if ((Test-path -path $ora2pgTemp) -eq $True)
        {
            Remove-item $ora2pgTemp -Recurse -Force
        }
        write-outputAndLog "Cloning git repo to $ora2pgTemp ..."

        # supress error
        $ErrorActionPreference = 'SilentlyContinue'
		# execute git clone ora2pg even if it doesnt exist (assuming it does exist)
        Invoke-expression -command "git clone $ora2pgGit $ora2pgTemp" 
		# unsupress error
        $ErrorActionPreference = 'Continue'

        # Check whether ora2pg has been downloaded
        if ( (Test-path -path $ora2pgTemp) -eq $True)
        {
		   # this is to force ora2pg recompilation just incase there is a problem with the previous step
           cd $ora2pgTemp
           $ErrorActionPreference = 'SilentlyContinue'
           #perl Makefile.PL PREFIX=$global:ora2pg CONFDIR=$global:ora2pg
           perl Makefile.PL
           (Get-Content -Path Makefile -Raw) -replace 'C:\\strawberry',"$global:ora2pg\strawberry" -replace 'C:\\ora2pg',"$global:ora2pg\ora2pg" | set-content -LiteralPath Makefile -Force
           gmake
           gmake install
           Add-Content -Path $global:ora2pg\ora2pg.bat -Value "SET ORACLE_HOME=$global:ora2pg\instantclient`nSet LD_LIBRARY_PATH=%ORACLE_HOME%`nSET POSTGRESQL_HOME=$global:ora2pg\pgsql" -force
           Add-content -Path $global:ora2pg\ora2pg.bat -Value "SET PATH=$global:ora2pg\strawberry\c\bin;$global:ora2pg\strawberry\perl\site\bin;$global:ora2pg\strawberry\perl\bin;$global:ora2pg\instantclient;$global:ora2pg;%PATH%" -force
           (Get-content -Path "$global:ora2pg\strawberry\perl\site\bin\ora2pg.bat") -replace 'C:\\ora2pg',"$global:ora2pg\ora2pg" | set-content -LiteralPath "$global:ora2pg\strawberry\perl\site\bin\ora2pg.bat" -force
           Add-Content -Path $global:ora2pg\ora2pg.bat -Value (Get-content -Path "$global:ora2pg\strawberry\perl\site\bin\ora2pg.bat")
           $ErrorActionPreference = 'Continue'
           cd .. 
           Remove-Item $ora2pgtemp -Recurse -Force
           Remove-item "$global:ora2pg\temp" -Recurse -Force
           Remove-item $gitFolder -Recurse -Force
           Copy-Item C:\windows\system32\msvcr100.dll -Destination "$global:ora2pg\instantclient" -recurse -ErrorAction SilentlyContinue
           Copy-Item C:\windows\system32\msvcr120.dll -Destination "$global:ora2pg\instantclient" -recurse -ErrorAction SilentlyContinue
           Copy-Item C:\windows\system32\vcruntime140.dll -Destination "$global:ora2pg\instantclient" -recurse -ErrorAction SilentlyContinue
        }
    }
    else
    {
	    # display message that ora2pg has been installed
        write-outputAndLog "ora2pg is currently existing.. in order to upgrade it, please delete ora2pg.bat under $global:ora2pg\strawberry\perl\site\bin directory.."
        Write-OutputAndLog "`n=====================================================================================================`n`n"
		write-outputAndLog "........Press any key to exit............";
        return
    }

}

# fnction to move directory if doesnt exist
Function Move-Dir()
{
Param(
    [Parameter(Mandatory = $True)]
    [String] $Source,
    [String] $Destination)

        if (Test-Path -LiteralPath $Source ) 
        {
            try {
               Move-Item -LiteralPath $Source -Destination $Destination -ErrorAction Stop | Out-Null #-Force
            }
            catch {
               Write-Error -Message "Unable to move directory from '$Source' to '$Destintaion'. Error was: $_" -ErrorAction Stop
            }
            write-outputandLog "Successfully move directory from '$Source' to '$Destination'."
        }
        else 
        {
            write-outputandlog "Directory '$Source' doesnt exist"
        }
           

}

# fnction to create directory if doesnt exist
Function Create-Dir()
{
Param(
    [Parameter(Mandatory = $True)]
    [String] $DirectoryToCreate)

        if (-not (Test-Path -LiteralPath $DirectoryToCreate )) 
        {
            write-outputAndLog "Creating Directory '$DirectoryToCreate' ..."
            try {
               New-Item -Path $DirectoryToCreate -ItemType Directory -ErrorAction Stop | Out-Null #-Force
            }
            catch {
               Write-Error -Message "Unable to create directory '$DirectoryToCreate'. Error was: $_" -ErrorAction Stop
            }
            write-outputAndLog "Successfully created directory '$DirectoryToCreate'."
        }
        else 
        {
            write-outputAndLog "Directory '$DirectoryToCreate' already existed"
        }
           

}

# function to install perl library from CPAN
Function Install-PerlLib()
{
    Param(
        [Parameter(Mandatory)]
        [string] $name
        )

    write-outputAndLog "Executing cpan to install $name ..."
    $DirName = $name.replace("::","-")
    
    # check if the library.pm exists, if it is then delete the library.pm before it can be re-installed
    foreach ( $Disk in (Get-Volume | where { $_.DriveLetter -ne $null })) {
           $result = Get-childitem -path $Global:perl -Include "$Dirname*" -Exclude ("$Dirname*.pm","$Dirname*.gz") -recurse -erroraction SilentlyContinue 
           if ($result -ne $null)
           {
               write-outputAndLog "Removing item $Result .."
               Remove-item -path $Result -recurse -force
           }
       }

    
    # exeucte cpan 
    invoke-Expression -command "cpan -i $name"
    set-location "$result"
	# supress error
    $ErrorActionPreference = 'SilentlyContinue'
	# install perl library and if it is oracle it will force to use version 12.2.0
    perl Makefile.PL -V 12.2.0
    gmake
    gmake install
    $ErrorActionPreference = 'Continue'
    cd ..
    
}

    # this is an entry point of this powershell script
	
    # get the script name
	$TheScriptName = $MyInvocation.MyCommand.Name

    # check whether this script has been running
	$handle = get-process | where { $_.name -like 'powershell*' }
	
	# Check whether this is a windows container
	$foundService = Get-Service -Name cexecsvc -ErrorAction SilentlyContinue

    # check if the parameter has been passed to this scirpt
	if ( $Flag -eq 0 -and $handle.count -lt 4 -and ( $foundService -eq $null ))
	{
	    # if not then execute this script as administrator
		Start-process Powershell -verb runas -ArgumentList "-file `"$($MyInvocation.MyCommand.Definition)`" 1"
		$Env:ScriptName="$TheScriptName"
		# this will exit out but it will spawn this script again with administrator privilege
	}
	else
	{
	    # get the script directory location
        $Global:ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
		# execute the functions to check internet, install perl and oracle client
        Check-InstantClientVersion "instantclient*basic*"
		Check-Internet
        Create-Dir $global:ora2pg
        create-Dir $global:ora2pg\temp
        Install-pgsqlclient $global:ora2pg
		install-perl $global:Perl
       
		
		Check-OracleClient "$Global:oraclehome"

        $orasqlfile = Get-ChildItem -Path "$global:ora2pg\instantclient\orasql*.dll" -ErrorAction SilentlyContinue

        if ( $orasqlfile -ne $null)
        {

            $thedllfile = get-dllfile "msvc.*dll" $orasqlfile.FullName
		    if ( $thedllfile -ne "" )
            {
                $ReqdFile = Get-ChildItem -literalpath "c:\windows\system32\$thedllfile"
                if ( $reqdfile -eq $null )
                {
                    Write-OutputAndLog "File $thedllfile doesnt exist on c:\windows\system32"
                    Write-OutputAndLog "Please download required VC++ redistribution file from Microsoft website..."
                    Write-OutputAndLog "You need 2 files vcredist_x86 (Visual C++ redistributable 2010) and vcredist_x64 (Visual C++ Redistributable 2013)"
                    Write-OutputAndLog "Or msvcr100.dll and msvcr120.dll"
                    Write-OutputAndLog "`n=====================================================================================================`n`n"
		            write-outputAndLog "........Press any key to exit............";
		            #  requires press any key to exit
		            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
                    exit
                }
            }
         }


		


        # install portable git from the following url
		Install-FromExe -name git -url https://github.com/git-for-windows/git/releases/download/v2.23.0.windows.1/PortableGit-2.23.0-64-bit.7z.exe "-o $GitFolder -y"

        # set ORACLE_HOME and LD_LIBRARY_PATH environment variables
		$env:ORACLE_HOME="$Global:oraclehome"
		$env:LD_LIBRARY_PATH="$Global:oraclehome"
        
        $env:POSTGRESQL_HOME="$Global:ora2pg\pgsql"
        
		 
		# Check whether Oracle.pm is installed, if not then execute install perl library for DBD::Oracle
        $result = Get-ChildItem -path $Global:Perl -Include "Oracle.pm" -recurse
        if ($result -eq $null)
		{
            install-perllib "DBD::Oracle"
        }
		# check whether Pg.om is installed, if not then execute install per library for DBD::Pg
        $result = Get-ChildItem -path $Global:perl -Include "Pg.pm" -recurse
        if ($result -eq $null)
        {
            install-perllib "DBD::Pg"
        }
		# install ora2pg
		install-Ora2Pg
        Write-OutputAndLog "`n=====================================================================================================`n`n"
		write-outputAndLog "........Press any key to exit............";
		
		#  requires press any key to exit
		$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

}