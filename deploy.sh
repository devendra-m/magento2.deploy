#!/bin/bash
composer=$(which composer)
php=$(which php)

# directory path of deploy.sh file
deploy_dir=$(realpath $0 | xargs dirname)

hl_path='\033[0;33m'
hl_text='\033[0;34m'
hl_conf_text='\033[0;32m'
nc='\033[0m'

# function to check if configuration file exits
file(){
        filename=$deploy_dir/deploy.conf

        if [ ! -f $filename ];then
                echo "# document root path for magento 2
                        document_root='/var/www/html'
                        
                      # locales of site
                        locales='en_US en_GB'
        
                      # git branch and git repository
                        git_branch=''
                        git_repo=''
        
                      # database name and username of new deployed magento 2
                        db_name=''
                        db_username=''" | sed 's/^\s*//g' > $filename
        fi
}

confirmation(){
	echo -e "${hl_conf_text}Document root:${nc} ${hl_path}$(config "document_root")${nc}"
	echo -e "${hl_conf_text}Locales:${nc} ${hl_path}$(config "locales")${nc}"
	echo -e "${hl_conf_text}Git Branch:${nc} ${hl_path}$(config "git_branch")${nc}"
	echo -e "${hl_conf_text}Git Repository Link:${nc} ${hl_path}$(config "git_repo")${nc}"
	echo -e "${hl_conf_text}New database name:${nc} ${hl_path}$(config "db_name")${nc}"
	echo -e "${hl_conf_text}New database username:${nc} ${hl_path}$(config "db_username")${nc}"
	read -p "Enter [y] to confirm configuration and proceed: " input

	if [ ! "$input" = "y" ]; then
		exit
	fi
}

# function to get configuration values
config(){
	cat $deploy_dir/deploy.conf | grep "^[^#].*" | grep "$1" | sed "s/.*='\(.*\)'/\1/g"
}

# function to validate fields 
validate(){
	validation='1'
	IFS=$'\n'
	for field in $(echo $1 | sed 's/,/\n/g')
	do
		varname=$(echo $field | grep -o  ".*=>" | grep -o "\".*\"" | grep -o "[^\"]*")
		value=$(echo $field | grep -o  "=>.*" | grep -o "\".*\"" | grep -o "[^\"]*" | sed 's/^\s*\(.*\)\s*$/\1/g')
		if [ "$value" = "" ];then
   			echo "Please enter $varname value in deploy.conf"
			validation='0'
   		fi
 	done 	  	

	if [ $validation -eq "0" ]; then
		exit
	fi
}

# get node by index
node(){
	node=$(($2+1))
	echo $1 | sed 's/,/\n/g' | tail -n +$node | head -n 1 | grep -o "[^'\"]*"
}

# move node next to current and current to previous and previous to current and current to next 
move(){
	prevNode=$(node $list $(($current-1)))
	currNode=$(node $list $current)
	nextNode=$(node $list $(($current+1)))
	
	if [ $1 = 'n' ];then
		if [ -d $nextNode ] && [ ! -d $prevNode ];then
			mv $currNode $prevNode && mv $nextNode $currNode
			echo -e "Next site ${hl_path}$nextNode${nc} has been published to ${hl_path}$currNode${nc}"
		elif [ ! -d $nextNode ];then
			echo "Next site is not there"
		elif [ -d $prevNode ];then
			echo -e "Cannot move ${hl_path}$currNode${nc} to ${hl_path}$prevNode${nc} is already there"
		fi
	fi
	
	if [ $1 = 'p' ];then
		if [ -d $prevNode ] && [ ! -d $nextNode ];then
			mv $currNode $nextNode && mv $prevNode $currNode
			echo -e "Previous site ${hl_path}$prevNode${nc} has been restored to ${hl_path}$currNode${nc}"			
		elif [ ! -d $prevNode ];then
			echo "Previous site is not there"
		elif [ -d $nextNode ];then
			echo -e "Cannot move ${hl_path}$currNode${nc} to ${hl_path}$nextNode${nc} is already there"
		fi
	fi
}

# get database info from env.php
env(){ 
	cat $document_root/app/etc/env.php | grep ".*" | awk '{printf("%s ",$0)}' | grep -oP "'db'\s*=>(.(?!\]\s*\]\s*\]))*\s*.\s*.\s*." | grep -o  "'$1'\s*=>\s*'[^']*'\s*," | grep -o "'.*'" | grep -o "=>\s*'.*'" | grep -o "'.*'" | grep -o "[^']*"
}

# import current site db to next site db
newdb(){
	echo -e 'Import to new database '${hl_path}$dest_db${nc}
	echo -e 'Current site '${hl_path}$source_db${nc}' password'
	mysqldump --no-tablespaces --single-transaction -u $source_db_username -p $source_db > $document_root/var/$source_db.sql &&
	
	echo -e 'New site '${hl_path}$dest_db${nc}' password'
	mysql -u $dest_db_username -p $dest_db < $document_root/var/$source_db.sql

	if [ $? -eq 0 ]; then
		echo -e "Database has been transferred to ${hl_path}$dest_db${nc}"
	fi

	rm $document_root/var/$source_db.sql
}

# deploy next site
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
	
	read -p $(echo -e "Enter [y] to copy media from ${hl_path}$document_root/pub/media${nc} to ${hl_path}$site_next/pub/${nc}: ") input
	
	if [ "$input" = "y" ];then
		echo -e "${hl_text}Copying media files....${nc} "
		cp -R $document_root/pub/media  $site_next/pub/

		echo -e "${hl_text}Media has been copied${nc}"
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

# check if configuration file exists
file

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

# validate fields in configuration
fields='"document_root" => "'$document_root'","locales"=>"'$locales'","git_branch"=>"'$git_branch'","git_repo"=>"'$git_repo'","dest_db"=>"'$dest_db'","dest_db_username"=>"'$dest_db_username'"'
validate "$fields"

confirmation

site_next=$deploy_dir/'sites/next'
site_prev=$deploy_dir/'sites/prev'

# index of current site
current=1

list='"'$site_prev'","'$document_root'","'$site_next'"'

# get database name and username from current site
source_db=$(env "dbname")
source_db_username=$(env "username")

# database from current site will be imported to new site database
read -p $(echo -e "Enter [y] to transfer current database to new database ${hl_path}$dest_db${nc}: ") input

if [ "$input" = "y" ];then
	newdb
fi

# fetch from git and deploy in next site directory
read -p $( echo -e "Enter [y] to deploy ${hl_path}$site_next${nc}: ") input

if [ "$input" = "y" ];then
	deploy
fi

# publish next site to current site or restore from previous site
read -p $(echo -e  "Enter [y] to publish ${hl_path}$site_next${nc} to ${hl_path}$document_root${nc}: ") input

if [ "$input" = "y" ];then
	move "n"
fi

read -p $(echo -e  "Enter [y] to restore ${hl_path}$site_prev${nc} to ${hl_path}$document_root${nc}: ") input

if [ "$input" = "y" ];then
	move "p"
fi
