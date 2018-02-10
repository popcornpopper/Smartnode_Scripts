#!/bin/bash
#
#  Smartnode First Aid v1.0
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
#

clear

############ Make sure relative paths point to base OS bin dirs
PATH=/bin:/usr/bin:/sbin:$PATH
export PATH

############ Variable Declaration ###################
OK_FLAG=0 ; WARNING_FLAG=0 ; FAIL_FLAG=0

## TUNABLES - Change the values below per your liking
## System Thresholds
MEM_THRESHOLD=90              # 90%
CPU_THRESHOLD=95              # 95%

## Disk Space Thresholds
USED_PCT_THRESHOLD=50         # 50%
AVAIL_SIZE_THRESHOLD=12000000 # 12GB
DEBUG_LOG_SIZE_THRESHOLD=5000 # 5000M or 5GB


######   FUNCTIONS

convert_kb_to () {
KB_size="$1"
convert_to="$2"

if [ "$convert_to" = "GB" ]; then perl -e "use POSIX qw(round);print round(${KB_size}/1000/1000)"; fi
if [ "$convert_to" = "MB" ]; then perl -e "use POSIX qw(round);print round(${KB_size}/1000)"; fi
}

convert_mb_to () {
MB_size="$1"
convert_to="$2"

if [ "$convert_to" = "GB" ]; then perl -e "use POSIX qw(round);print round(${MB_size}/1000)"; fi
}

check_debug_log () {

dbglog_size="`ls -l ${SMARTCASH_HOME_DIR}/.smartcash/debug.log  |  awk '{ printf  "%3.0f\n",$5 / 1000000 }' | tr -d '\012'`"
if [ $dbglog_size -gt ${DEBUG_LOG_SIZE_THRESHOLD} ]; then
      echo -e "\e[91m[ FAIL ]\e[39m debug log too big (${dbglog_size}M) . "
      echo -e "\e[93m[ TIP  ]\e[39m Quick fix , run this command: /bin/date > ${SMARTCASH_HOME_DIR}/.smartcash/debug.log
      Long-term fix : Schedule official clearlog.sh script into CRON.
"
      FAIL_FLAG=`expr $FAIL_FLAG + 1`
else  echo -e "\e[92m[  OK  ]\e[39m debug log size (${dbglog_size}M) is less than threshold (${DEBUG_LOG_SIZE_THRESHOLD}M or `convert_mb_to ${DEBUG_LOG_SIZE_THRESHOLD} GB`GB)"
      OK_FLAG=`expr $OK_FLAG + 1`
fi

}


check_disk_space () {
   # check_disk_space v1.2 - popcornpopper
   IFS=\$
   for fspct in `df -k  |grep -v ^Filesystem | awk '{ print $5" "$4" "$6"\$" }' | sort -nr | tr -d '\012' `
   do

   FAIL=0
   pct=`echo -n $fspct | awk '{ print $1 }' | tr -d \% `
   avail_size=`echo -n $fspct | awk '{ print $2 }' |tr -d ' ' `
   fs=`echo -n $fspct | awk '{ print $3 }' `
   if [ $pct -gt $USED_PCT_THRESHOLD ]
   then
   ## Available space cannot go below AVAIL_SIZE_THRESHOLD
      if [ $avail_size -lt $AVAIL_SIZE_THRESHOLD ]
      then
         FAIL=1
         FAIL_TXT="$FAIL_TXT $fs $pct $size"
      fi
   fi

   sizemb=`convert_kb_to $avail_size MB`
   sizegb=`convert_kb_to $avail_size GB`
   if [ $sizemb -gt 1000 ] ;then sizedisp="${sizegb}G" ; fi
   if [ $sizemb -le 1000 ] ;then sizedisp="${sizemb}M" ; fi

   if [ $FAIL -eq 1 ];then
         echo -e "\e[91m[ FAIL ]\e[39m $fs fs has ${sizedisp}(${pct}% used)"
         FAIL_FLAG=`expr $FAIL_FLAG + 1`
   else  echo -e "\e[92m[  OK  ]\e[39m $fs fs has ${sizedisp}(${pct}% used) "
         OK_FLAG=`expr $OK_FLAG + 1`
   fi
   done
}


