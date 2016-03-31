#!/bin/sh

# reverse import of zpanel data

root="zEarJSXjhIn4VJbz"
postfix="ZSG1ZAYmxBERwfOX"
proftpd="DqkLCUKUaOvi1uz4"
roundcube="mY2bQxHiXvLsFTN0"

BACKUP="./backup"
BACKUP_SETTINGS="$BACKUP/settings"
BACKUP_DATA="$BACKUP/data"
BACKUP_DATABASE="$BACKUP/database"
BACKUP_USERDB="$BACKUP/userdb"
ORIG="./orig"
LIST_USERDB="./dbList.txt"

function_drop_db_execute() {
	echo "Dropping database $1"
	mysql -u root -p$root -e "drop database $1;"
}
function_restore_db_execute() {
        echo "Restoring database $1"
        mysql -u $4 -p$5 -e "create database $3;"
        unzip -p $2/$1_db.zip | mysql -u $4 -p$5 $3
}

echo "ZPANEL UNDO SCRIPT"
echo "####################"

# drop zpanel databases
function_drop_db_execute sentora_core
function_drop_db_execute sentora_postfix
function_drop_db_execute sentora_proftpd
function_drop_db_execute sentora_roundcube

# restore original sentora databases
function_restore_db_execute sentora_core $ORIG sentora_core root $root
function_restore_db_execute sentora_postfix $ORIG sentora_postfix postfix $postfix
function_restore_db_execute sentora_proftpd $ORIG sentora_proftpd proftpd $proftpd
function_restore_db_execute sentora_roundcube $ORIG sentora_roundcube roundcube $roundcube

# restore original sentora settings
rm -rf /etc/sentora/configs/apache
mv /etc/sentora/configs/apache-orig /etc/sentora/configs/apache
rm -rf /etc/sentora/configs/bind/zones
mv /etc/sentora/configs/bind/zones-orig /etc/sentora/configs/bind/zones

# remove user data
LIST_BACKUP_DATA_USER="$BACKUP_DATA/userList.txt"
if [ -f $LIST_BACKUP_DATA_USER ]; then
        while IFS='' read -r line || [[ -n "$line" ]]; do
                USER_DATA="$BACKUP_DATA/$line"
	        echo "Removing symlinks to user $line"
                TARGET="/var/zpanel/hostdata/$line"
                unlink $TARGET                        
        done < $LIST_BACKUP_DATA_USER
fi

# restore orig zadmin
mv /var/zpanel/hostdata/zadmin-orig /var/zpanel/hostdata/zadmin

# drop zpanel user databases
LIST_BACKUP_DATABASE_USER="$BACKUP_DATABASE/userList.txt"
if [ -f $LIST_BACKUP_DATABASE_USER ]; then
        while IFS='' read -r line || [[ -n "$line" ]]; do
                USER_DATABASE="$BACKUP_DATABASE/$line"
                USER_DATABASE_LIST="$USER_DATABASE/dbList.txt"
                if [ -f $USER_DATABASE_LIST ]; then
                        while IFS='' read -r line2 || [[ -n "$line2" ]]; do
                                function_drop_db_execute $line2
                        done < $USER_DATABASE_LIST
                fi
        done < $LIST_BACKUP_DATABASE_USER
fi



# drop user databases
if [ -f $LIST_USERDB ]; then
        while IFS='' read -r line || [[ -n "$line" ]]; do
#                function_drop_db_execute $line
echo "$line"
        done < $LIST_USERDB
fi

# remove symlink
echo "Removing vmail symlink"
unlink /var/sentora/vmail
mv /var/sentora/vmail-orig /var/sentora/vmail

# remove orig directory
echo "Removing original backups"
rm -rf $ORIG
