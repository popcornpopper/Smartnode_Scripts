# Wrapper script
#
# Instructions:
# Run below command:
#    1. wget https://raw.githubusercontent.com/popcornpopper/Smartnode_Scripts/master/grab_and_run_smartnode_health_check.sh
#    2. sh grab_and_run_smartnode_health_check.sh

mkdir -p /tmp/smartnode_health_check
rm -f  /tmp/smartnode_health_check/smartnode_health_check.sh 2> /dev/null
wget -O /tmp/smartnode_health_check/smartnode_health_check.sh https://raw.githubusercontent.com/popcornpopper/Smartnode_Scripts/master/smartnode_health_check.sh
bash /tmp/smartnode_health_check/smartnode_health_check.sh | tee /tmp/smartnode_health_check/smartnode_health_check_report.txt

echo "Health Check Report : /tmp/smartnode_health_check/smartnode_health_check_report.txt"
echo
