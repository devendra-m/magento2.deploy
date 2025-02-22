# magento2.deploy
This script is for deploying magento 2 from git.

New database needs to be created before running script.
Main directory is the directory of magento root. New build and backup dir will be created in this directory.
Source db password is current site db password.
Enter new database name in dest_db and new username in dest_db_username variables. Password will be asked to enter.
Enter git branch name in variable git_branch and repository name in git_repo
It asks for confirmation to import into new database, deploy new build to current site and restore from backup.
