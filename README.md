# magento2.deploy
This script is for deploying magento 2 from git and create new site keeping same magento 2 directory structure. Deploy structure previous, current and next. When deployed it creates next site, current site is document root. When next site is published, current site is changed to previous site. When previous site is restored, current site is changed to next site.

1. Create directory deploy and download deploy.sh and deploy.conf to that directory.
2. Enter all configuration values in deploy.conf as per server configuration.
3. Create new database for next site or use same database name as current site if not required.
4. Next site and previous site directory will be created in deploy/sites directory.
5. Current site database is transferred to new database.
6. Current site database password is database password from document root.
7. New site database password is new database password to be deployed.