check_cmd_pattern() {
   # check_cmd_pattern v1.1 - popcornpopper
   command="$1"
   desc="$2"
   pattern1="$3"
   prefilter="$4"
   tip_line1="$5"
   tip_line2="$6"

   if [ -z "$prefilter" ] ; then
       $command  |grep -v grep | grep -v ^\# | grep -w "${pattern1}" > /dev/null 2>&1
   else
       $command  |grep -v grep | grep -v ^\# | grep -w "${prefilter}"  |grep -w "$pattern1" > /dev/null 2>&1
   fi
   ret=$?

   if [ $ret -eq 0 ]; then
      echo -e "\e[92m[  OK  ]\e[39m $desc : Test successful for $pattern1 " ;
      OK_FLAG=`expr $OK_FLAG + 1`
      return 0;
   else
      echo -e "\e[91m[ FAIL ]\e[39m $desc : Test failed for  $pattern1 "
      echo -e "\e[93m[ TIP  ]\e[39m $tip_line1
         $tip_line2"
      FAIL_FLAG=`expr $FAIL_FLAG + 1`
      return 1
   fi
}

check_crons () {
 if [ "`whoami`" = "root" ] ; then
       CRONTAB_CMD="cat /var/spool/cron/crontabs/${SMARTCASH_HOME_DIR_OWNER}";
 else  CRONTAB_CMD="crontab -l "
 fi

 check_cmd_pattern "$CRONTAB_CMD" "Check cron script for auto start smartcashd after reboot is scheduled"  smartcashd reboot "Add this line in CRON: @reboot /usr/bin/smartcashd." "Alternatively, see https://raw.githubusercontent.com/popcornpopper/Smartnode_Scripts/master/grab_and_install_smartnode_crons.sh "
  ## Disabling below checks, since cron checks are already done at the check_cron_scripts_if_official sub routine
  # check_cmd_pattern "$CRONTAB_CMD" "Check cron script for auto upgrade script is scheduled" upgrade.sh
  # check_cmd_pattern "$CRONTAB_CMD" "Check cron script to check/fix hung smartcashd is scheduled " checkdaemon.sh
  # check_cmd_pattern "$CRONTAB_CMD" "Check cron script to clear debug log is scheduled"  clearlog.sh
  # check_cmd_pattern "$CRONTAB_CMD" "Check cron script to auto restart smartcashd when down is scheduled"  makerun.sh
}


check_smartcashd_process () {
check_cmd_pattern "ps -ef" "Check if smartcashd daemon process is running" smartcashd
}


check_sc_status () {
 if [ "`whoami`" = "root" ] ; then
       echo "smartcash-cli smartnode status" > /tmp/sn.cmd.$$.txt ; chmod 755  /tmp/sn.cmd.$$.txt
       check_cmd_pattern  "sudo su ${SMARTCASH_HOME_DIR_OWNER} -c /tmp/sn.cmd.$$.txt" "Check smartcash-cli smartnode status" "Smartnode successfully started" "successfully" "Restart smartcashd by killing its pid and running 'smartcashd'. " "Alternatively, you may reboot your VPS, then run 'smartcashd'"
       rm -f  /tmp/sn.cmd.$$.txt
 else  check_cmd_pattern  "smartcash-cli smartnode status" "Check smartcash-cli smartnode status" "Smartnode successfully started" "successfully" "Restart smartcashd by killing its pid and running 'smartcashd'. " "Alternatively, you may reboot your VPS, then run 'smartcashd'"
 fi
}

check_sc_port () {
  check_cmd_pattern 'netstat -an' "Check if SN daemon port is listening" "9678" "LISTEN"
  ### disabling this check .. for advanced users.. if the check below fails .. means check_ddos.sh script was not run yet.
  #check_cmd_pattern "$SUDO iptables -L" "Check if your network allows inbound traffic to SN port" "dpt:9678" "ACCEPT"
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
        echo -e "\e[92m[  OK  ]\e[39m Mem usage ${mpct}% under threshold(${MEM_THRESHOLD}%)"
        OK_FLAG=`expr $OK_FLAG + 1`
   else echo -e "\e[91m[ FAIL ]\e[39m Mem usage ${mpct}% above threshold(${MEM_THRESHOLD}%)"
        echo -e "\e[93m[ TIP  ]\e[39m Kill some non-smartcashd processes. Reboot may help release un-needed processes.
"
   fi

   cpua=0
   for cpuv in `vmstat 1 5 | tail -5 | awk '{ print $15 }'`
   do
     cpua=`expr $cpua + $cpuv`
   done
     cpuavg=`perl -e "use POSIX qw(round);print 100-round(( $cpua / 5 ))"`

   if [ $cpuavg -lt $CPU_THRESHOLD ]; then
        echo -e "\e[92m[  OK  ]\e[39m CPU usage ${cpuavg}% under threshold(${CPU_THRESHOLD}%)"
        OK_FLAG=`expr $OK_FLAG + 1`
   else echo -e "\e[91m[ FAIL ]\e[39m CPU usage ${cpuavg}% above threshold(${CPU_THRESHOLD}%)"
        echo -e "\e[93m[ TIP  ]\e[39m Smartcashd daemon maybe synching , this can  be verified in the debug log.
         Perform Reboot of server if very high CPU condition persists, this helps release possibly hung processes.
"
   fi

}

