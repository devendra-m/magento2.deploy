# magento2.deploy
This script is for deploying magento 2 from git.

1. Create directory deploy and download deploy.sh and deploy.conf to that directory.
2. Enter all configuration values in deploy.conf as per server configuration.
3. Create new database for new site or use same database name as current site if not required.
4. New site and backup directory will be created in deploy directory.
5. Source db password is current site db password.
6. Destination db password is new database password.
