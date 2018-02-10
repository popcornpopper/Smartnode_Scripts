#!/bin/bash
#
# setup_cron_scripts.sh
#
# Download all official Smartcash Smartnode maintenance scripts, then schedule them into CRON scheduler.
#
# By: popcornpopper

if [ $# -ne 1 ]
then
   echo "USAGE: sh setup_cron.sh [Smartnode Dir]"
   exit 1
fi

SMARTNODE_DIR="$1"

## Make sure Smartnode DIR exists
if [ ! -s ${SMARTNODE_DIR}/.smartcash/smartcash.conf ]
then
   echo "ERROR: Unable to determine smartcashd. Unable to locate ${SMARTNODE_DIR}/.smartcash/smartcash.conf  . "
   exit 99
fi

mkdir -p ${SMARTNODE_DIR}/smartnode
rm -f ${SMARTNODE_DIR}/smartnode/makerun.sh
rm -f ${SMARTNODE_DIR}/smartnode/checkdaemon.sh
rm -f ${SMARTNODE_DIR}/smartnode/upgrade.sh
rm -f ${SMARTNODE_DIR}/smartnode/clearlog.sh


## Make backup of original config and original cron scheds
if [ ! -d ${SMARTNODE_DIR}/smartnode_prev ]; then cp -Rp ${SMARTNODE_DIR}/smartnode ${SMARTNODE_DIR}/smartnode_prev; fi
if [ ! -f /tmp/crontab.prev ]; then crontab -l > /tmp/crontab.prev ; fi

# Download the appropriate scripts

wget -O ${SMARTNODE_DIR}/smartnode/makerun.sh https://raw.githubusercontent.com/SmartCash/smartnode/master/makerun.sh 2>/dev/null
wget -O ${SMARTNODE_DIR}/smartnode/checkdaemon.sh https://raw.githubusercontent.com/SmartCash/smartnode/master/checkdaemon.sh 2>/dev/null
wget -O ${SMARTNODE_DIR}/smartnode/upgrade.sh https://raw.githubusercontent.com/SmartCash/smartnode/master/upgrade.sh 2>/dev/null
wget -O ${SMARTNODE_DIR}/smartnode/clearlog.sh https://raw.githubusercontent.com/SmartCash/smartnode/master/clearlog.sh 2>/dev/null


chmod 700 ${SMARTNODE_DIR}/smartnode/*.sh
echo "
@reboot /usr/bin/smartcashd > /tmp/start_at_reboot.out 2>&1

*/1 * * * * ${SMARTNODE_DIR}/smartnode/makerun.sh > /tmp/makerun.sh.out 2>&1
*/30 * * * * ${SMARTNODE_DIR}/smartnode/checkdaemon.sh > /tmp/checkdaemon.sh.out 2>&1
*/120 * * * * ${SMARTNODE_DIR}/smartnode/upgrade.sh > /tmp/upgrade.sh.out 2>&1
0 8,20 * * * ${SMARTNODE_DIR}/smartnode/clearlog.sh > /tmp/clearlog.sh.out 2>&1

" > /tmp/smartnode.crontabs


crontab /tmp/smartnode.crontabs

rm -f /tmp/smartnode.crontabs

echo
echo "Smartcash Official scripts are now scheduled in CRON ."
echo "To see all available CRON scheduled jobs , run command : crontab -l "
echo
echo "If you want to revert back , run below commands in the following order :
  1.  crontab /tmp/crontab.prev
  2.  rm -f /tmp/crontab.prev
  3.  cp -p ${SMARTNODE_DIR}/smartnode_prev/*.sh  ${SMARTNODE_DIR}/smartnode
  4.  rmdir ${SMARTNODE_DIR}/smartnode_prev/
"

