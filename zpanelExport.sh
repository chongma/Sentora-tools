#!/bin/sh

# copy settings data and databases (excluding virtual mailboxes)
# from a zpanel installation to a backup folder.  Zip the contents
# of the backup folder and then delete the backup folder

# paths
#mysqlpassword=$(cat /etc/zpanel/panel/cnf/db.php | grep "pass =" | sed -s "s|.*pass \= '\(.*\)';.*|\1|")
mysqlpassword="G4u7Z5i6r"
SETTINGS="/etc/zpanel"
DATA="/var/zpanel/"
BACKUP="./backup"
BACKUP_SETTINGS="$BACKUP/settings"
BACKUP_DATA="$BACKUP/data"
BACKUP_DATABASE="$BACKUP/database"
BACKUP_USERDB="$BACKUP/userdb"
LIST_USERDB="./dbList.txt"

function_directory_must_exist() {
	if [ -d "$1" ]; then
        	echo "$2 directory exists..."
	else
    		echo "Failed to find $2 directory...exiting"
        	exit
	fi
}
function_directory_must_not_exist_create() {
	if [ -d "$1" ]; then
                echo "$2 directory already exists...exiting"
		exit
        else
            	echo "$2 directory not found...creating"
		mkdir $1
		function_directory_must_exist $1 $2
        fi
}
function_copy_directory() {
	echo "COPYING $1 TO $2"
	cp -Rf $1 $2
}
function_backup_db_execute() {
        mysqldump --user=root --password=$mysqlpassword --host=localhost $1 --default-character-set=utf8  --skip-set-charset -r $2/$1_db.sql
	zip -r $2/$1_db.zip $2/$1_db.sql
        rm -f $2/$1_db.sql
}
# Function backup DB get list of DB then call DB dump
function_backup_db() {
        echo "user ID to backup : $1"
	touch "$3/dbList.txt"
        mysql zpanel_core -u root -p$mysqlpassword -e "SELECT my_name_vc FROM x_mysql_databases WHERE my_acc_fk='$1' AND my_deleted_ts IS NULL;;"| while read my_name_vc; do
        	if [ ! "$my_name_vc" == "my_name_vc" ]; then
                	echo "database to backup $my_name_vc"
			echo "$my_name_vc" >> $3/dbList.txt
                	function_backup_db_execute $my_name_vc $3
        	fi
	done
}
function_backup_users() {
        # Get all users from mySQL DB
        sql="SELECT ac_id_pk, ac_user_vc"
        sql="$sql FROM zpanel_core.x_accounts WHERE ac_deleted_ts IS NULL"
        sql="$sql and ac_enabled_in = 1;"

	touch "$BACKUP_DATA/userList.txt"
	touch "$BACKUP_DATABASE/userList.txt"
        echo $sql | mysql -u root -p$mysqlpassword -ss | while read ac_id_pk ac_user_vc; do
		USER_DIR="/var/zpanel/hostdata/$ac_user_vc"
        	USER_BACKUP="$BACKUP_DATA/$ac_user_vc"
		USER_DATABASE="$BACKUP_DATABASE/$ac_user_vc"
        	function_directory_must_not_exist_create $USER_BACKUP "$ac_user_vc personal data"
		function_directory_must_not_exist_create $USER_DATABASE "$ac_user_vc database"
		echo "$ac_user_vc" >> $BACKUP_DATA/userList.txt
		echo "$ac_user_vc" >> $BACKUP_DATABASE/userList.txt
		# copy directories except backups
        	for directory in `ls -Ibackups $USER_DIR`
        	do
          		function_copy_directory "$USER_DIR/$directory" $USER_BACKUP
        	done
		# - loop through users and also backup user databases
                function_backup_db $ac_id_pk $ac_user_vc $USER_DATABASE
        done
}

echo "ZPANEL EXPORT SCRIPT"
echo "####################"

# check for a zpanel installation
function_directory_must_exist $SETTINGS "Installation"

# create BACKUP directory
function_directory_must_not_exist_create $BACKUP "Backup"

# copy contents of CONFIGS to backup directory
function_directory_must_not_exist_create $BACKUP_SETTINGS "Backup settings"
function_copy_directory "/etc/zpanel/configs/apache" $BACKUP_SETTINGS
function_copy_directory "/etc/zpanel/configs/bind/zones" $BACKUP_SETTINGS

# copy user data and databases to backup directory
function_directory_must_not_exist_create $BACKUP_DATA "Backup data"
function_directory_must_not_exist_create $BACKUP_DATABASE "Backup database"
function_backup_users

# export zpanel databases
function_backup_db_execute zpanel_core $BACKUP_DATABASE
function_backup_db_execute zpanel_postfix $BACKUP_DATABASE
function_backup_db_execute zpanel_proftpd $BACKUP_DATABASE
function_backup_db_execute zpanel_roundcube $BACKUP_DATABASE

# - exclude contents of directories in vmail but preserve directories themselves

# extra databases
# read file containing a list of extra databases on host
if [ -f $LIST_USERDB ]; then
	function_directory_must_not_exist_create $BACKUP_USERDB "Backup user databases"
	while IFS='' read -r line || [[ -n "$line" ]]; do
		function_backup_db_execute $line $BACKUP_USERDB
	done < $LIST_USERDB
fi
