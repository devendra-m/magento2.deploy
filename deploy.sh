#!/bin/bash
composer=$(which composer)
php=$(which php)

deploy_dir=$(realpath .)

config(){
    cat $deploy_dir/deploy.conf | grep "^[^#].*" | grep "$1" | sed "s/.*='\(.*\)'/\1/g"
}

document_root=$(config "document_root")

locales=$(config "locales")

git_branch=$(config "git_branch")
git_repo=$(config "git_repo")

dest_db=$(config "dest_db")
dest_db_username=$(config "dest_db_username")

site_build_dir=$deploy_dir/'site_new'
site_backup_dir=$deploy_dir/'site_old'

# get database name and username from current site
source_db=$(cat $document_root/app/etc/env.php | grep -o  "'dbname'\s*=>\s*'.*'" | grep -o "=>\s*'.*'" | grep -o "'.*'" | grep -o "[^']*")
source_db_username=$(cat $document_root/app/etc/env.php | grep -o  "'username'\s*=>\s*'.*'" | grep -o "=>\s*'.*'" | grep -o "'.*'" | grep -o "[^']*")

# database from current site will be imported to new build database
read -p "Press y to create new database $dest_db: " input
if [ "$input" = "y" ];then
     echo 'Import to new database '$dest_db
     echo 'Current site '$source_db' password '
     mysqldump --no-tablespaces --single-transaction -u $source_db_username -p $source_db > $document_root/var/$source_db.sql &&
     
     echo 'New db '$dest_db' password'
     mysql -u $dest_db_username -p $dest_db < $document_root/var/$source_db.sql

     rm $document_root/var/$source_db.sql
fi

# fetch from git and deploy in new build directory
read -p "Press y to upgrade site:" input
if [ ! -d $site_build_dir ] && [ "$input" = "y" ];then
   mkdir $site_build_dir && cd $site_build_dir
   
   git init
   git remote add origin git@github:$git_repo
   git pull origin $git_branch
   git checkout $git_branch

   # copy env.php and config.php to new build
   cp $document_root/app/etc/env.php $document_root/app/etc/config.php $site_build_dir/app/etc

   # change database name in new build env.php
   sed -i "s/'dbname'\s*=>\s*'.*'/'dbname' => '$dest_db'/g" $site_build_dir/app/etc/env.php

   echo "Copy media files:"
   cp -R $document_root/pub/media  $site_build_dir/pub/

   $composer update

   mage=$site_build_dir'/bin/magento'
   
   $php -dmemory_limit=-1  $mage setup:upgrade &&
   $php -dmemory_limit=-1  $mage setup:di:compile &&
   $php -dmemory_limit=-1  $mage setup:static-content:deploy -f $locales &&
   $php -dmemory_limit=-1  $mage cache:flush
fi

# deploy new build to current site
read -p "Press y to deploy new build to current site: " input
if [ ! -d $site_backup_dir ] && [ -d  $site_build_dir ] && [ "$input" = "y" ];then
    mv $document_root $site_backup_dir && mv $site_build_dir $document_root
fi

# restore from backup to current site
read -p "Press y to restore backup to current site: " input
if [ -d $site_backup_dir ] && [ "$input" = "y" ];then
    mv $document_root $site_build_dir && mv $site_backup_dir $document_root
fi
