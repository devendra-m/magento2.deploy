# magento2.deploy
This script is for deploying magento 2 from git and create new site keeping same magento 2 directory structure. Deploy structure is based on previous, current and next. When deployed it creates next site, current site is document root. When next site is published, current site is changed to previous site. When previous site is restored, current site is changed to next site.

1. Create directory deploy and download deploy.sh and deploy.conf to that directory.
2. Enter all configuration values in deploy.conf as per server configuration.
3. Create new database for next site or use same database name as current site if not required.
4. Next site and previous site directory will be created in deploy directory.
5. Source database password is current site database password.
6. Destination database password is new database password.
