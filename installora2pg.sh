#!/bin/bash
# $Id: installora2pg.sh 347 2020-09-22 09:18:37Z bpahlawa $
# Created 20-AUG-2019
# $Author: bpahlawa $
# $Date: 2020-09-22 17:18:37 +0800 (Tue, 22 Sep 2020) $
# $Revision: 347 $

#url basic and sdk instantclient for oracle 19c now doesnt require to accept license agreement
ORAINSTBASICURL="https://download.oracle.com/otn_software/linux/instantclient/19800/instantclient-basic-linux.x64-19.8.0.0.0dbru.zip?xd_co_f=27c74c5ade0e8f3e1141595923378611"
ORAINSTSDKURL="https://download.oracle.com/otn_software/linux/instantclient/19800/instantclient-sdk-linux.x64-19.8.0.0.0dbru.zip"
ORA2PG_GIT="https://github.com/darold/ora2pg.git"
DBD_ORACLE="https://www.cpan.org/modules/by-module/DBD"
PGSQLREPO="https://yum.postgresql.org/repopackages/"
PERLSOURCE="https://www.cpan.org/src/5.0/"
PERL5STABLE="5.32"
PGSQLSOURCE="https://ftp.postgresql.org/pub/source/v11.9/postgresql-11.9.tar.gz"

DEFPREFIX=/opt/localora2pg
PGVER="11"
INSTCLIENTKEYWORD="instantclient"
TMPFILE=/tmp/$0.$$
INTERNETCONN="1"

# User specific environment and startup programs
REDFONT="\e[01;48;5;234;38;5;196m"
GREENFONT="\e[01;38;5;46m"
NORMALFONT="\e[0m"
BLUEFONT="\e[01;38;5;14m"
YELLOWFONT="\e[0;34;2;10m"
VERSION_ID=""
ALLVER=""
export DISTRO=""
PKGDISTRO=""
RUNPKGUPDATE="1"

trap exitshell SIGINT SIGTERM

get_params_shadow()
{
   local OPTIND
   while getopts "v:lsbh" PARAM
   do
      manipulate_params "$PARAM" "$OPTARG" "1"
   done
   shift $((OPTIND-1))
}

manipulate_params()
{
      local OPTARG="$2"
      local LOPT="$3"
      [[ "$LOPT" = "0" ]] && OPTERR=0 || OPTERR=1
      case "$1" in
      v)
	  [[ "$OPTARG" =~ -.* ]] && return	  
          #pgver
	  if [[ "$OPTARG" =~ ^[0-9]+$ ]]
	  then
	      PGVER="${OPTARG}" 
	  else
	      echo -e "${REDFONT}Postgresql Version must be numeric...${NORMALFONT}" 
	      usage
	  fi
          ;;
      s)
          #Skip oracle client library search
          IGNORESEARCH="1"
          ;;
      l) 
	  [[ "$OPTARG" =~ -.* ]] && return	  
	  [[ "$PREFIX" != "" ]] && return
	  PREFIX=${OPTARG:=$DEFPREFIX} 
	  LOCALPERL="1"
	  ;;
      b)
	  #compressed ora2pg binary
	  ORA2PGBIN="1"
	  ;;
      h)
          #display this usage
          usage
          ;;
      *)
	  [[ "$LOPT" = "0" ]] && return
	  echo -e "\n${REDFONT}Invalid argument !!... ${NORMALFONT}"
	  usage
	  ;;
      esac
}


get_params()
{
   local OPTIND
   while getopts "v:l:sbh" PARAM
   do
      manipulate_params "$PARAM" "$OPTARG" "0"
   done
   shift $((OPTIND-1))

}

#this is how to use this script
usage()
{
   echo -e "\nUsage: \n    $0 -v <pgsql-version> -s -l <full-path-dir> -b"
   echo -e "\n    [-v] pgsql-version [10|12|11 11(default)]\n    [-s] ignore-oracle-client [ none(default)]\n    [-l] local-perl-install [/fullpath-dir | /opt/localora2pg(default)]"
   echo -e "    [-b] build-ora2pg-binary [ none(default)]\n"
   echo -e "    E.g: $0 -v 12 -s               #using pgsql version 12 client and skip oracle client library (use instantclient instead)"
   echo -e "         $0 -v 10                  #using pgsql version 10 and search oracle client library"
   echo -e "         $0 -b                     #create ora2pg binary file and generate file smallora2pg.bin, this file can be used for ora2pg offline installation"
   echo -e "         $0 -l /opt/localora2pg    #Install local perl (on /opt/localora2pg) and generate file localora2pg.bin, which includes ora2pg script, perl binary, postgresql client and their libraries"
   exit 1
}



get_distro_version()
{
   if [ -f /etc/os-release ]
   then
      ALLVER=`sed -n ':a;N;$bb;ba;:b;s/.*VERSION_ID="\([0-9\.]\+\)".*/\1/p' /etc/os-release`
      VERSION_ID=`echo $ALLVER | cut -f1 -d"."`
      export DISTRO=`sed -n 's/^ID[ \|=]\(.*\)/\1/p' /etc/os-release | sed 's/"//g'`
      DISTRO=${DISTRO^^}
   else
      echo "Unsupported operating system version!!"
      exit 1
   fi
}

exitshell()
{
   echo -e "${NORMALFONT}Cancelling script....exiting....."
   [[ -d ora2pg ]] && echo -e "${YELLOWFONT}Removing ora2pg source directory" && rm -rf ora2pg
   [[ -d "${DBDSOURCE}" ]] && echo -e "${YELLOWFONT}Removing ${DBDSOURCE} source directory and gz file${NORMALFONT}" && rm -rf "${DBDSOURCE}"*
   [[ -d "${DBDPGSOURCE}" ]] && echo -e "${YELLOWFONT}Removing ${DBDPGSOURCE} source directory and gz file${NORMALFONT}" && rm -rf "${DBDPGSOURCE}"*
   [[ -d "${SMALLORA2PG}" ]] && echo -e "${YELLOWFONT}Removing ${SMALLORA2PG} source directory${NORMALFONT}" && rm -rf "${SMALLORA2PG}"*
   [[ -d "${PGSQLCLIENT}" ]] && echo -e "${YELLOWFONT}Removing ${PGSQLCLIENT} source directory${NORMALFONT}" && rm -rf "${PGSQLCLIENT}"*
   exit 0
}

