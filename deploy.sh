#!/bin/bash
composer=$(which composer)
php=$(which php)

# directory path of deploy.sh file
deploy_dir=$(realpath $0 | xargs dirname)

# function to get configuration values
config(){
	$(cat $deploy_dir/deploy.conf | grep "^[^#].*" | grep "$1" | sed "s/.*='\(.*\)'/\1/g")
}

# validate fields 
validate(){
	for arg in $@
	do
 		echo "$arg"
 	done 	
  	exit
}

# document_root of magento 2
document_root=$(config "document_root")

# locales of site
locales=$(config "locales")

# git branch name and repository link
git_branch=$(config "git_branch")
git_repo=$(config "git_repo")

# new site database name and username
dest_db=$(config "db_name")
dest_db_username=$(config "db_username")

validate $document_root $locales $git_branch $git_repo $dest_db $dest_db_username

site_next=$deploy_dir/'site_next'
site_prev=$deploy_dir/'site_prev'

# index of current site
current=1

list='"'$site_prev'","'$document_root'","'$site_next'"'

# get node by index
node(){
	node=$(($1+1))
	echo $list | sed 's/,/\n/g' | tail -n +$node | head -n 1 | grep -o "[^'\"]*"
}

# move node next to current and current to previous and previous to current and current to next 
move(){
	prevNode=$(node $(($current-1)))
	currNode=$(node $current)
	nextNode=$(node $(($current+1)))
	
	if [ $1 = 'n' ];then
		if [ -d $nextNode ] && [ ! -d $prevNode ];then
			mv $currNode $prevNode && mv $nextNode $currNode
		elif [ ! -d $nextNode ];then
			echo "Next site $nextNode is not there"
		elif [ -d $prevNode ];then
			echo "Cannot move $currNode to $prevNode is already there"
		fi
	fi
	
	if [ $1 = 'p' ];then
		if [ -d $prevNode ] && [ ! -d $nextNode ];then
			mv $currNode $nextNode && mv $prevNode $currNode
		elif [ ! -d $prevNode ];then
			echo "Previous site is not there"
		elif [ -d $prevNode ];then
			echo "Cannot move $currNode to $nextNode is already there"
		fi
	fi
}

# get database info from env.php
env(){ 
	cat $document_root/app/etc/env.php | grep ".*" | awk '{printf("%s ",$0)}' | grep -oP "'db'\s*=>(.(?!\]\s*\]\s*\]))*\s*.\s*.\s*." | grep -o  "'$1'\s*=>\s*'[^']*'\s*," | grep -o "'.*'" | grep -o "=>\s*'.*'" | grep -o "'.*'" | grep -o "[^']*"
}

# import current site db to next site db
newdb(){
	echo 'Import to new database '$dest_db
	echo 'Current site '$source_db' password '
	mysqldump --no-tablespaces --single-transaction -u $source_db_username -p $source_db > $document_root/var/$source_db.sql &&
	
	echo 'New db '$dest_db' password'
	mysql -u $dest_db_username -p $dest_db < $document_root/var/$source_db.sql
	
	rm $document_root/var/$source_db.sql
}

deploy(){
	if [ -d $site_next ];then
		rm -rf $site_next;
	fi
 
	mkdir $site_next && cd $site_next
	
	git init
	git remote add origin $git_repo
	git pull origin $git_branch
	git checkout $git_branch
	
	# copy env.php and config.php to next site
	cp $document_root/app/etc/env.php $document_root/app/etc/config.php $site_next/app/etc
	
	# change database name in next site env.php
	sed -i "s/'dbname'\s*=>\s*'.*'/'dbname' => '$dest_db'/g" $site_next/app/etc/env.php	
	
	read -p "Press y to copy media from $document_root/pub/media to $site_next/pub/:" input
	
	if [ "$input" = "y" ];then
		echo "Copy media files:"
		cp -R $document_root/pub/media  $site_next/pub/
	fi
	
	$composer update
	
	git reset --hard HEAD &&
	git pull origin $git_branch
	
	mage=$site_next'/bin/magento'
	
	$php -dmemory_limit=-1  $mage setup:upgrade &&
	$php -dmemory_limit=-1  $mage setup:di:compile &&
	$php -dmemory_limit=-1  $mage setup:static-content:deploy -f $locales &&
	$php -dmemory_limit=-1  $mage cache:flush
}

# get database name and username from current site
source_db=$(env "dbname")
source_db_username=$(env "username")

# database from current site will be imported to new site database
read -p "Press y to create new database $dest_db: " input

if [ "$input" = "y" ];then
	newdb
fi

# fetch from git and deploy in next site directory
read -p "Press y to deploy $site_next:" input

if [ "$input" = "y" ];then
	deploy
fi

# publish next site to current site or restore from previous site
read -p "Press n to move $site_next to $document_root and press p to move $site_prev to $document_root: " input

if [ "$input" = "n" ];then
	move "n"
fi
if [ "$input" = "p" ];then
	move "p"
fi
