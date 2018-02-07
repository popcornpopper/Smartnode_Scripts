#!/bin/bash
#
#  Smartnode Health Check report v1.0
#
#  This script helps to quickly determine the root cause of Smartnode issues.
#  Assumptions: This script is intended to be run on a completely configured Smartnode.
#               Not intended for incomplete Smartnode Installations.
#  Author : popcornpopper  . Created Feb 4, 2018
#
#  smartnode_health_check.sh -
#      Provides a robust end-to-end verification of a Smartnode.
#      Performs the following checks:
#         1. check_smartcashd_process - Checks if your smartcashd daemon process is running
#         2. check_sc_status - Checks status of your smartcashd. Runs smartcash-cli smartnode status
#         3. check_crons - Checks all official cron scripts if you have them scheduled.
#         4. check_cron_scripts_if_official - Checks cron scripts if they are identical to the official Smartcash Smartnode scripts 
#         5. check_sc_port - Checks smartcashd daemon port to ensure its listening and its not blocked by internal/external firewalls.
#         6. check_web_status - Checks smartcashd daemon port, verifies if its communicable from external internet.
#         7. check_system_stats - Checks your server's CPU and MEMORY stats and verify if its within reasonable thresholds
#         8. check_disk_space - Checks each filesystem is within space thresholds ( default : not less than 50% used ; free space > 12GB )
#
#  INSTRUCTIONS
#  1. Download this script :
#         $ wget https://raw.githubusercontent.com/popcornpopper/Smartnode_Scripts/master/smartnode_health_check.sh
#  2. This script can be ran either as root user or smartadmin user. Run below command :
#         $ bash ./smartnode_health_check.sh
#

clear
PATH=/bin:/usr/bin:/sbin:$PATH
export PATH

######   FUNCTIONS
check_disk_space () {
   # check_disk_space v1.2 - popcornpopper
   FAIL=0
   IFS=\$
   for fspct in `df -k  |grep -v ^Filesystem | awk '{ print $5" "$4" "$6"\$" }' | sort -nr | tr -d '\012' `
   do

   fs=`echo -n $fspct | awk '{ print $3 }' `
   pct=`echo -n $fspct | awk '{ print $1 }' | tr -d \% `
   size=`echo -n $fspct | awk '{ print $2 }' |tr -d ' ' `
   if [ $pct -gt $FREE_PCT_THRESHOLD ]
   then
      if [ $size -lt $FREE_SIZE_THRESHOLD ]
      then
         FAIL=1
         FAIL_TXT="$FAIL_TXT $fs $pct $size"
      fi
   fi

   sizemb=`perl -e "use POSIX qw(round);print round(( $size / 1000 ))"`
   if [ $FAIL -eq 1 ];then
         echo -e "\e[91m[ FAIL ]\e[39m $fs fs has ${sizemb}M(${pct}% used)"
   else  echo -e "\e[92m[ OK ]\e[39m $fs fs has ${sizemb}M(${pct}% used) "
   fi
   done
}


check_cmd_pattern() {
   # check_cmd_pattern v1.1 - popcornpopper
   command="$1"
   desc="$2"
   pattern1="$3"
   prefilter="$4"

   if [ -z "$prefilter" ] ; then
       $command  |grep -v grep | grep -v ^\# | grep -w "${pattern1}" > /dev/null 2>&1
   else
       $command  |grep -v grep | grep -v ^\# | grep -w "${prefilter}"  |grep -w "$pattern1" > /dev/null 2>&1
   fi
   ret=$?

   if [ $ret -eq 0 ]; then
      echo -e "\e[92m[ OK ]\e[39m $desc : Test successful for $pattern1 " ; return 0;
   else
      echo -e "\e[91m[ FAIL ]\e[39m $desc : Test failed for  $pattern1 "
      echo "     This test failed : $command | grep -w \"${pattern1}\"  "
      return 1
   fi
}