pkg_install()
{
 PKGDISTRO="${DISTRO,,}"
 [[ "$PKGDISTRO" = "rhel" ]] && PKGDISTRO="centos"

 PKG2INSTALL=`echo "$1" | sed -n "s/\(^\|.*:.*\)${PKGDISTRO}:\([a-zA-Z0-9\*-]\+\)\( .*:.*\|$\)/\2/p"`
 [[ `echo $1 | grep ":" | wc -l` -eq 0 ]] && [[ "$PKG2INSTALL" = "" ]] && PKG2INSTALL="$1" 
 [[ "$PKG2INSTALL" = "" ]] && return
 echo -e "${BLUEFONT}Checking $PKG2INSTALL package....."

    case "${DISTRO}" in
    "RHEL"|"CENTOS")
            [[ "$RUNPKGUPDATE" = "1" ]] && yum update all && RUNPKGUPDATE=0
            if [ $(yum list installed | grep "^${PKG2INSTALL}" | wc -l) -eq 0 ]
            then
                echo -e "${YELLOWFONT}installing ${PKG2INSTALL}....${NORMALFONT}" 
                yum -y install "${PKG2INSTALL}"
            fi
            ;;
    "UBUNTU")
            [[ "$RUNPKGUPDATE" = "1" ]] && apt update && RUNPKGUPDATE=0
            if [ $(apt list ${PKG2INSTALL} | grep "installed" | wc -l) -eq 0 ]
            then
                echo -e "${YELLOWFONT}installing ${PKG2INSTALL}....${NORMALFONT}"
                apt-get --yes install "${PKG2INSTALL}"
            fi
            ;;
    "ARCH")
            [[ "$RUNPKGUPDATE" = "1" ]] && echo "Y" | pacman -Syu && RUNPKGUPDATE=0
            echo "Y" | pacman -Sy $PKG2INSTALL
            ;;
    "DEBIAN")
            [[ "$RUNPKGUPDATE" = "1" ]] && apt update && RUNPKGUPDATE=0
            if [ $(apt list ${PKG2INSTALL} | grep "installed" | wc -l) -eq 0 ]
            then
                echo -e "${YELLOWFONT}installing ${PKG2INSTALL}....${NORMALFONT}"
                apt-get --yes install "${PKG2INSTALL}"
            fi
            ;;
    "OPENSUSE-LEAP")
	    [[ "$RUNPKGUPDATE" = "1" ]] && zypper refresh && RUNPKGUPDATE=0
	    if [ $(rpm -qa | grep "${PKG2INSTALL}" | wc -l) -eq 0 ]
            then
	       zypper install -y "${PKG2INSTALL}"
	    fi
            ;;
    "ALPINE")
            [[ "$RUNPKGUPDATE" = "1" ]] && apk update && apk add perl perl-dev && RUNPKGUPDATE=0
            apk add $PKG2INSTALL 
            ;;
     esac
   RVAL="$?"
   [[ "$PKG2INSTALL" = "wget" ]] && INTERNETCONN="$RVAL"
   echo -e "${GREENFONT}$PKG2INSTALL package is available......"
}


check_internet_conn()
{
   pkg_install wget
   echo -e "${BLUEFONT}Checking internet connection in progress....."
   [[ "$INTERNETCONN" != "0" ]] && echo -e "${REDFONT}Unable to connect to the internet!!${NORMALFONT}" && exit 1
   echo -e "${GREENFONT}Internet connection is available${NORMALFONT}"
   pkg_install which 
   pkg_install curl
   pkg_install git
   pkg_install "centos:gnupg2 ubuntu:gnupg2 debian:gnupg2 suse:gpg2 alpine:gnupg arch:gnupg"
   pkg_install "centos:iputils ubuntu:iputils-ping debian:iputils-ping"
   pkg_install "ubuntu:lsb-release debian:lsb-release"
   pkg_install "alpine:musl-dev"
   pkg_install "centos:perl-open"
   pkg_install "centos:perl-version"
   pkg_install "centos:perl-ExtUtils-MakeMaker ubuntu:libmodule-cpanfile-perl debian:libmodule-cpanfile-perl arch:perl-extutils-makemaker"
   pkg_install "centos:perl-DBI ubuntu:libdbi-perl debian:libdbi-perl alpine:perl-dbi arch:perl-dbi"
   pkg_install "centos:perl-Time-HiRes ubuntu:libtime-hires-perl debian:libtime-hires-perl alpine:perl-time-hires"
   pkg_install "centos:perl-Test-Simple ubuntu:libtest-simple-perl debian:libtest-simple-perl alpine:perl-test-simple arch:perl-test-simple"
   pkg_install "centos:libaio-devel ubuntu:libaio-dev debian:libaio-dev alpine:libaio-dev"
   pkg_install "centos:zlib-devel ubuntu:libz-dev debian:libz-dev alpine:libz-dev"
   pkg_install make
   pkg_install gcc
   pkg_install libnsl
   curl -kS --verbose --header 'Host:' $ORA2PG_GIT 2> $TMPFILE
   export GITHOST=`cat $TMPFILE | sed -n -e "s/\(.*CN=\)\([a-z0-9A-Z\.]\+\)\(,.*\|$\)/\2/p"`
   export GITIP=`ping -c1 -w1 github.com | sed -n -e "s/\(.*(\)\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\().*\)/\2/p"`
   [[ -f $TMPFILE ]] && rm -f $TMPFILE

}

