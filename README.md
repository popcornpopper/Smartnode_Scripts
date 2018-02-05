# Smartnode_Scripts
# Author: popcornpopper
#
#     This repository contains my custom made scripts for Smartcash's Smartnode mainly to simplify maintenance, automate tasks,
#   and just some fun stuffs.
#
#   smartnode_health_check.sh - 
#        Provides a robust end-to-end verification of a Smartnode. 
#        Performs the following checks:
#         1. check_smartcashd_process - Checks if your smartcashd daemon process is running
#         2. check_sc_status - Checks status of your smartcashd. Runs smartcash-cli smartnode status
#         3. check_crons - Checks all official cron scripts if you have them scheduled.
#         4. check_sc_port - Checks smartcashd daemon port to ensure its listening and its not blocked by internal/external firewalls. 
#         5. check_web_status - Checks smartcashd daemon port, verifies if its communicable from external internet.
#         6. check_system_stats - Checks your server's CPU and MEMORY stats and verify if its within reasonable thresholds
#         7. check_disk_space - Checks each filesystem is within space thresholds ( default : not less than 50% ; free space > 12GB )
