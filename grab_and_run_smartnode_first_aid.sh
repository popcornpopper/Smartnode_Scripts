#!/bin/bash
# Wrapper script
#
# Instructions: Download this script only once. This will not change.
# Run below command:
#    1. wget https://raw.githubusercontent.com/popcornpopper/Smartnode_Scripts/master/grab_and_run_smartnode_first_aid.sh
#    2. bash grab_and_run_smartnode_first_aid.sh

mkdir -p /tmp/smartnode_first_aid
rm -f  /tmp/smartnode_first_aid/smartnode_first_aid.sh 2> /dev/null
wget -O /tmp/smartnode_first_aid/smartnode_first_aid.sh https://raw.githubusercontent.com/popcornpopper/Smartnode_Scripts/master/smartnode_first_aid.sh > /dev/null 2>&1
bash /tmp/smartnode_first_aid/smartnode_first_aid.sh | tee /tmp/smartnode_first_aid/smartnode_first_aid_report.txt

echo "Smartnode First Aid Report : /tmp/smartnode_first_aid/smartnode_first_aid_report.txt"
echo "To view the report , run the command : cat /tmp/smartnode_first_aid/smartnode_first_aid_report.txt"