install_dbd_postgres()
{
   PGCONFIGLOC="$1"

   if [ "$PGCONFIGLOC" = "" ]
   then
      PGCONFIGLOC=/usr
      echo -e "${BLUEFONT}Finding pg_config, if it has multiple pg_config then latest version will be used"
      PGCONFIGS=`find $PGCONFIGLOC -name "pg_config" | grep ${PGVER} | tail -1`
      [[ "$PGCONFIGS" = "" ]] && PGCONFIGS=`find /opt -name "pg_config" | grep ${PGVER} | tail -1`
      [[ "$PGCONFIGS" = "" ]] && PGCONFIGS=`find / -name "pg_config" | tail -1`
   else
      echo -e "${BLUEFONT}Installing Postgresql client from source code..."
      PGCONFIGS=`find $PGCONFIGLOC -name "pg_config" | tail -1`
   fi

   if [ "$PGCONFIGS" = "" ]
   then
      echo -e "${REDFONT}Postgres client or server is not installed..."
      echo -e "${BLUEFONT}if you want to install postgresql library for ora2pg then press ctrl+C to cancel this installation"
      echo -e "after that, Install postgresql client then re-run this installation!\n"
      echo -e "${YELLOWFONT}However, the ora2pg will be installed without postgresql library"
      echo -e "${GREENFONT}Sleeping for 5 seconds waiting for you to decide...\n\n"
      sleep 5
      echo -e "${BLUEFONT}Installing ora2pg without Postgresql Library........"
      return 0
   fi

   VER=0
   for PGCFG in $PGCONFIGS
   do
      echo -e "${BLUEFONT}Running $PGCFG to get the PostgreSQL version..."
      if [ $VER -lt `$PGCFG | grep VERSION | sed "s/\(.* \)\([0-9]\+\).*$/\2/g"` ]
      then  
         VER=`$PGCFG | grep VERSION | sed "s/\(.* \)\([0-9]\+\).*$/\2/g"` 
         PGCONFIG="$PGCFG"
      fi
   done
   echo -e "${GREENFONT}The latest PostgreSQL Version is $VER"
      
   export POSTGRES_HOME=${PGCONFIG%/*/*}
   echo -e "${BLUEFONT}Checking DBD-Pg latest version...."
   DBDFILE=`curl -kS "${DBD_ORACLE}/" | grep "DBD-Pg-.*tar.gz" | tail -1 | sed -n 's/\(.*="\)\(DBD.*gz\)\(".*\)/\2/p'`
   [[ ! -f ${DBDFILE} ]] && echo -e "${YELLOWFONT}Downloading DBD-Pg latest version...." && wget --no-check-certificate ${DBD_ORACLE}/${DBDFILE}
   echo -e "${BLUEFONT}Checking postgres development...."

   pkg_install "centos:postgresql*${PGVER}*devel ubuntu:postgresql*dev*${PGVER} debian:postgresql*dev*${PGVER}"
   echo -e "${GREENFONT}Extracting $DBDFILE${NORMALFONT}"
   tar xvfz ${DBDFILE}
   cd ${DBDFILE%.*.*}
   perl Makefile.PL
   if [ -f Makefile ]
   then
      echo -e "${YELLOWFONT}Compiling $DBDFILE${NORMALFONT}"
      make
      make install
      [[ $? -ne 0 ]] && echo -e "${REDFONT}Error in compiling ${DBDFILE%.*.*} ${NORMALFONT}" && exit 1
   fi
   cd ..
   export DBDPGSOURCE="${DBDFILE%.*.*}"
}


install_dbd_oracle()
{
   echo -e "${BLUEFONT}Checking DBD-Oracle latest version...."
   DBDFILE=`curl -kS "${DBD_ORACLE}/" | grep "DBD-Oracle.*tar.gz" | tail -1 | sed -n 's/\(.*="\)\(DBD.*gz\)\(".*\)/\2/p'`
   [[ ! -f ${DBDFILE} ]] && echo -e "${YELLOWFONT}Downloading DBD-Oracle latest version...." && wget --no-check-certificate ${DBD_ORACLE}/${DBDFILE}
   echo -e "${GREENFONT}Extracting $DBDFILE${NORMALFONT}"
   tar xvfz ${DBDFILE}
   cd ${DBDFILE%.*.*}
   perl Makefile.PL
   if [ -f Makefile ]
   then
      echo -e "${YELLOWFONT}Compiling $DBDFILE${NORMALFONT}"
      make
      make install
      [[ $? -ne 0 ]] && echo -e "${REDFONT}Error in compiling ${DBDFILE%.*.*} ${NORMALFONT}" && exit 1
   fi
   cd ..
   export DBDSOURCE="${DBDFILE%.*.*}"
}


install_ora2pg()
{
   ETCDIR="$1"
   if [ "$GITHOST" = "github.com" ]
   then
      echo -e "${BLUEFONT}Cloning git repository...${NORMALFONT}"
      git clone $ORA2PG_GIT
   else
      echo -e "${REDFONT}Server in github.com ssl certificate is different!!, Hostname=$GITHOST ${NORMALFONT}"
      echo -e "can not continue!!, there must be something wrong...."
      echo -e "GitIP $GITIP"
      exit 1
   fi
   cd ora2pg
   if [ "$ETCDIR" != "" ]
   then
	if [ "$LOCALPERL" = "1" ]
	then
	  sed -i "s|/etc/ora2pg|$ETCDIR|g" Makefile.PL
	else
	  sed -i "s|/etc/ora2pg/||g" Makefile.PL
        fi
   fi
   perl Makefile.PL
   if [ -f Makefile ]
   then
      echo -e "${YELLOFONT}Compiling ora2pg${NORMALFONT}"
      make
      make install
      [[ $? -ne 0 ]] && echo -e "${REDFONT}Error in compiling ora2pg...${NORMALFONT}" && exit 1
   fi
   echo -e "\n${GREENFONT}ora2pg has been compiled successfully\n${NORMALFONT}"
   cd ..
   [[ -d ora2pg ]] && echo -e "${YELLOWFONT}Removing ora2pg source directory" && rm -rf ora2pg
   [[ -d "${DBDSOURCE}" ]] && echo -e "${YELLOWFONT}Removing ${DBDSOURCE} source directory and gz file${NORMALFONT}" && rm -rf "${DBDSOURCE}"*
   [[ -d "${DBDPGSOURCE}" ]] && echo -e "${YELLOWFONT}Removing ${DBDPGSOURCE} source directory and gz file${NORMALFONT}" && rm -rf "${DBDPGSOURCE}"*

}

install_pgsqlclient()
{
    echo -e "${BLUEFONT}Installing Postgresql client from package distribution... ${NORALFONT}"
    case "$DISTRO" in
    "RHEL"|"CENTOS")
            PGCLIENT=`curl -kS "${PGSQLREPO}" | grep "EL-${VERSION_ID}-x86_64" | grep -v "non-free" | tail -1 | sed -n 's/\(.*="\)\(https.*rpm\)\(".*\)/\2/p'`
            rpm -ivh $PGCLIENT
            [[ ( "$DISTRO" = "CENTOS" || "$DISTRO" = "RHEL" ) && "${VERSION_ID}" -ge "8" ]] && yum -y module disable postgresql
            yum -y install postgresql${PGVER}
            ;;
    "UBUNTU")
            echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
            wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
            apt update
	    apt -y install postgresql-client-${PGVER}
            ;;
    "ARCH")
            echo "Y" | pacman -Sy postgresql
            ;;
    "DEBIAN")
            echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
            wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
            apt update
	    apt -y install postgresql-client-${PGVER}
            ;;
    "OPENSUSE-LEAP")
	    zypper ar -f -G http://download.opensuse.org/repositories/server:database:postgresql/openSUSE_Tumbleweed/ PostgreSQL
	    zypper refresh
	    zypper install -y postgresql10-devel

            ;;
    "ALPINE")
            apk add postgresql-client
            apk add postgresql-dev
            ;;
     esac
   
}

install_additional_libs()
{
   if [ \( "$DISTRO" = "CENTOS" -o "$DISTRO" = "RHEL" \) -a "${VERSION_ID}" = "6" ]
   then
      yum install -y perl-Time-modules perl-Time-HiRes
   fi
}
   

checking_ora2pg()
{
   echo -e "\n${BLUEFONT}Checking whether ora2pg can be run successfully!!"
   echo -e "Running ora2pg without parameter.........\n"
   echo -e "${YELLOWFONT}This ora2pg will depend on the following ORACLE_HOME directory:${GREENFONT} $ORACLE_HOME"
   if [ "$POSTGRES_HOME" != "" ] 
   then
      echo -e "${YELLOWFONT}This ora2pg will depend on the following POSTGRES_HOME directory:${GREENFONT} $POSTGRES_HOME\n"
   else
      echo -e "${BLUEFONT}This ora2pg is not linked to POSTGRES_HOME due to the unavailability of postgresql client/server package"
      echo -e "${BLUEFONT}You can install postgresql client/server package using dnf or yum REDHAT tool, and re-run this installation at anytime...\n"
   fi
   
   if [ "$SUDO_USER" = "" ]
   then
      echo -e "${YELLOWFONT}\nYou are running this script as ${BLUEFONT}root"
    
      printf "\nWhich Linux username who will run ora2pg tool? : $ERRCODE ";read THEUSER
      [[ "$THEUSER" = "" ]] && THEUSER=empty
      id $THEUSER 2>/dev/null
      while [ $? -ne 0 ] 
      do
          ERRCODE="Sorry!!, User : $THEUSER doesnt exist!!.. try again.."
          printf "$ERRCODE\nWhich user that will run this ora2pg tool? : ";read THEUSER
          [[ "$THEUSER" = "" ]] && THEUSER=empty
          id $THEUSER 2>/dev/null
      done
      printf "User : $THEUSER is available....\n"
      HOMEDIR=`su - $THEUSER -c "echo ~" 2>/dev/null`
   else
      echo -e "${YELLOWFONT}\nYou are running this script as ${BLUEFONT}$SUDO_USER"
      echo -e "\nUser : $SUDO_USER is running this installation, now setting up necessary environment variable"
      HOMEDIR=`su - $SUDO_USER -c "echo ~" 2>/dev/null`
      THEUSER="$SUDO_USER"
   fi

   [[ ! -d "$HOMEDIR" ]] && mkdir "$HOMEDIR" && chown $THEUSER "$HOMEDIR" 2>/dev/null
   if [ -f $HOMEDIR/.bash_profile ]
   then
      [[ `cat $HOMEDIR/.bash_profile | grep LD_LIBRARY_PATH | wc -l` -eq 0 ]] && echo "export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$ORACLE_HOME" >> $HOMEDIR/.bash_profile
   else
      echo "export ORACLE_HOME=$ORACLE_HOME" >> $HOMEDIR/.bash_profile
      echo "export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$ORACLE_HOME" >> $HOMEDIR/.bash_profile
   fi
   ln -sf $HOMEDIR/.bash_profile $HOMEDIR/.profile 2>/dev/null 1>/dev/null
	
   
   export PATH=/usr/local/bin:$PATH
   THEORA2PG=`which ora2pg`

   if [ "$THEUSER" = "root" ]
   then
      RESULT=`$THEORA2PG 2>&1`
   else
      RESULT=`su - $THEUSER -c "$THEORA2PG" 2>&1`
      if [ $? -ne 0 ]
      then
         CHECKERROR=`su - $THEUSER -c "$THEORA2PG 2>&1 | grep \"Can't locate\" | sed \"s/.*contains: \(.*\) \.).*$/\1/g\""`
         for THEDIR in $CHECKERROR
         do
            [[ -d $THEDIR ]] && echo "setting read and executable permission on PERL lib directory $THEDIR" && chmod o+rx $THEDIR
         done
      fi
   fi
   if [ $? -ne 0 ]
   then
      if [[ $RESULT =~ ORA- ]]
      then
          echo -e "${GREENFONT}ora2pg can be run successfully, however the ${REDFONT}ORA- error ${GREENFONT}could be related to the following issues:"
          echo -e "ora2pg.conf has wrong configuration, listener is not up or database is down!!"          
          echo -e "This installation is considered to be successfull...${NORMALFONT}\n"
          echo -e "\nPlease logout from this user, then login as $THEUSER to run ora2pg...\n"
          exit 0
      fi
      if [[ $RESULT =~ .*find.*configuration.*file ]]
      then
          echo -e "${GREENFONT}ora2pg requires ora2pg.conf...."
          echo -e "ora2pg has been installed successfully${NORMALFONT}"
          exit 0
      fi
      echo -e "${REDFONT}There some issues with ora2pg....${NORMALFONT}"
      echo -e "Usually this is due to LD_LIBRARY_PATH that was not set...."
      echo -e "${BLUEFONT}Enforcing LD_LIBRARY_PATH to $ORACLE_HOME/lib:$ORACLE_HOME"
      export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$ORACLE_HOME
      echo -e "${YELLOWFONT}Re-running ora2pg......"
      RESULT=`su - $THEUSER -c "$THEORA2PG" 2>&1`
      if [ $? -ne 0 ]
      then
          if [[ $RESULT =~ ORA- ]]
          then
              echo -e "${GREENFONT}ora2pg can be run successfully, however ${REDFONT}the ORA- error ${GREENFONT}could be related to the following issues:"
              echo -e "ora2pg.conf has wrong configuration, listener is not up or database is down!!"          
              echo -e "This installation is considered to be successfull...${NORMALFONT}\n"
              echo -e "\nPlease logout from this user, then login as $THEUSER to run ora2pg...\n"
              exit 0
          else
              echo -e "${REDFONT}The issues are not resolved, please check logfile....!!${NORMALFONT}"
              exit 1
          fi
      fi
   fi
   echo -e "${GREENFONT}ora2pg can be run successfully"
   echo -e "${NORMALFONT}Before running ora2pg you must do:"
   echo -e "export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$ORACLE_HOME"
}

download_instantclient19c()
{
   FILENAME="$1"
   URL="$2"
   DESCRIPTION="$3"
   echo -e "${BLUEFONT}${DESCRIPTION}${NORMALFONT}"
   wget -O "${FILENAME}" "${URL}" 2>/dev/null 1>/dev/null
   [[ $? -ne 0 ]] && echo -e "${REDFONT}Unable to download $DESCRIPTION from URL $URL , you may need to change the URL within this script!!, or the URL has been relocated!!\nExiting....${NORMALFONT}" && exit 1

}

build_pgsql()
{
   [[ "$1" != "" ]] && PREFIX="$1"
   echo -e "${BLUEFONT}Installing postgresql client from source code into $PREFIX...${NORMALFONT}"
   [[ -f $PGSQLSOURCE ]] && rm -f $PGSQLSOURCE
   wget $PGSQLSOURCE
   PGSQLSRCFILE=`basename $PGSQLSOURCE`
   PGSQLSRCDIR=`basename $PGSQLSOURCE | sed 's/.tar.gz//g'`
   if [ -f $PGSQLSRCFILE ]
   then
        echo -e "${GREENFONT}Postgresql source code $PGSQLSRCFILE has been successfully downloaded!!"
        echo -e "Extracting $PGSQLSRCFILE ....${NORMALFONT}"
        tar xvfz $PGSQLSRCFILE
	rm -f $PGSQLSRCFILE
        [[ $? -ne 0 ]] && echo -e "${REDFONT}Failed extracting file $PGSQLSRCFILE .. pleaes re-run this script to re-download it..${NORMALFONT}" && exit 1
        cd $PGSQLSRCDIR
        echo -e "${BLUEFONT}Configuring Postgresql ...........${NORMALFONT}"
        ./configure --prefix=$PREFIX --exec-prefix=$PREFIX --without-readline
        echo -e "${BLUEFONT}Building Postgresql client ..........${NORMALFONT}"
	make -C src/bin install
	make -C src/include install
	make -C src/interfaces install
	make -C doc install
	cd ..
	rm -rf $PGSQLSRCDIR
   else
	echo -e "${REDFONT}Failed to Download Postgresql source code from $PGSQLSOURCE please check and re-run this script..... ${NORMALFONT}" 
	exit 1
   fi
}

copy_reqlib()
{
   local LIBDIR="$1"
   local TARGETDIR="$2"
   GLIBCVER=`find /usr/lib /usr/lib64 /lib /lib64 -name "libc.so.6" -exec readlink -f {} \; | awk -F / '{print $NF}' | sed 's/.*\-\([0-9\.]\+\)\..*/\1/g' 2>/dev/null`

   echo -e "${BLUEFONT}Copying required libraries to $TARGETDIR ${NORMALFONT}"
   find $LIBDIR -type f -exec ldd {} \; 2>/dev/null | grep -Ev "not a dynamic|not regular file|statically linked|Not a valid|not found" | egrep -v "\-vdso|ld\-|libdl\-|libdl.so|librt.so|librt\-|thread|libc.so" |  awk '{print $(NF-1)}' | sort | uniq > $TMPFILE
   local CURRDIR=`pwd`
   while read -r DEPLIB
   do
        DLIBFILE=`basename $DEPLIB`
        if [ -L $DEPLIB ]
        then
           LIBTFILE=`readlink $DEPLIB | awk -F / '{print $NF}'`
           REALFILE=`readlink -f $DEPLIB`
           [[ "$REALFILE" != "" ]] && [[ ! -f $TARGETDIR/$DLIBFILE ]] && cp $REALFILE $TARGETDIR 2>/dev/null
	   cd $TARGETDIR
           if [ "$LIBTFILE" = "$DLIBFILE" ]
           then
              ln -s $(basename $REALFILE) $LIBTFILE
              echo -e "ln -s $(basename $REALFILE) $LIBTFILE"
           else
              ln -s $LIBTFILE $DLIBFILE
              echo -e "ln -s $LIBTFILE $DLIBFILE"
           fi
	   cd $CURRDIR
        else
           [[ ! -f $TARGETDIR/$DLIBFILE ]] &&  cp $DEPLIB $TARGETDIR 2>/dev/null && echo -e "cp $DEPLIB $TARGETDIR"
        fi
   done < $TMPFILE
   [[ -f $TMPFILE ]] && rm -f $TMPFILE
}

remove_duplicate_libs()
{
   local SOURCEDIR="$1"
   local TARGETDIR="$2"
   for FILE2RM in `ls -1 $SOURCEDIR`
   do
       [[ -f $TARGETDIR/$FILE2RM ]] && rm -f $TARGETDIR/$FILE2RM
   done
}

 
build_localperl()
{
   echo -e "${BLUEFONT}Installing local ora2pg into $PREFIX..."
   echo -e "After this installation $PREFIX can be copied to any other linux distro as long as it has libc.so.6 ${NORMALFONT}"
   PERLSRC=`curl -kSs  $PERLSOURCE | sed -n 's/\(.*="\)\(perl-[0-9_.]\+.tar.gz\)\(".*\)/\2/p' | grep "$PERL5STABLE" | sed 's/perl-5.//g' | sort -n | tail -1 2>/dev/null`
   [[ "$PERLSRC" = "" ]] && echo -e "${REDFONT}Unable to download latest perl source code from url $PERLSOURCE .... please check the link...exiting...${NORMALFONT}" && exit 1
   PERL5VER=`echo perl-5.$PERLSRC | sed 's/.tar.gz//g'`
   [[ -f $PERL5VER.tar.gz ]] && rm -f $PERL5VER.tar.gz
   wget $PERLSOURCE/$PERL5VER.tar.gz
   if [ -f $PERL5VER.tar.gz ]
   then
	[[ -d $PERL5VER ]] && rm -rf $PERL5VER
	echo -e "${GREENFONT}Perl source code $PERL5VER has been successfully downloaded!!"
	echo -e "Extracting $PERL5VER.tar.gz ...."
	tar xvfz $PERL5VER.tar.gz
	rm -f $PERL5.tar.gz
	[[ $? -ne 0 ]] && echo -e "${REDFONT}Failed extracting file $PERL5VER.tar.gz .. pleaes re-run this script to re-download it..${NORMALFONT}" && exit 1
	cd $PERL5VER
	echo -e "${BLUEFONT}Configuring local perl ...........${NORMALFONT}"
	./Configure -Dprefix=$PREFIX -Dcc=gcc -Dusethreads -Duselargefiles -Dcccdlflags=-fPIC -Doptimize=-O2 -Duseshrplib -Duse64bitall -de
	echo -e "${BLUEFONT}Building local perl ..........${NORMALFONT}"
	make
	echo -e "${BLUEFONT}Testing local perl ..........${NORMALFONT}"
	make test
	echo -e "${BLUEFONT}Installing local perl ..........${NORMALFONT}"
	make install
	echo -e "${BLUEFONT}Checking local perl ..........${NORMALFONT}"
	cd ..
	rm -rf $PERL5VER
        $PREFIX/bin/perl --version 
	[[ $? -ne 0 ]] && echo -e "${REDFONT}Failed to install local perl.. please check and re-run this script..... ${NORMALFONT}" && exit 1
	echo "${GREENFONT}Perl has been installed successfully...${NORMALFONT}"
   else
	echo -e "${REDFONT}Failed to Download perl source code from $PERLSOURCE please check and re-run this script..... ${NORMALFONT}" 
	exit 1
   fi
}

build_ora2pg_binary()
{
   SMALLORA2PG=~/.smallora2pg
   [[ ! -d $SMALLORA2PG ]] && mkdir $SMALLORA2PG || rm -rf $SMALLORA2PG/*
   CURRDIR=`pwd`
   if [ "$LOCALPERL" = "1" ]
   then
       DIRTOSEARCH=$PREFIX 
       export PERL_BASE="$PREFIX"
       export PATH="$PERL_BASE/bin${PATH:+:$PATH}"
       export MANPATH="$PERL_BASE/man${MANPATH:+:$MANPATH}"
       export POSTGRES_HOME=$PERL_BASE
       LIBFILE=`find $PREFIX -name "libclntsh.so*" | grep -v "$PREFIX/lib" 2>/dev/null | tail -1 2>/dev/null`
       ORA2PGCONFFILE=`find $PREFIX -name "ora2pg*conf*" 2>/dev/null`
   else
       DIRTOSEARCH="/usr"
       LIBFILE=`find /usr/local -name "libclntsh.so*" 2>/dev/null| grep -Ev "stage|inventory" | tail -1 2>/dev/null`
       LIBPERL=`find /lib/ -name "libperl*" 2>/dev/null | tail -1 2>/dev/null`
       [[ "$LIBPERL" = "" ]] && echo -e "${REDFONT}Failed to find libperl library...exiting...${NORMALFONT}" && exit 1
       DIRLIBPERL=`dirname $LIBPERL`
       cd $DIRLIBPERL
       ln -s $LIBPERL libperl.so 2>/dev/null
       copy_reqlib $DIRLIBPERL/libperl.so $SMALLORA2PG
       ORA2PGCONFFILE=`find /etc/ora2pg -name "ora2pg*conf*" 2>/dev/null`
   fi
   [[ "$ORA2PGCONFFILE" != "" ]] && cp $ORA2PGCONFFILE $SMALLORA2PG
   export ORACLE_HOME="${LIBFILE%/*}"
   export LD_LIBRARY_PATH="$ORACLE_HOME"
   cd $CURRDIR
   perl -MCPAN -e 'install PAR::Packer'

   ORA2PGFILE=`find $DIRTOSEARCH -name "ora2pg" 2>/dev/null | tail -1 2>/dev/null`
   [[ "$ORA2PGFILE" = "" ]] && echo -e "${REDFONT}Can not find ora2pg script...exiting.... ${NORMALFONT}" && exit 1

   cp $ORA2PGFILE /tmp
   sed -i "s/\(.*CONFIG_FILE = \)\".*\(ora2pg.conf\)/\1\"ora2pg.conf/g" /tmp/ora2pg
   pp -o $SMALLORA2PG/ora2pg /tmp/ora2pg
   [[ $? -ne 0 ]] && echo "${REDFONT}Unable to convert ora2pg script to a binary file...exiting...${NORMALFONT}" && exit 1
   rm -f /tmp/ora2pg
   
   PGSQLDEPLIBS=`find $DIRTOSEARCH -name "Pg.so" 2>/dev/null | tail -1 2>/dev/null`
   ORACLEDEPLIBS=`find $DIRTOSEARCH -name "Oracle.so" 2>/dev/null | tail -1 2>/dev/null`
   copy_reqlib $PGSQLDEPLIBS $SMALLORA2PG
   copy_reqlib $ORACLEDEPLIBS $SMALLORA2PG
   copy_reqlib $ORACLE_HOME/genezi $SMALLORA2PG
   cp $ORACLE_HOME/*oci*.so $SMALLORA2PG
   echo -e "${BLUEFONT}Gzipping $SMALLORA2PG into $(pwd)/smallora2pg.tar.gz${NORMALFONT}"
   cd $SMALLORA2PG
   tar cvfz $CURRDIR/smallora2pg.tmp *
   cd $CURRDIR

   printf "#!/bin/bash
CURRDIR=\`pwd\`
BUILTGLIBCVER=$GLIBCVER
[[ \"\$USER\" != \"root\" && \"\$USER\" != \"\" ]] && echo \"root is needed to extract this package....exiting...\" && exit 1
THISGLIBC=\`find /usr/lib /usr/lib64 /lib /lib64 -name \"libc.so.6\" -exec readlink -f {} \\; | awk -F / '{print \$NF}' | sed 's/.*\-\\([0-9\.]\\+\\)\\..*/\\\\1/g'\`
VER=\`echo \"\$BUILTGLIBCVER \$THISGLIBC\" | awk '{printf(\"%%d\",\$1-\$2<=0?0:1)}'\`
[[ \$VER -gt 0 ]] && echo \"This package required GLIBC version >= \$BUILTGLIBCVER, this system has GLIBC version \$THISGLIBC\" && exit 1
PAYLOAD_LINE=\`awk '/^__PAYLOAD_BELOW__/ {print NR + 1; exit 0; }' \$CURRDIR/\$0\`
printf \"\\\\nWhich Linux username who will run ora2pg tool? : \$ERRCODE \";read THEUSER
[[ \"\$THEUSER\" = \"\" ]] && THEUSER=empty
id \$THEUSER 2>/dev/null
while [ \$? -ne 0 ] 
do
    ERRCODE=\"Sorry!!, User : \$THEUSER doesnt exist!!.. try again..\"
    printf \"\\\\n\\\\n\$ERRCODE\\\\nWhich user that will run this ora2pg tool? : \";read THEUSER
    [[ \"\$THEUSER\" = \"\" ]] && THEUSER=empty
    id \$THEUSER 2>/dev/null
done
HOMEDIR=\`grep \"\$THEUSER:\" /etc/passwd | cut -f6 -d:\`
[[ ! -d \$HOMEDIR/ora2pg ]] && mkdir -p \$HOMEDIR/ora2pg && chown -R \$THEUSER \$HOMEDIR
tail -n+\$PAYLOAD_LINE \$CURRDIR/\$0 | tar -xvz -C \$HOMEDIR/ora2pg
printf \"
export PATH=\\\\\"\$HOMEDIR/ora2pg\\\${PATH:+:\\\$PATH}\\\\\"
export LD_LIBRARY_PATH=\$HOMEDIR/ora2pg\\\\n\" > \$HOMEDIR/.bash_profile
ln -sf \$HOMEDIR/.bash_profile \$HOMEDIR/.profile
exit 0
__PAYLOAD_BELOW__\n" > smallora2pg.bin
   chmod ugo+rx smallora2pg.bin
   cat smallora2pg.tmp >> smallora2pg.bin
   [[ -f smallora2pg.tmp ]] && rm -f smallora2pg.tmp
   [[ -d $SMALLORA2PG ]] && rm -rf $SMALLORA2PG
}


install_ora2pg_locally()
{
   [[ ! -f $PREFIX/bin/perl ]] && build_localperl
   export PERL_BASE="$PREFIX"
   export PATH="$PERL_BASE/bin${PATH:+:$PATH}"
   export MANPATH="$PERL_BASE/man${MANPATH:+:$MANPATH}"
   export POSTGRES_HOME=$PERL_BASE
   LIBNZFILE=`find $PREFIX -name "libnnz*" 2>/dev/null`
   [[ "$LIBNZFILE" = "" ]] && install_oracle_instantclient
   export ORACLE_HOME=`ls -1d $PREFIX/instantclient* | tail -1 2>/dev/null`
   [[ "$ORACLE_HOME" = "" ]] && echo -e "${REDFONT}ORACLE_HOME is not set.... it may be that instantclient is not installed on $PREFIX .. please check and re-run this script..${NORMALFONT}" && exit 1
   export LD_LIBRARY_PATH="$PREFIX/lib:$ORACLE_HOME"
   CURRDIR=`pwd`


   [[ `find $PREFIX -name "Oracle.so" | wc -l` -eq 0 ]] && perl -MCPAN -e 'install DBD' && perl -MCPAN -e 'install DBD::Oracle'
   [[ `find $PREFIX -name "Pg.so" | wc -l` -eq 0 ]] && perl -MCPAN -e 'install DBD::Pg'
   [[ ! -f $PREFIX/bin/pg_config ]] && build_pgsql
   [[ ! -d $PREFIX/etc ]] && mkdir -p $PREFIX/etc
   [[ `find $PREFIX -name "ora2pg" | wc -l` -eq 0 ]] && install_ora2pg $PREFIX/etc
   echo -e "${BLUEFONT}Copying required libraries ....${NORMALFONT}"
   copy_reqlib $PREFIX $PREFIX/lib
   echo -e "${BLUEFONT}Removing duplicate libraries on $PREFIX/lib which already available on $ORACLE_HOME....${NORMALFONT}"
   remove_duplicate_libs $ORACLE_HOME $PREFIX/lib
   echo -e "${BLUEFONT}Gzipping $PREFIX into $(pwd)/localora2pg.tar.gz${NORMALFONT}"
   tar cvfz localora2pg.tmp $PREFIX/*

   printf "#!/bin/bash
CURRDIR=\`pwd\`
BUILTGLIBCVER=$GLIBCVER
[[ \"\$USER\" != \"root\" && \"\$USER\" != \"\" ]] && echo \"root is needed to extract this package....exiting...\" && exit 1
THISGLIBC=\`find /usr/lib /usr/lib64 /lib /lib64 -name \"libc.so.6\" -exec readlink -f {} \\; | awk -F / '{print \$NF}' | sed 's/.*\-\\([0-9\.]\\+\\)\\..*/\\\\1/g'\`
VER=\`echo \"\$BUILTGLIBCVER \$THISGLIBC\" | awk '{printf(\"%%d\",\$1-\$2<=0?0:1)}'\`
[[ \$VER -gt 0 ]] && echo \"This package required GLIBC version >= \$BUILTGLIBCVER, this system has GLIBC version \$THISGLIBC\" && exit 1
PAYLOAD_LINE=\`awk '/^__PAYLOAD_BELOW__/ {print NR + 1; exit 0; }' \$CURRDIR/\$0\`
cd /
tail -n+\$PAYLOAD_LINE \$CURRDIR/\$0 | tar -xvz
printf \"\\\\nWhich Linux username who will run ora2pg tool? : \$ERRCODE \";read THEUSER
[[ \"\$THEUSER\" = \"\" ]] && THEUSER=empty
id \$THEUSER 2>/dev/null
while [ \$? -ne 0 ] 
do
    ERRCODE=\"Sorry!!, User : \$THEUSER doesnt exist!!.. try again..\"
    printf \"\\\\n\\\\n\$ERRCODE\\\\nWhich user that will run this ora2pg tool? : \";read THEUSER
    [[ \"\$THEUSER\" = \"\" ]] && THEUSER=empty
    id \$THEUSER 2>/dev/null
done
HOMEDIR=\`grep \"\$THEUSER:\" /etc/passwd | cut -f6 -d:\`
[[ ! -d \$HOMEDIR ]] && mkdir \$HOMEDIR && chown \$THEUSER \$HOMEDIR
printf \"export PERL_BASE=\\\\\"$PREFIX\\\\\"
export PATH=\\\\\"\\\$PERL_BASE/bin\\\${PATH:+:\\\$PATH}\\\\\"
export MANPATH=\\\\\"\\\$PERL_BASE/man\\\${MANPATH:+:\\\$MANPATH}\\\\\"
export ORACLE_HOME=\\\\\"$ORACLE_HOME\\\\\"
export LD_LIBRARY_PATH=\\\$PERL_BASE/lib:\\\$ORACLE_HOME
export POSTGRES_HOME=\\\\\"\\\$PERL_BASE\\\\\"\\\\n\" > \$HOMEDIR/.bash_profile
ln -sf \$HOMEDIR/.bash_profile \$HOMEDIR/.profile
chown -R \$THEUSER $PREFIX
exit 0
__PAYLOAD_BELOW__\n" > localora2pg.bin
   chmod ugo+rx localora2pg.bin
   cat localora2pg.tmp >> localora2pg.bin
   rm -f localora2pg.tmp

   [[ "$ORA2PGBIN" = "1" ]] && build_ora2pg_binary
}
   


install_oracle_instantclient()
{
   pkg_install unzip
   echo -e "${BLUEFONT}Installing oracle instant client"
   echo -e "${YELLOWFONT}Finding instantclient filename with keyword=${INSTCLIENTKEYWORD}${NORMALFONT}"
   find -quit 2>/dev/null 1>/dev/null
   [[ $? -eq 0 ]] && QUITCMD="-quit"
   INSTCLIENTFILE=`find . \( -not -name "*${INSTCLIENTKEYWORD}*sdk*linux*" -a -name "*${INSTCLIENTKEYWORD}*linux*" \) -print $QUITCMD`
   if [[ "$INSTCLIENTFILE" = "" ]]
   then
      INSTCLIENTFILE=`find . -name "*${INSTCLIENTKEYWORD}*" -print $QUITCMD | grep -v sdk`
      if [[ "$INSTCLIENTFILE" = "" ]]
      then
         echo -e "${YELLOWFONT}Oracle instant client file doesnt exist....${NORMALFONT}"
      else
         echo -e "${YELLOWFONT}Oracle instant client file $INSTCLIENTFILE has been found.... but it is not for linux, please download the correct file!..${NORMALFONT}"
      fi
      echo -e "\n========================ATTENTION============ATTENTION============================================="
      echo -e "Trying to download oracle basic instant client 19c.... "
      echo -e "Pleaes NOTE that oracle instant client 19c only works with oracle 12c or later..."
      echo -e "if your Oracle database is version 11g or earlier, please cancel this script by pressing ctrl+c right now!!"
      echo -e "and then download oracle instantclient 12c from oracle website\n"
      download_instantclient19c "${INSTCLIENTKEYWORD}-basic-linux.zip" "${ORAINSTBASICURL}" "Oracle basic instantclient 19c"
      INSTCLIENTFILE="${INSTCLIENTKEYWORD}-basic-linux.zip"
   fi

   INSTCLIENTSDKFILE=`find . -name "*${INSTCLIENTKEYWORD}*sdk*linux*" -print $QUITCMD`
   if [[ "$INSTCLIENTSDKFILE" = "" ]]
   then
      INSTCLIENTSDKFILE=`find . -name "*${INSTCLIENTKEYWORD}*sdk*" -print $QUITCMD`
      if [[ "$INSTCLIENTSDKFILE" = "" ]]
      then
          echo -e "${YELLOWFONT}Oracle instant client sdk file doesnt exist....${NORMALFONT}"
      else
          echo -e "${YELLOWFONT}Oracle instant client sdk file $INSTCLIENTSDKFILE has been found.... but not for linux, please download the correct file!....${NORMALFONT}"
      fi
      echo -e "\n========================ATTENTION============ATTENTION============================================="
      echo -e "Trying to download oracle sdk instant client 19c.... "
      echo -e "Pleaes NOTE that oracle instant client 19c only works with oracle 12c or later..."
      echo -e "if your Oracle database is version 11g or earlier, please cancel this script by pressing ctrl+c right now!!"
      echo -e "and then download oracle instantclient 12c from oracle website\n"
      download_instantclient19c "${INSTCLIENTKEYWORD}-sdk-linux.zip" "${ORAINSTSDKURL}" "Oracle sdk instantclient 19c"
      INSTCLIENTSDKFILE="${INSTCLIENTKEYWORD}-sdk-linux.zip"
   fi
    
       
    if [ "$LOCALPERL" = "1" ]
    then
	unzip -o $INSTCLIENTFILE -d $PREFIX 
        [[ $? -ne 0 ]] && echo -e "${REDFONT}Unzipping file $INSTCLIENTFILE failed!!${NORMALFONT}" && exit 1
	unzip -o $INSTCLIENTSDKFILE -d $PREFIX  
        [[ $? -ne 0 ]] && echo -e "${REDFONT}Unzipping file $INSTCLIENTSDKFILE failed!!${NORMALFONT}" && exit 1
        echo -e "${GREENFONT}File $INSTCLIENTFILE has been unzipped successfully!!"
        LIBFILE=`find $PREFIX -name "libclntsh.so*" 2>/dev/null| grep -Ev "stage|inventory" | tail -1 2>/dev/null`
    else
	unzip -o $INSTCLIENTFILE -d /usr/local
        [[ $? -ne 0 ]] && echo -e "${REDFONT}Unzipping file $INSTCLIENTFILE failed!!${NORMALFONT}" && exit 1
	unzip -o $INSTCLIENTSDKFILE -d /usr/local
        [[ $? -ne 0 ]] && echo -e "${REDFONT}Unzipping file $INSTCLIENTSDKFILE failed!!${NORMALFONT}" && exit 1
        echo -e "${GREENFONT}File $INSTCLIENTFILE has been unzipped successfully!!"
        LIBFILE=`find /usr/local -name "libclntsh.so*" 2>/dev/null| grep -Ev "stage|inventory" | tail -1 2>/dev/null`
    fi 
    export ORACLE_HOME="${LIBFILE%/*}"
    export LD_LIBRARY_PATH="$ORACLE_HOME"
}

   [[ $(whoami) != "root" ]] && echo -e "${REDFONT}This script must be run as root or with sudo...${NORMALFONT}" && exit 1
   get_params "$@"
   get_params_shadow "$@"
   echo -e "${GREENFONT}Installing ora2pg with the following features: ${NORMALFONT}"
   [[ "$PREFIX" != "" ]] && echo -e "${GREENFONT}Local perl Directory: $PREFIX ....${NORMALFONT}"
   [[ "$ORA2PGBIN" = "1" ]] && echo -e "${GREENFONT}Building ora2pg binary ....${NORMALFONT}"
   [[ "$PGVER" != "" ]] && echo -e "${GREENFONT}Using Postgresql client version $PGVER ....${NORMALFONT}"
   [[ "$IGNORESEARCH" = "1" ]]  && export ORACLE_HOME=/usr/local && echo -e "${GREENFONT}Ignoring current Oracle Client package...${NORMALFONT}"
   get_distro_version
   echo "Running linux distribution $DISTRO version $ALLVER"
   check_internet_conn
   echo -e "${BLUEFONT}Checking oracle installation locally....."

   [[ "$LOCALPERL" = "1" ]] && install_ora2pg_locally && exit 0

   echo -e "${BLUEFONT}Checking ORACLE_HOME environment variable...."
   if [ "$ORACLE_HOME" != "" ]
   then
      if [ ! -d $ORACLE_HOME ]
      then
         echo -e "${BLUEFONT}The $ORACLE_HOME is not a directory, so searchig from root directory / ...."
         LIBFILE=`find /usr -name "libclntsh.so*" 2>/dev/null| grep -Ev "stage|inventory" | tail -1 2>/dev/null`
         [[ "$LIBFILE" = "" ]] && LIBFILE=`find /opt -name "libclntsh.so*" 2>/dev/null| grep -Ev "stage|inventory" | tail -1 2>/dev/null`
      else
         LIBFILE=`find $ORACLE_HOME -name "libclntsh.so*" 2>/dev/null| grep -Ev "stage|inventory" | tail -1 2>/dev/null`
      fi
   else
      LIBFILE=`find /usr -name "libclntsh.so*" 2>/dev/null| grep -Ev "stage|inventory" | tail -1 2>/dev/null`
      [[ "$LIBFILE" = "" ]] && LIBFILE=`find /usr -name "libclntsh.so*" 2>/dev/null| grep -Ev "stage|inventory" | tail -1 2>/dev/null`
   fi
   if [ "$LIBFILE" = "" ]
   then
      [[ "$IGNORESEARCH" = "1" ]] && unset ORACLE_HOME
      echo -e "${BLUEFONT}oracle instantclient needs to be installed or $ORACLE_HOME is not correct"
      install_oracle_instantclient
   else
      if [[ $LIBFILE =~ .*${INSTCLIENTKEYWORD}.*$ ]]
      then
         export ORACLE_HOME="${LIBFILE%/*}"
      else
         export ORACLE_HOME="${LIBFILE%/*/*}"
      fi
   fi
   install_additional_libs
   install_dbd_oracle
   [[ "$ORA2PGBIN" = "1" ]] && PGSQLCLIENT=~/.pgsqlclient && mkdir $PGSQLCLIENT && build_pgsql $PGSQLCLIENT || install_pgsqlclient
   install_dbd_postgres $PGSQLCLIENT
   install_ora2pg
   [[ "$ORA2PGBIN" = "1" ]] && build_ora2pg_binary && rm -rf $PGSQLCLIENT && install_dbd_postgres && [[ -d "${DBDPGSOURCE}" ]] && rm -rf "${DBDPGSOURCE}"*
   checking_ora2pg