smartcash_homedir () {
  smartcash_dir=`ls -1d /.smartcash /home/smartadmin/.smartcash ./smartcash 2> /dev/null`
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
  else  CRONTAB_CMD="crontab -l "
  fi

  ${CRONTAB_CMD} | grep -v "^\#" | grep -w "$script_name" | awk '{ print $6 }'
}

scriptit_and_run() {
   script_name="$1"

   cron_script="`get_cron_script_fname \"$script_name\" 2> /dev/null`"
   if [ ! -z "$cron_script" ]
   then
      echo "diff ${cron_script} ${TMPDIR}/${script_name} " > /tmp/scriptit.$$
      sh /tmp/scriptit.$$ >/dev/null 2>&1

      if [ $? -eq 0 ]; then
            echo -e "\e[92m[  OK  ]\e[39m Cron script $script_name is identical with official script and scheduled in CRON" ;
            OK_FLAG=`expr $OK_FLAG + 1`
      else  echo -e "\e[95m[ WARNING ]\e[39m Cron script $script_name is different from the official script. $script_name is scheduled in CRON" ;
            echo -e "\e[93m[ TIP  ]\e[39m Download and configure the latest official scripts.
          See https://raw.githubusercontent.com/popcornpopper/Smartnode_Scripts/master/grab_and_install_smartnode_crons.sh
";
            WARNING_FLAG=`expr $WARNING_FLAG + 1`
      fi
      rm -f /tmp/scriptit.$$
   else
      echo -e "\e[91m[ FAIL ]\e[39m Official $script_name is not scheduled in CRON."
            echo -e "\e[93m[ TIP  ]\e[39m Download and configure the latest official scripts.
          See https://raw.githubusercontent.com/popcornpopper/Smartnode_Scripts/master/grab_and_install_smartnode_crons.sh
";
      FAIL_FLAG=`expr $FAIL_FLAG + 1`
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
\e[30m\e[103m    SmartNode First Aid Analysis report v1.0   \e[49m\e[39m
----------------------------------------------
NOTE: This script is designed for Smartnodes that are fully configured and has achieved ENABLED status previously.
"

echo "
########## Performing Smartcashd Tests ##################
"
check_smartcashd_process
check_debug_log
check_sc_status
check_crons 2> /dev/null ## 2> /dev/null to suppress warnings when there's blank cron entries
check_cron_scripts_if_official

echo "
########## Performing System Tests ##################
"
check_system_stats
check_sc_port
check_web_status

DEBUG_LOG_SIZE_GB_THRESHOLD="`perl -e \"use POSIX qw(round);print round(${DEBUG_LOG_SIZE_THRESHOLD}/1000)\"`"
AVAIL_SIZE_GB_THRESHOLD="`perl -e \"use POSIX qw(round);print round(${AVAIL_SIZE_THRESHOLD}/1000/1000)\"`"
echo "
########## Performing Disk Space Checks ##################"
check_disk_space


echo -e "
########## RESULTS ##################

\e[92m OK      : ${OK_FLAG}\e[39m
\e[95m WARNING : ${WARNING_FLAG}\e[39m
\e[91m FAIL    : ${FAIL_FLAG}\e[39m

#### Thresholds # You may change these thresholds per your liking within the script.
Memory Utilization Threshold  : Must not go beyond ${MEM_THRESHOLD}%
CPU Utilization  Threshold    : Must not go beyond ${CPU_THRESHOLD}%

Disk Space % Used Threshold   : Must not go beyond ${USED_PCT_THRESHOLD}%
Disk Space Available Threshold: Must not go below ${AVAIL_SIZE_GB_THRESHOLD}G
Debug Log size Threshold      : Must not go beyond ${DEBUG_LOG_SIZE_GB_THRESHOLD}G

"


if [ $FAIL_FLAG -eq 0 ]
then
    echo -e "\e[92m Congratulations ! Your Smartnode has passed all tests.\e[39m"
fi

echo -e "
Author :\e[44m popcornpopper \e[49m\e[39m "


echo "Report Date : `/bin/date`
Tea me up! (SMART) ScgbsLn4GSfvzEHWZhugTiyhFHejHAUcXD (ETH) 0x0c78d711b216082209a54f13065886311f94ce77
"
