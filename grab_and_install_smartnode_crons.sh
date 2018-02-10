#!/bin/bash
#
# grab_and_install_smartnode_crons.sh
#
#    Download all official Smartcash Smartnode maintenance scripts, then schedule them into CRON scheduler.
#
# INSTRUCTIONS , run below commands:
#   1. wget https://raw.githubusercontent.com/popcornpopper/Smartnode_Scripts/master/grab_and_install_smartnode_crons.sh
#   2. sh get_and_install_smartnode_crons.sh [SmartNode Directory] .
#      - If you installed smartnode with smartadmin, your command will be : bash grab_and_install_smartnode_crons.sh "/home/smartadmin"
#      - If you installed using bash installer , your command will be : bash grab_and_install_smartnode_crons.sh "/"
#
# Author : popcornpopper
# Created: Feb 10, 2018
#

if [ $# -ne 1 ]
then
   echo "USAGE: sh setup_cron.sh [Smartnode Dir]"
   exit 1
fi

SMARTNODE_DIR="$1"

## Make sure Smartnode DIR exists
if [ ! -s ${SMARTNODE_DIR}/.smartcash/smartcash.conf ]
then
   echo "ERROR: Invalid Smartnode directory ${SMARTNODE_DIR}. "
   exit 99
fi

## If they exist, make backup of ${SMARTNODE_DIR}/smartnode and original cron scheds. User can revert back to these if needed.
if [ ! -d ${SMARTNODE_DIR}/smartnode_prev ]; then cp -Rp ${SMARTNODE_DIR}/smartnode ${SMARTNODE_DIR}/smartnode_prev; fi
if [ ! -f /tmp/crontab.prev ]; then crontab -l > /tmp/crontab.prev ; fi

## Prepwork
mkdir -p ${SMARTNODE_DIR}/smartnode
rm -f ${SMARTNODE_DIR}/smartnode/makerun.sh
rm -f ${SMARTNODE_DIR}/smartnode/checkdaemon.sh
rm -f ${SMARTNODE_DIR}/smartnode/upgrade.sh
rm -f ${SMARTNODE_DIR}/smartnode/clearlog.sh

# Downloading the official smartnode maintenance scripts 
wget -O ${SMARTNODE_DIR}/smartnode/makerun.sh https://raw.githubusercontent.com/SmartCash/smartnode/master/makerun.sh 2>/dev/null
wget -O ${SMARTNODE_DIR}/smartnode/checkdaemon.sh https://raw.githubusercontent.com/SmartCash/smartnode/master/checkdaemon.sh 2>/dev/null
wget -O ${SMARTNODE_DIR}/smartnode/upgrade.sh https://raw.githubusercontent.com/SmartCash/smartnode/master/upgrade.sh 2>/dev/null
wget -O ${SMARTNODE_DIR}/smartnode/clearlog.sh https://raw.githubusercontent.com/SmartCash/smartnode/master/clearlog.sh 2>/dev/null


## Giving the scripts locked down read, write and execute permissions
chmod 700 ${SMARTNODE_DIR}/smartnode/*.sh

## Below will create a temp file to store the smartnode cron scripts
echo "
@reboot /usr/bin/smartcashd > /tmp/start_at_reboot.out 2>&1

*/1 * * * * ${SMARTNODE_DIR}/smartnode/makerun.sh > /tmp/makerun.sh.out 2>&1
*/30 * * * * ${SMARTNODE_DIR}/smartnode/checkdaemon.sh > /tmp/checkdaemon.sh.out 2>&1
*/120 * * * * ${SMARTNODE_DIR}/smartnode/upgrade.sh > /tmp/upgrade.sh.out 2>&1
0 8,20 * * * ${SMARTNODE_DIR}/smartnode/clearlog.sh > /tmp/clearlog.sh.out 2>&1

" > /tmp/smartnode.crontabs

## Applying the smartnode cron scripts into CRON scheduler
crontab /tmp/smartnode.crontabs

## No longer need the temp file
rm -f /tmp/smartnode.crontabs

echo
echo "Smartcash Official scripts are now scheduled in CRON ."
echo "To see all available CRON scheduled jobs , run command : crontab -l "
echo
echo "If you want to revert back , run below commands in the following order :
  1.  crontab /tmp/crontab.prev
  2.  rm -f /tmp/crontab.prev
  3.  cp -p ${SMARTNODE_DIR}/smartnode_prev/*.sh  ${SMARTNODE_DIR}/smartnode 2> /dev/null
  4.  rmdir ${SMARTNODE_DIR}/smartnode_prev/
"

