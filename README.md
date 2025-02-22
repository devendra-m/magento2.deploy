# magento2.deploy
This script is for deploying magento 2 from git.

1. New database needs to be created before running script.
2. Main directory is the directory of magento root. New build and backup dir will be created in this directory.
3. Source db password is current site db password.
4. Enter new database name in dest_db and new username in dest_db_username variables. Password will be asked to enter.
5. Enter git branch name in variable git_branch and repository name in git_repo.
6. It asks for confirmation to import into new database, deploy new build to current site and restore from backup.