check_crons () {
 if [ "`whoami`" = "root" ] ; then
       CRONTAB_CMD="cat /var/spool/cron/crontabs/${SMARTCASH_HOME_DIR_OWNER}";
 else  CRONTAB_CMD="crontab -l"
 fi

 check_cmd_pattern "$CRONTAB_CMD" "Check cron script for auto start smartcashd after reboot is scheduled"  smartcashd reboot
 check_cmd_pattern "$CRONTAB_CMD" "Check cron script for auto upgrade script is scheduled" upgrade.sh
 check_cmd_pattern "$CRONTAB_CMD" "Check cron script to check/fix hung smartcashd is scheduled " checkdaemon.sh
 check_cmd_pattern "$CRONTAB_CMD" "Check cron script to clear debug log is scheduled"  clearlog.sh
 check_cmd_pattern "$CRONTAB_CMD" "Check cron script to auto restart smartcashd when down is scheduled"  makerun.sh
}


check_smartcashd_process () {
check_cmd_pattern "ps -ef" "Check if smartcashd daemon process is running" smartcashd
}


check_sc_status () {
 if [ "`whoami`" = "root" ] ; then
       echo "smartcash-cli smartnode status" > /tmp/sn.cmd.$$.txt ; chmod 755  /tmp/sn.cmd.$$.txt
       check_cmd_pattern  "sudo su ${SMARTCASH_HOME_DIR_OWNER} -c /tmp/sn.cmd.$$.txt" "Check smartcash-cli smartnode status" "Smartnode successfully started"
       rm -f  /tmp/sn.cmd.$$.txt
 else  check_cmd_pattern  "smartcash-cli smartnode status" "Check smartcash-cli smartnode status" "Smartnode successfully started"
 fi
}

check_sc_port () {
  check_cmd_pattern "$SUDO iptables -L" "Check if your network allows inbound traffic to SN port" "dpt:9678" "ACCEPT"
  check_cmd_pattern 'netstat -an' "Check if SN daemon port is listening" "9678" "LISTEN"
}

get_pub_ip() {
   # get_pub_ip v1.0 - popcornpopper
   /sbin/ifconfig |grep 'inet addr' |grep -v 127.0.0.1 | awk '{ print $2 }' |awk -F: '{ print $2 }' | tr -d '\012'
}

check_web_status() {
  # check_web_status v1.0 - popcornpopper
  pub_ip="`get_pub_ip`"
  wget -o  /tmp/wget.sn_webtest.$$.txt --timeout=1 --waitretry=0 --retry-connrefused --tries=2  ${pub_ip}:9678 > /dev/null 2>&1
  check_cmd_pattern "cat /tmp/wget.sn_webtest.$$.txt" "Check if SN daemon port is reachable from external internet" "connected"
  rm -f /tmp/wget.sn_webtest.$$.txt
}

check_system_stats() {
   # check_system_stats v1.2 - popcornpopper
   mtotal="`free -m |grep ^Mem | awk '{ print $2 }'|tr -d '\012'`"
   mavail="`free -m |grep ^Mem | awk '{ print $7 }'|tr -d '\012'`"
   mpct=`perl -e "use POSIX qw(round);print round(100*( $mavail / $mtotal ))"`

   if [ $mpct -lt $MEM_THRESHOLD ]; then
     echo -e "\e[92m[ OK ]\e[39m Mem usage ${mpct}% under threshold(${MEM_THRESHOLD}%)"
   else echo -e "\e[91m[ FAIL ]\e[39m Mem usage ${mpct}% above threshold(${MEM_THRESHOLD}%)"
   fi

   cpua=0
   for cpuv in `vmstat 1 5 | tail -5 | awk '{ print $15 }'`
   do
     cpua=`expr $cpua + $cpuv`
   done
     cpuavg=`perl -e "use POSIX qw(round);print 100-round(( $cpua / 5 ))"`

   if [ $cpuavg -lt $CPU_THRESHOLD ]; then
        echo -e "\e[92m[ OK ]\e[39m CPU usage ${cpuavg}% under threshold(${CPU_THRESHOLD}%)"
   else echo -e "\e[91m[ FAIL ]\e[39m CPU usage ${cpuavg}% above threshold(${CPU_THRESHOLD}%)"
   fi

}

