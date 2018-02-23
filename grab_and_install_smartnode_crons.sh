#!/bin/bash
#
# grab_and_install_smartnode_crons.sh
#
#    Download all official Smartcash Smartnode maintenance scripts, then schedule them into CRON scheduler.
#
# INSTRUCTIONS , run below commands:
#   1. rm -f grab_and_install_smartnode_crons.sh 2> /dev/null
#   2. wget https://raw.githubusercontent.com/popcornpopper/Smartnode_Scripts/master/grab_and_install_smartnode_crons.sh
#   3. bash grab_and_install_smartnode_crons.sh
#
# Author : popcornpopper
# Created: Feb 10, 2018
#

clear

SMARTCASH_CONF="`ls -1d ~/.smartcash/smartcash.conf 2> /dev/null`"
SMARTCASH_DIR="`dirname $SMARTCASH_CONF 2> /dev/null`"
SMARTCASH_BASE="`dirname $SMARTCASH_DIR 2> /dev/null`"

CURRENT_USER="`whoami`"
## Make sure Smartnode DIR exists
if [ ! -f ${SMARTCASH_BASE}/.smartcash/smartcash.conf ]
then
   echo
   echo "ERROR: Unable to locate Smartnode base directory . ${SMARTCASH_BASE}/.smartcash does not exist.
    - If you installed Smartnode using the Setup Guides with smartadmin , please login as smartadmin user.
    - If you installed Smartnode using bash installer, please login as root"
   exit 99
else
   echo
   echo "OK : detected ${SMARTCASH_DIR} as your smartcash top directory"
   echo "OK : detected ${SMARTCASH_BASE} as your smartcash base directory"
   echo
   echo "Using account $CURRENT_USER to cron-schedule the official Smartcash Smartnode Scripts"
   echo
fi

echo "
To proceed with downloading and scheduling Smartcash's official Smartnode scripts into CRON , then
give ${CURRENT_USER} sudo nopasswd (non-interactive) privilege ( smartcashd upgrade scripts requires root privs ).

please press ENTER key, to cancel press CTRL-C"
read go_no_go


## Add user to sudoers if not there yet. Using NOPASSWD , so sudo upgrade.sh will be non-interactive
if [ ! -f /etc/sudoers.prev ]; then sudo cp -p /etc/sudoers /etc/sudoers.prev ; fi
sudo grep -v ^${CURRENT_USER} /etc/sudoers > /tmp/tmp.sudoers
sudo echo "${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL" >> /tmp/tmp.sudoers
sudo cp /tmp/tmp.sudoers /etc/sudoers
sudo rm -f /tmp/tmp.sudoers

## If they exist, make backup of ${SMARTCASH_BASE}/smartnode and original cron scheds. User can revert back to these if needed.
if [ ! -d ${SMARTCASH_BASE}/smartnode_prev -a -d ${SMARTCASH_BASE}/smartnode ]; then cp -Rp ${SMARTCASH_BASE}/smartnode ${SMARTCASH_BASE}/smartnode_prev; fi
if [ ! -f /tmp/crontab.prev ]; then crontab -l > /tmp/crontab.prev ; fi

## Prepwork
mkdir -p ${SMARTCASH_BASE}/smartnode
rm -f ${SMARTCASH_BASE}/smartnode/makerun.sh
rm -f ${SMARTCASH_BASE}/smartnode/checkdaemon.sh
rm -f ${SMARTCASH_BASE}/smartnode/upgrade.sh
rm -f ${SMARTCASH_BASE}/smartnode/clearlog.sh

# Downloading the official smartnode maintenance scripts
wget -O ${SMARTCASH_BASE}/smartnode/makerun.sh https://raw.githubusercontent.com/SmartCash/smartnode/master/makerun.sh 2>/dev/null
wget -O ${SMARTCASH_BASE}/smartnode/checkdaemon.sh https://raw.githubusercontent.com/SmartCash/smartnode/master/checkdaemon.sh 2>/dev/null
wget -O ${SMARTCASH_BASE}/smartnode/upgrade.sh https://raw.githubusercontent.com/SmartCash/smartnode/master/upgrade.sh 2>/dev/null
wget -O ${SMARTCASH_BASE}/smartnode/clearlog.sh https://raw.githubusercontent.com/SmartCash/smartnode/master/clearlog.sh 2>/dev/null


## Giving the scripts locked down read, write and execute permissions
chmod 700 ${SMARTCASH_BASE}/smartnode/*.sh

SUDO=""
if [ "`whoami`" != "root" ]; then SUDO="/usr/bin/sudo" ;fi

## Below will create a temp file to store the smartnode cron scripts
echo "
@reboot /usr/bin/smartcashd > /tmp/start_at_reboot.out 2>&1

*/1 * * * * ${SMARTCASH_BASE}/smartnode/makerun.sh > /tmp/makerun.sh.out 2>&1
*/30 * * * * ${SMARTCASH_BASE}/smartnode/checkdaemon.sh > /tmp/checkdaemon.sh.out 2>&1
#* * */1 * * ${SUDO} ${SMARTCASH_BASE}/smartnode/upgrade.sh > /tmp/upgrade.sh.out 2>&1
0 8,20 * * * ${SMARTCASH_BASE}/smartnode/clearlog.sh > /tmp/clearlog.sh.out 2>&1

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
  3.  mv ${SMARTCASH_BASE}/smartnode_prev/*.sh  ${SMARTCASH_BASE}/smartnode 2> /dev/null
  4.  rmdir ${SMARTCASH_BASE}/smartnode_prev/
  5.  sudo mv /etc/sudoers.prev /etc/sudoers
"

echo "Below are your newly install CRON scripts:"
crontab -l
