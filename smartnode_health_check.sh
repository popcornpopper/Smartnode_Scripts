

PATH=/bin:/usr/bin:/sbin:$PATH
export PATH

check_disk_space () {

   
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
         echo "FAIL: $fs fs has ${sizemb}Megs(${pct}% used) , this has breached thresholds of (must be < ${FREE_PCT_THRESHOLD}% + >12GB)"
   else  echo "OK: $fs fs has ${sizemb}Megs(${pct}% used) , within thresholds (must be < ${FREE_PCT_THRESHOLD}% + >12GB)"
   fi
   done


}


check_cmd_pattern() {

   command="$1"
   desc="$2"
   pattern1="$3"
   prefilter="$4"

  # echo "$command $desc $exclude $pattern1 $prefilter"

   if [ -z "$prefilter" ] ; then
       $command  |grep -v grep | grep -v ^\# | grep -w "${pattern1}" > /dev/null 2>&1
   else 
       $command  |grep -v grep | grep -v ^\# | grep -w "${prefilter}"  |grep -w "$pattern1" > /dev/null 2>&1
   fi
   ret=$?

   if [ $ret -eq 0 ]; then 
      echo "OK: $desc : Test successful for $pattern1 " ; return 0;
   else 
      echo "FAIL: $desc : Test failed for  $pattern1 "
      echo "     This test failed : $command | grep -w \"${pattern1}\"  "
      return 1
   fi

}

check_crons () {

 check_cmd_pattern 'crontab -l' "Check cron script for auto start smartcashd after reboot is scheduled"  smartcashd reboot
 check_cmd_pattern 'crontab -l' "Check cron script for auto upgrade script is scheduled" upgrade.sh
 check_cmd_pattern 'crontab -l' "Check cron script to check/fix hung smartcashd is scheduled " checkdaemon.sh
 check_cmd_pattern 'crontab -l' "Check cron script to clear debug log is scheduled"  clearlog.sh
 check_cmd_pattern 'crontab -l' "Check cron script to auto restart smartcashd when down is scheduled"  makerun.sh
}


check_smartcashd_process () {
check_cmd_pattern "ps -ef" "Check if smartcashd daemon process is running" smartcashd
}


check_sc_status () {
  check_cmd_pattern  'smartcash-cli smartnode status' "Check smartcash-cli smartnode status" "Smartnode successfully started"
}
 
check_sc_port () {
  if [ "`whoami`" != root ]; then
        check_cmd_pattern 'sudo iptables -L' "Check if your network allows traffic to SN port" "dpt:9678" "ACCEPT"
  else check_cmd_pattern 'iptables -L' "Check if your network allows traffic to SN port" "dpt:9678" "ACCEPT";
  fi 
  check_cmd_pattern 'netstat -an' "Check if SN daemon port is listening" "9678" "LISTEN"
}

get_pub_ip() {
/sbin/ifconfig |grep 'inet addr' |grep -v 127.0.0.1 | awk '{ print $2 }' |awk -F: '{ print $2 }' | tr -d '\012'
}

check_web_status() {
  pub_ip="`get_pub_ip`"
  wget -o  /tmp/wget.sn_webtest.txt --timeout=1 --waitretry=0 --retry-connrefused --tries=2  ${pub_ip}:9678 > /dev/null 2>&1
  check_cmd_pattern "cat /tmp/wget.sn_webtest.txt" "Check if SN daemon port is reachable from external internet" "connected"
}

check_system_stats() {

mtotal="`free -m  |grep ^Mem| awk '{ print $2 }'|tr -d '\012'`"
mavail="`free -m |grep ^Mem | awk '{ print $7 }'|tr -d '\012'`"
mpct=`perl -e "use POSIX qw(round);print round(100*( $mavail / $mtotal ))"` 

if [ $mpct -lt $MEM_THRESHOLD ]; then
     echo "OK: Mem usage ${mpct}% under threshold(${MEM_THRESHOLD}%)" 
else echo "FAIL: Mem usage ${mpct}% above threshold(${MEM_THRESHOLD}%)" 
fi

cpua=0
for cpuv in `vmstat 1 5 | tail -5 | awk '{ print $15 }'`
do
  cpua=`expr $cpua + $cpuv`
done
  cpuavg=`perl -e "use POSIX qw(round);print 100-round(( $cpua / 5 ))"`

if [ $cpuavg -lt $CPU_THRESHOLD ]; then
     echo "OK: CPU usage ${cpuavg}% under threshold(${CPU_THRESHOLD}%)" 
else echo "FAIL: CPU usage ${cpuavg}% above threshold(${CPU_THRESHOLD}%)" 
fi
   
}

####### MAIN #############
## TUNABLES
## System Thresholds
MEM_THRESHOLD=90
CPU_THRESHOLD=95

## Disk Space Thresholds
FREE_PCT_THRESHOLD=50
FREE_SIZE_THRESHOLD=12000000  # 12GB


echo "
SmartNode Health Check Analysis report 
---------------------------------------------------------
"

########## Performing Smartcashd Tests ##################"
check_smartcashd_process
check_sc_status
check_crons

echo "
########## Performing System Tests ##################"
check_sc_port
check_web_status
check_system_stats
echo "
########## Performing Disk Space Checks ##################"
check_disk_space

echo "
Scripts by : popcornpopper ( bsmart )
Report Date: `/bin/date`
Tea me up! (SMART) ScgbsLn4GSfvzEHWZhugTiyhFHejHAUcXD (ETH) 0x0c78d711b216082209a54f13065886311f94ce77
"
