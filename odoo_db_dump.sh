# !/usr/bin/env bash

echo -n "ENTER ODOO-SERVER URL(exclude last \"/\"): " 
read server_url
echo -n "DATABASE NAME ON THE SERVER YOU WANT TO RESTORE: " 
read db_name
echo -n "ENTER MASTER PASSWORD OF YOUR ODOO-SERVER: " 
read master_pass
echo -n "ENTER NAME FOR NEW DATABASE TO RESTORE: " 
read db_name_new
echo -n "ENTER YOUR POSTGRES USERNAME: " 
read odoo_pg_usr

dt=$(date '+%Y-%m-%d_%H-%M-%S');
db_nm_zip="${db_name}_${dt}.dump"
sleep 1
echo "Starting database dump download..."
curl -X POST "$server_url/web/database/backup" -d "master_pwd=$master_pass&name=$db_name&backup_format=dump" -o $db_nm_zip
filepath="`readlink -f $db_nm_zip`"
echo $filepath
echo "Database dump downloaded..."
sleep 1

echo "Started database restoring... please wait until finish log."
sudo -i -u postgres bash << EOF
createdb $db_name_new
nohup pg_restore -c -d $db_name_new $filepath
EOF

echo "Executing SQL queries to change production parameters..."
sleep 1
psql -U $odoo_pg_usr -d $db_name_new -w -c "ALTER DATABASE \"$db_name_new\" OWNER TO $odoo_pg_usr;"
psql -U $odoo_pg_usr -d $db_name_new -w -c "DELETE FROM ir_mail_server;"
psql -U $odoo_pg_usr -d $db_name_new -w -c "UPDATE ir_cron SET active=false;"
psql -U $odoo_pg_usr -d $db_name_new -w -c "UPDATE res_partner SET email='test-email@zmail.com';"
exec_end_time=`date +%s`
runtime=$((exec_end_time-exec_start_time))
echo "Finished!"
echo "Script execution time was $runtime sec."