smartcash_homedir () {
  smartcash_dir=`ls -1d /.smartcash /home/smartadmin/.smartcash  2> /dev/null`
  dirname $smartcash_dir | tr -d '\012'
}




download_official_script () {
  script_name="$1"
  rm -f ${TMPDIR}/${script_name} 2> /dev/null
  wget -O ${TMPDIR}/${script_name} https://raw.githubusercontent.com/SmartCash/smartnode/master/${script_name} > /dev/null 2>&1
}


get_cron_script_fname () {
  script_name="$1"

  if [ "`whoami`" = "root" ] ; then
        CRONTAB_CMD="cat /var/spool/cron/crontabs/${SMARTCASH_HOME_DIR_OWNER}";
  else  CRONTAB_CMD="crontab -l"
  fi

  ${CRONTAB_CMD} | grep -v "^\#" | grep -w "$script_name" | awk '{ print $6 }'
}

scriptit_and_run() {
   script_name="$1"

   cron_script="`get_cron_script_fname \"$script_name\"`"
   if [ ! -z "$cron_script" ]
   then
      echo "diff ${cron_script} ${TMPDIR}/${script_name} " > /tmp/scriptit.$$
      sh /tmp/scriptit.$$ >/dev/null 2>&1

      if [ $? -eq 0 ]; then
            echo -e "\e[92m[ OK ]\e[39m Cron script $script_name is identical with official script" ;
      else  echo -e "\e[95m[ WARNING ]\e[39m Cron script $script_name is different from the official script" ;
      fi
      rm -f /tmp/scriptit.$$
   else
      echo -e "\e[91m[ FAIL ]\e[39m Official $script_name is not scheduled in CRON"
   fi
}

check_cron_scripts_if_official () {
download_official_script clearlog.sh
download_official_script checkdaemon.sh
download_official_script makerun.sh
download_official_script upgrade.sh

scriptit_and_run clearlog.sh
scriptit_and_run makerun.sh
scriptit_and_run checkdaemon.sh
scriptit_and_run upgrade.sh
}

############## MAIN Routine #############
## TUNABLES
## System Thresholds
MEM_THRESHOLD=90
CPU_THRESHOLD=95

## Disk Space Thresholds
FREE_PCT_THRESHOLD=50
FREE_SIZE_THRESHOLD=12000000  # 12GB

###### Detect if this smartcashd was installed as root user or smartadmin
SMARTCASH_HOME_DIR="`smartcash_homedir`"
if [ -z "$SMARTCASH_HOME_DIR" ]; then echo "ERROR: Unable to locate Smartcash Application directory. "; exit 1; fi
SMARTCASH_HOME_DIR_OWNER="`ls -ld $SMARTCASH_HOME_DIR|head -1 | awk '{ print $3 }' | tr -d '\012'`"

TMPDIR=/tmp/smartcash_official_scripts
mkdir -p ${TMPDIR}

###### Checking if root user is running this program
if [ "`whoami`" != "root" ]; then
     SUDO="sudo"
else SUDO=""
fi

echo -e "
\e[30m\e[103m    SmartNode Health Check Analysis report v1.0   \e[49m\e[39m
----------------------------------------------"
if [ "`whoami`" = "smartadmin" ]; then echo "NOTE: smartadmin user detected , you maybe prompted for sudo password to run iptables command"; fi
echo

echo "
########## Performing Smartcashd Tests ##################
"
check_smartcashd_process
check_sc_status
#check_crons
check_cron_scripts_if_official

echo "
########## Performing System Tests ##################
"
check_system_stats
check_sc_port
check_web_status

echo "
########## Performing Disk Space Checks ##################"
echo "Thresholds : Must be < ${FREE_PCT_THRESHOLD}% used + free space >12GB
"
check_disk_space


echo -e "
Author :\e[44m popcornpopper \e[49m\e[39m "


echo "Report Date : `/bin/date`
Tea me up! (SMART) ScgbsLn4GSfvzEHWZhugTiyhFHejHAUcXD (ETH) 0x0c78d711b216082209a54f13065886311f94ce77
"
