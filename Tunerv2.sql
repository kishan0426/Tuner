#!/bin/bash

trap 'rm -rf /home/oracle/oratab_new' EXIT
#For logging purpose
_LOG_0()
{
echo "*************************************$1"
}

#Set the environment variables
_SET_ENV_1()
{
cat /etc/oratab|grep -v '#'|grep -v '^$' > /home/oracle/oratab_new
while read x
   do
     IFS=':' read -r -a array <<< $x
                ORACLE_SID="${array[0]}"
                ORACLE_HOME="${array[1]}"
                echo $ORACLE_SID
                echo $ORACLE_HOME
                export PATH=$PATH:$ORACLE_HOME/bin
   done < /home/oracle/oratab_new
}
_VAR(){
        SQL_ID=frqcv71skm5rv
}

#View the existing auto partition created for last hour and append to a output file
_VIEW_PLAN_CHANGE_2()
{
$ORACLE_HOME/bin/sqlplus -S '/ as sysdba' << EOF >> log_for_reference
set heading off
set feedback off
def SQL_ID=$SQL_ID
spool PHV.txt
select to_char(dhsn.BEGIN_INTERVAL_TIME,'dd-mm-yy hh24:mi:ss') time,
       dhss.elapsed_time_total,
       dhss.plan_hash_value
       from dba_hist_sqlstat dhss
inner join dba_hist_snapshot dhsn on ( dhss.snap_id = dhsn.snap_id )
and dhss.sql_id='&SQL_ID'
order by dhss.elapsed_time_total desc;
--and BEGIN_INTERVAL_TIME >= sysdate - (1/24);
spool off
spool best_plan.txt
select plan_hash_value,min(elapsed_time_total) from dba_hist_sqlstat where sql_id='&SQL_ID' group by plan_hash_value;
spool off
exit;
EOF
_LOG_0
echo "PLAN DETAILS"
_LOG_0
cat PHV.txt
}

_TUNE_SQL_3(){
PHV=`cat PHV.txt |grep -vE 'old|new|^$'|awk '{print $4}'|uniq`
BEST_PHV=`cat best_plan.txt|awk '{print $1}'|grep -vE 'old|new|^$'`
for x in `cat PHV.txt |grep -vE 'old|new|^$'|awk '{print $NF}'|uniq|wc -l`;
    do
            if [ $x -gt 1 ]
            then
                   _TUNER_PROFILE_4
            elif [ $x -eq 1 ]
            then
                    echo "There is one plan hash value $PHV for sql_id: $SQL_ID, tune the sql manually";
            else
                    echo "Invalid request or error'd out"
            fi;
    done

}

_TUNER_PROFILE_4(){
$ORACLE_HOME/bin/sqlplus -S '/ as sysdba' << EOF >>log2_for_reference
def BP=$BEST_PHV
def SQL_ID=$SQL_ID
@coe_xfr_sql_profile.sql &SQL_ID &BP
@coe_xfr_sql_profile_${SQL_ID}_$BEST_PHV
exit
EOF
}


_VAR
_SET_ENV_1
_VIEW_PLAN_CHANGE_2
_TUNE_SQL_3
