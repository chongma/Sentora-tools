#!/bin/sh

# shell script to import zpanel to sentora

root="zEarJSXjhIn4VJbz"
postfix="ZSG1ZAYmxBERwfOX"
proftpd="DqkLCUKUaOvi1uz4"
roundcube="mY2bQxHiXvLsFTN0"

SETTINGS="/etc/sentora"
DATA="/var/sentora/"
BACKUP="./backup"
BACKUP_SETTINGS="$BACKUP/settings"
BACKUP_DATA="$BACKUP/data"
BACKUP_DATABASE="$BACKUP/database"
BACKUP_USERDB="$BACKUP/userdb"
ORIG="./orig"
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
function_drop_db_execute() {
        echo "Dropping database $1"
        mysql -u root -p$root -e "drop database $1;"
}
function_restore_db_execute() {
	echo "Restoring database $1"
	mysql -u root -p$root -e "create database $3;"
	unzip -p $2/$1_db.zip | mysql -u $4 -p$5 $3
}
function_backup_db_execute() {
        mysqldump --user=root --password=$root --host=localhost $1 > $2/$1_db.sql
        zip -r $2/$1_db.zip $2/$1_db.sql
        rm -f $2/$1_db.sql
}
function_restore_table_execute() {
	echo "Restoring table $3"
        unzip -p $2/$3_table.zip | mysql -u root -p$root $1
}
function_backup_table_execute() {
	mysqldump --user=root --password=$root --host=localhost $1 $3 > $2/$3_table.sql
	zip -r $2/$3_table.zip $2/$3_table.sql
        rm -f $2/$3_table.sql
}
function_convert_utf8() {
	echo "Converting $1 to utf8"
	sql="SELECT CONCAT('ALTER TABLE ',TABLE_SCHEMA,'.',TABLE_NAME,' CHARACTER SET utf8 COLLATE utf8_general_ci;',"
	sql="$sql 'ALTER TABLE ',TABLE_SCHEMA,'.',TABLE_NAME,' CONVERT TO CHARACTER SET utf8 COLLATE utf8_general_ci;')"
	sql="$sql AS alter_sql FROM information_schema.TABLES WHERE TABLE_SCHEMA = '$1';"
	echo $sql | mysql -u root -p$root -ss | mysql -u root -p$root
}
echo "ZPANEL IMPORT SCRIPT"
echo "####################"

# backup sentora original databases
function_directory_must_not_exist_create $ORIG "Original databases"

# preserve certain tables
function_backup_table_execute sentora_core $ORIG x_settings
function_backup_table_execute sentora_core $ORIG x_modules
function_backup_table_execute sentora_core $ORIG x_faqs
function_backup_table_execute sentora_core $ORIG x_translations

function_backup_db_execute sentora_core $ORIG
function_backup_db_execute sentora_postfix $ORIG
function_backup_db_execute sentora_proftpd $ORIG
function_backup_db_execute sentora_roundcube $ORIG

# drop the sentora database
function_drop_db_execute sentora_core
function_drop_db_execute sentora_postfix
function_drop_db_execute sentora_proftpd
function_drop_db_execute sentora_roundcube

# restore zpanel databases to sentora
function_restore_db_execute zpanel_core $BACKUP_DATABASE sentora_core root $root
function_restore_db_execute zpanel_postfix $BACKUP_DATABASE sentora_postfix postfix $postfix
function_restore_db_execute zpanel_proftpd $BACKUP_DATABASE sentora_proftpd proftpd $proftpd
function_restore_db_execute zpanel_roundcube $BACKUP_DATABASE sentora_roundcube roundcube $roundcube

# convert databases to utf8
function_convert_utf8 sentora_core
function_convert_utf8 sentora_postfix
function_convert_utf8 sentora_proftpd
function_convert_utf8 sentora_roundcube

# restore preserved tables
function_restore_table_execute sentora_core $ORIG x_settings
function_restore_table_execute sentora_core $ORIG x_modules
function_restore_table_execute sentora_core $ORIG x_faqs
function_restore_table_execute sentora_core $ORIG x_translations

# move away sentora settings
cp -rf /etc/sentora/configs/apache /etc/sentora/configs/apache-orig
cp -rf /etc/sentora/configs/bind/zones /etc/sentora/configs/bind/zones-orig

# copy zpanel settings to sentora
cp -rf $BACKUP_SETTINGS/apache/* /etc/sentora/configs/apache
cp -rf $BACKUP_SETTINGS/zones/* /etc/sentora/configs/bind/zones

# backup orig zadmin
mv /var/zpanel/hostdata/zadmin /var/zpanel/hostdata/zadmin-orig

# copy user settings
LIST_BACKUP_DATA_USER="$BACKUP_DATA/userList.txt"
if [ -f $LIST_BACKUP_DATA_USER ]; then
        while IFS='' read -r line || [[ -n "$line" ]]; do
		PWD=`pwd`
                USER_DATA="$PWD/backup/data/$line"
		echo "Symlinking user data"
		TARGET="/var/zpanel/hostdata/$line"
		ln -s $USER_DATA $TARGET
        done < $LIST_BACKUP_DATA_USER
fi

# restore zpanel user databases
LIST_BACKUP_DATABASE_USER="$BACKUP_DATABASE/userList.txt"
if [ -f $LIST_BACKUP_DATABASE_USER ]; then
        while IFS='' read -r line || [[ -n "$line" ]]; do
		USER_DATABASE="$BACKUP_DATABASE/$line"
		USER_DATABASE_LIST="$USER_DATABASE/dbList.txt"
		if [ -f $USER_DATABASE_LIST ]; then
		        while IFS='' read -r line2 || [[ -n "$line2" ]]; do
	               		function_restore_db_execute $line2 $USER_DATABASE $line2 root $root
			done < $USER_DATABASE_LIST
		fi
        done < $LIST_BACKUP_DATABASE_USER
fi

# restore user databases
if [ -f $LIST_USERDB ]; then
        while IFS='' read -r line || [[ -n "$line" ]]; do
#                function_restore_db_execute $line $BACKUP_USERDB $line root $root
		echo $line
        done < $LIST_USERDB
fi

# symlink to vmail
echo "Symlinking vmail"
mv /var/sentora/vmail /var/sentora/vmail-orig
ln -s ./vmail /var/sentora/vmail
