# !/usr/bin/env bash
exec_start_time=`date +%s`
#ACCEPTING INPUTS HERE
echo -n "ENTER ODOO-SERVER URL(exclude last \"/\"): " 
read server_url
echo -n "DATABASE NAME ON THE SERVER YOU WANT TO RESTORE: " 
read db_name
echo -n "DOES SERVER HAS MASTER PASSWORD? [Y,n]"
read pass_flag
if [[ $pass_flag == "Y" || $pass_flag == "y" ]]; then
        echo -n "ENTER MASTER PASSWORD OF YOUR ODOO-SERVER: " 
		read master_pass
else
        master_pass='admin'
fi
echo -n "ENTER YOUR POSTGRES USERNAME: " 
read odoo_pg_usr
dt=$(date '+%Y-%m-%d_%H-%M-%S');
db_nm_zip="${db_name}_${dt}.dump"
db_name_new="${db_name}_${dt}"
sleep 2
#GRABBING DUMP FROM ODOO-SERVER
printf "\n++++++++++++++++++++\n\n"
echo "Starting database dump download..."
printf "\n"
curl -X POST "$server_url/web/database/backup" -d "master_pwd=$master_pass&name=$db_name&backup_format=dump" -o $db_nm_zip
filepath="`readlink -f $db_nm_zip`"
printf "\n++++++++++++++++++++\n\n"
echo "Database dump downloaded..."
sleep 2
printf "\n++++++++++++++++++++\n\n"
#ACTUAL DUMP REASTORATION AT LOCAL POSTGRES SERVER
echo "Started database restoring... please wait until finish log."
sudo -i -u postgres bash << EOF
createdb $db_name_new
nohup pg_restore -c -d $db_name_new $filepath
EOF
printf "\n++++++++++++++++++++\n\n"
echo "Executing SQL queries to change production parameters..."
sleep 2
#UTILITY SQLS TO CHANGE PRODUCTION DB PARAMETERS
#YOU CAN ADD MORE SQLS AS PER YOUR NEED HERE
psql -U $odoo_pg_usr -d $db_name_new -w -c "ALTER DATABASE \"$db_name_new\" OWNER TO $odoo_pg_usr;"
psql -U $odoo_pg_usr -d $db_name_new -w -c "UPDATE res_users SET password='a' WHERE id=2;"
psql -U $odoo_pg_usr -d $db_name_new -w -c "DELETE FROM ir_mail_server;"
psql -U $odoo_pg_usr -d $db_name_new -w -c "UPDATE ir_cron SET active=false;"
psql -U $odoo_pg_usr -d $db_name_new -w -c "UPDATE res_partner SET email='test-email@zmail.com';"
exec_end_time=`date +%s`
runtime=$((exec_end_time-exec_start_time))
printf "\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
echo   "                         Finished!                              "
echo   "           Script execution time was $runtime sec.              "
printf "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
