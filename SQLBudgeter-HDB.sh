#!/bin/bash
############################################################################################
# Tool Name: SQLBudgeter-HDB                                                               #
# Tool to check the expensive sql statements in a HDB and report it out via email          #
# Version - 01 (Designed for SAP Systems on HDB)                                           #
# Release Date - 03/18/2020                                                                #
# For support please contact Sudhanshu Shekhar                                             #
############################################################################################

#==================================================
# Current Tool version
#==================================================
tool_version="1.0"
tool_scope="(Designed for SAP Systems on HDB, Tested On - HDB on RHEL)"
#==================================================

#==================================================
# Source environment variables in the shell
echo "Sourcing environment variables for the execution of the tool $0 now." 
cd ~; . .bashrc;
#==================================================

#==================================================
# Set Global Variables for the tool & its functions
#==================================================
TOOL_NAME=$0
SAPSID=`echo $1 | tr "[a-z]" "[A-Z]"`
USERSTORE_KEY=`echo $2`
DAYS_TO_MONITOR="2"
NUMBER_INPUTS="$#"
LOGGER="/tmp/SQLBudgeter.log"
MAILER="sudhanshu.shekhar@company.com, YourMailingList@company.com"
SQLBudgeter_DIR=`pwd`
STARTTIME=`date +%s`
BEGIN_DATE=$(date -d "$date -${DAYS_TO_MONITOR} days" +"%Y/%m/%d")
END_DATE=$(date +"%Y/%m/%d")
echo " Begin Date for monitoring is ${BEGIN_DATE}"
export LD_LIBRARY_PATH="/usr/sap/`echo $1`/SYS/exe/hdb"
HDBSQL_EXE="${LD_LIBRARY_PATH}/hdbsql"

#==================================================

#==================================================
# Function: tool_help()
# Purpose: provide a detailed usage instruction to the user
tool_help()
{
    echo ""
    echo -e "\e[33mNAME:\e[0m SQLBudgeter-HDB - ${tool_version} \e[31m ${tool_scope} \e[0m"
    echo -e "\e[33mDESCRIPTION:\e[0m This tool is used for monitoring expensive SQLs of SAP systems running on a HANA DB."
    echo ""
    echo ""
    echo -e "\e[33mFeatures:\e[0m --->"
    echo -e "\e[33m01:\e[0m SQLBudgeter-HDB will be monitoring expensive SQLs of last ${DAYS_TO_MONITOR} days"
    echo -e "\e[33m02:\e[0m It will generate a report of the expensive SQLs and send it out to the following peopele - "
    echo -e "\e[33m02:\e[0m ${MAILER} "
    echo ""
    echo ""
    echo -e "\e[33mBelow is the right way to execute the SQLBudgeter-HDB tool:\e[0m --->"
    echo -e "\e[33m Please execute me as the sidadm user only."
    echo -e "\e[33m Adhoc execution --> ./SQLBudgeter-HDB.sh SID USERSTORE_KEY"  
    echo -e "\e[33m Cron execution --> "
    echo -e "\e[33m#-----------------------------------------------------------------------------------------------------------------------------------------#"
    echo -e "\e[33m#           ****Script to generate the report for the expensive SQL statements in HDB, Runs every Monday @ 02:00 AM Server Time****       #"
    echo -e "\e[33m#-----------------------------------------------------------------------------------------------------------------------------------------#"
    echo -e "\e[33m 00 02 * * 1 /home/sidadm/SQLBudgeter-HDB.sh SID USERSTORE_KEY > /dev/null 2>&1"
    echo -e "\e[33m#-----------------------------------------------------------------------------------------------------------------------------------------#" 
    echo ""
    echo ""
    echo -e "\e[34mAUTHOR:\e[0m Sudhanshu Shekhar"
    echo -e "\e[34mEMAIL:\e[0m sudhanshu.shekhar@company.com"
    echo ""
    exit 0
}
# END OF FUNCTION
#==================================================

#==================================================
# Function: tool_version()
# Purpose: Tool version page display
tool_version()
{
    clear
    echo ""
    echo -e "\e[33mCurrent Version:\e[0m ${tool_version} \e[31m ${tool_scope} \e[0m"
    echo ""
    echo -e "\e[33mChange History:\e[0m"
    echo "  March 16, 2020, version 0.0, Initial thought flow and development, basic version on scribe."
    echo "  March 17, 2020, version 0.1, Incremented with required logic & desired functions."
    echo "  March 18, 2020, Version 1.0, Released for general purpose."
    echo ""
    echo ""
    echo -e "\e[34mAUTHOR:\e[0m Sudhanshu Shekhar"
    echo -e "\e[34mEMAIL:\e[0m sudhanshu.shekhar@company.com"
    echo ""
    exit 0
}
# END OF FUNCTION
#==================================================

#==================================================
# Function: tool_info()
# Purpose: Tool information page display
tool_info()
{
    clear
    echo ""
    echo -e "\e[33mCurrent Version:\e[0m ${tool_version} \e[31m ${tool_scope} \e[0m"
    tool_help
    exit 0
}
# END OF FUNCTION
#==================================================

#==================================================
# Function: tool_input_check()
# Purpose: Tool input check
tool_input_check()
{
    clear
    echo ""
    echo "Performing input check @ `date` for ${TOOL_NAME}, Number of inputs passed is ${NUMBER_INPUTS}." > ${LOGGER}

# Check input values
if [ "${NUMBER_INPUTS}" == 2 ] ; then
  expensive_sql_reporter

else
  echo -e "\e[31m\e[5mError Detected::\e[0m Check the inputs/arguments provided to the tool & retry. Refer to the help below -"
  tool_help
fi
}
# END OF FUNCTION
#==================================================

#==================================================
# Function: expensive_sql_reporter()
# Purpose: Check the status of the Java server processes
expensive_sql_reporter()
{
clear
echo ""
  
#Set variables for finding out the java process status
sidadm="$(echo ${SAPSID} | tr '[A-Z]' '[a-z]')adm"

rm -f /tmp/SQLBudgeter*.
sql_in_check_tmp='/tmp/SQLBudgeter_sql_in_check_tmp.sql'
sql_out_check_tmp='/tmp/SQLBudgeter_sql_out_check_tmp.sql'

sql_in_ex_rep_tmp='/tmp/SQLBudgeter_sql_in_ex_rep_tmp.sql'
sql_out_ex_rep_tmp='/tmp/SQLBudgeter_ExpensiveSQLStatement_Report.txt'

# Find out if the tenant database is up & running
cat > ${sql_in_check_tmp} << EOF
select ACTIVE_STATUS from M_databases
EOF

${HDBSQL_EXE} -a -c \; -U ${USERSTORE_KEY} -I ${sql_in_check_tmp} -o ${sql_out_check_tmp}

hdb_status=`cat ${sql_out_check_tmp} | cut -c 2-4`
if  [[ ${hdb_status} == "YES" ]]
then 
    echo "Info:: Accessing hdbsql at ${HDBSQL_EXE}."  |& tee -a ${LOGGER}
    echo "Info:: Your HANA database ${SAPSID} is up & running." |& tee -a ${LOGGER}
    echo "Info:: ${TOOL_NAME} will proceed & generate the expensive SQLs for last ${DAYS_TO_MONITOR} days." |& tee -a ${LOGGER}

    # Generate the expensive SQL staements report
    cat > ${sql_in_ex_rep_tmp} << EOF
        SELECT
          START_TIME,
          HOST,
          LPAD(CONN_ID, 10) CONN_ID,
          STATEMENT_HASH,
          LPAD(EXECUTIONS, 10) EXECUTIONS,
          LPAD(TO_DECIMAL(ELAPSED_MS, 12, 2), 14) ELAPSED_MS,
          LPAD(TO_DECIMAL(CPU_MS, 12, 2), 10) CPU_MS,
          LPAD(TO_DECIMAL(ELA_PER_EXEC_MS, 12, 2), 15) ELA_PER_EXEC_MS,
          IFNULL(LPAD(TO_DECIMAL(SRV_PER_EXEC_MS, 12, 2) , 15), 'n/a') SRV_PER_EXEC_MS,
          LPAD(TO_DECIMAL(REC_PER_EXEC, 12, 2), 13) REC_PER_EXEC,
          LPAD(TO_DECIMAL(LOCK_PER_EXEC_MS, 12, 2), 16) LOCK_PER_EXEC_MS,
          LPAD(TO_DECIMAL(CPU_PER_EXEC_MS, 12, 2), 15) CPU_PER_EXEC_MS,
          LPAD(TO_DECIMAL(MEM_USED_GB, 10, 2), 11) MEM_USED_GB,
          LPAD(TO_DECIMAL(MEM_PER_EXEC_GB, 10, 2), 15) MEM_PER_EXEC_GB,
          OPERATION,
          APP_SOURCE,
          APP_USER,
          DB_USER,
          ERROR,
          LPAD(TO_DECIMAL(SQL_TEXT_LENGTH, 10, 0), 7) SQL_LEN,
          SQL_TEXT,
          BIND_VALUES,
          IFNULL(LOCATION_STATISTICS, '') LOCATION_STATISTICS
        FROM
        ( SELECT
            HOST,
            CONN_ID,
            STATEMENT_HASH,
            EXECUTIONS,
            ELAPSED_MS,
            CPU_MS,
            ELA_PER_EXEC_MS,
            SRV_PER_EXEC_MS,
            LOCK_PER_EXEC_MS,
            CPU_PER_EXEC_MS,
            REC_PER_EXEC,
            MEM_USED_GB,
            MEM_PER_EXEC_GB,
            START_TIME,
            OPERATION,
            APP_SOURCE,
            APP_USER,
            DB_USER,
            ERROR,
            SUBSTR(CASE
              WHEN LOCATE(UPPER(SQL_TEXT), 'FROM') <= 15 THEN
                SQL_TEXT
              ELSE
                SUBSTR(SQL_TEXT, 1, LOCATE(SQL_TEXT, CHAR(32))) || '...' || SUBSTR(SQL_TEXT, LOCATE(UPPER(SQL_TEXT), 'FROM') - 1)
            END, 1, MAP(SQL_TEXT_OUTPUT_LENGTH, -1, 9999, SQL_TEXT_OUTPUT_LENGTH)) SQL_TEXT,
            SQL_TEXT_LENGTH,
            BIND_VALUES,
            LOCATION_STATISTICS,
            RESULT_ROWS,
            ROW_NUMBER () OVER (ORDER BY
              MAP(ORDER_BY, 'TIME', START_TIME) DESC, 
              MAP(ORDER_BY, 'DURATION', ELAPSED_MS, 'MEMORY', MEM_USED_GB, 'CPU', CPU_MS, 'EXECUTIONS', EXECUTIONS, 'LENGTH', SQL_TEXT_LENGTH) DESC
            ) ROW_NUM
          FROM
          ( SELECT
              CASE 
                WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'TIME') != 0 THEN 
                  CASE 
                    WHEN BI.TIME_AGGREGATE_BY LIKE 'TS%' THEN
                      TO_VARCHAR(ADD_SECONDS(TO_TIMESTAMP('2014/01/01 00:00:00', 'YYYY/MM/DD HH24:MI:SS'), FLOOR(SECONDS_BETWEEN(TO_TIMESTAMP('2014/01/01 00:00:00', 
                      'YYYY/MM/DD HH24:MI:SS'), CASE BI.TIMEZONE WHEN 'UTC' THEN ADD_SECONDS(ES.START_TIME, SECONDS_BETWEEN(CURRENT_TIMESTAMP, CURRENT_UTCTIMESTAMP)) ELSE ES.START_TIME END) / SUBSTR(BI.TIME_AGGREGATE_BY, 3)) * SUBSTR(BI.TIME_AGGREGATE_BY, 3)), 'YYYY/MM/DD HH24:MI:SS')
                    ELSE TO_VARCHAR(CASE BI.TIMEZONE WHEN 'UTC' THEN ADD_SECONDS(ES.START_TIME, SECONDS_BETWEEN(CURRENT_TIMESTAMP, CURRENT_UTCTIMESTAMP)) ELSE ES.START_TIME END, BI.TIME_AGGREGATE_BY)
                  END
                ELSE 'any' 
              END START_TIME,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'HOST')      != 0 THEN ES.HOST                                             ELSE MAP(BI.HOST, '%', 'any', BI.HOST)                     END HOST,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'HASH')      != 0 THEN ES.STATEMENT_HASH                                   ELSE MAP(BI.STATEMENT_HASH, '%', 'any', BI.STATEMENT_HASH) END STATEMENT_HASH,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'CONN_ID')   != 0 THEN TO_VARCHAR(ES.CONNECTION_ID)                        ELSE MAP(BI.CONN_ID, -1, 'any', TO_VARCHAR(BI.CONN_ID))    END CONN_ID,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'OPERATION') != 0 THEN ES.OPERATION                                        ELSE MAP(BI.OPERATIONS, '%', 'any', BI.OPERATIONS)         END OPERATION,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'APP_USER')  != 0 THEN ES.APP_USER                                         ELSE MAP(BI.APP_USER, '%', 'any', BI.APP_USER)             END APP_USER,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'DB_USER')   != 0 THEN ES.DB_USER                                          ELSE MAP(BI.DB_USER, '%', 'any', BI.DB_USER)               END DB_USER,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'SOURCE')    != 0 THEN ES.APPLICATION_SOURCE                               ELSE MAP(BI.APP_SOURCE, '%', 'any', BI.APP_SOURCE)         END APP_SOURCE,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'ERROR')     != 0 THEN ES.ERROR_CODE || MAP(ES.ERROR_TEXT, '', '', ' (' || ES.ERROR_TEXT || ')') ELSE 'any'                           END ERROR,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'BINDS')     != 0 THEN ES.PARAMETERS                                       ELSE 'any'                                                 END BIND_VALUES,
              COUNT(*) EXECUTIONS,
              SUM(ES.DURATION_MICROSEC) / 1000 ELAPSED_MS,
              SUM(CASE WHEN ES.CPU_TIME / 1024 / 1024 / 1024 BETWEEN 0 AND 1000000 THEN ES.CPU_TIME ELSE 0 END) / 1000 CPU_MS,
              SUM(ES.DURATION_MICROSEC) / COUNT(*) / 1000 ELA_PER_EXEC_MS,
              SUM(N.SERVER_DURATION) / COUNT(*) / 1000 SRV_PER_EXEC_MS,
              SUM(ES.LOCK_WAIT_DURATION) / COUNT(*) / 1000 LOCK_PER_EXEC_MS,
              SUM(CASE WHEN ES.CPU_TIME / 1024 / 1024 / 1024 BETWEEN 0 AND 1000000 THEN ES.CPU_TIME ELSE 0 END) / COUNT(*) / 1000 CPU_PER_EXEC_MS,
              SUM(GREATEST(CASE WHEN ES.RECORDS BETWEEN 0 AND 100000000000 THEN ES.RECORDS ELSE 0 END, 0)) / COUNT(*) REC_PER_EXEC,
              SUM(CASE WHEN ES.MEMORY_SIZE / 1024 / 1024 / 1024 >= 1000000 THEN 0 ELSE ES.MEMORY_SIZE / 1024 / 1024 / 1024 END) MEM_USED_GB,
              SUM(CASE WHEN ES.MEMORY_SIZE / 1024 / 1024 / 1024 >= 1000000 THEN 0 ELSE ES.MEMORY_SIZE / 1024 / 1024 / 1024 END) / COUNT(*) MEM_PER_EXEC_GB,
              LTRIM(MAP(MIN(TO_VARCHAR(SUBSTR(ES.STATEMENT_STRING, 1, 5000))), MAX(TO_VARCHAR(SUBSTR(ES.STATEMENT_STRING, 1, 5000))), MIN(TO_VARCHAR(SUBSTR(ES.STATEMENT_STRING, 1, 5000))), 'various')) SQL_TEXT,
              AVG(LENGTH(ES.STATEMENT_STRING)) SQL_TEXT_LENGTH,
              MAP(MIN(ESL.LOCATION_STATISTICS), MAX(ESL.LOCATION_STATISTICS), MIN(ESL.LOCATION_STATISTICS), 'various') LOCATION_STATISTICS,
              BI.ORDER_BY,
              BI.RESULT_ROWS,
              BI.SQL_TEXT_OUTPUT_LENGTH,
              BI.MIN_SQL_TEXT_LENGTH
            FROM
            ( SELECT
                CASE
                  WHEN BEGIN_TIME =    'C'                             THEN CURRENT_TIMESTAMP
                  WHEN BEGIN_TIME LIKE 'C-S%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(BEGIN_TIME, 'C-S'))
                  WHEN BEGIN_TIME LIKE 'C-M%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(BEGIN_TIME, 'C-M') * 60)
                  WHEN BEGIN_TIME LIKE 'C-H%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(BEGIN_TIME, 'C-H') * 3600)
                  WHEN BEGIN_TIME LIKE 'C-D%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(BEGIN_TIME, 'C-D') * 86400)
                  WHEN BEGIN_TIME LIKE 'C-W%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(BEGIN_TIME, 'C-W') * 86400 * 7)
                  WHEN BEGIN_TIME LIKE 'E-S%'                          THEN ADD_SECONDS(TO_TIMESTAMP(END_TIME, 'YYYY/MM/DD HH24:MI:SS'), -SUBSTR_AFTER(BEGIN_TIME, 'E-S'))
                  WHEN BEGIN_TIME LIKE 'E-M%'                          THEN ADD_SECONDS(TO_TIMESTAMP(END_TIME, 'YYYY/MM/DD HH24:MI:SS'), -SUBSTR_AFTER(BEGIN_TIME, 'E-M') * 60)
                  WHEN BEGIN_TIME LIKE 'E-H%'                          THEN ADD_SECONDS(TO_TIMESTAMP(END_TIME, 'YYYY/MM/DD HH24:MI:SS'), -SUBSTR_AFTER(BEGIN_TIME, 'E-H') * 3600)
                  WHEN BEGIN_TIME LIKE 'E-D%'                          THEN ADD_SECONDS(TO_TIMESTAMP(END_TIME, 'YYYY/MM/DD HH24:MI:SS'), -SUBSTR_AFTER(BEGIN_TIME, 'E-D') * 86400)
                  WHEN BEGIN_TIME LIKE 'E-W%'                          THEN ADD_SECONDS(TO_TIMESTAMP(END_TIME, 'YYYY/MM/DD HH24:MI:SS'), -SUBSTR_AFTER(BEGIN_TIME, 'E-W') * 86400 * 7)
                  WHEN BEGIN_TIME =    'MIN'                           THEN TO_TIMESTAMP('1000/01/01 00:00:00', 'YYYY/MM/DD HH24:MI:SS')
                  WHEN SUBSTR(BEGIN_TIME, 1, 1) NOT IN ('C', 'E', 'M') THEN TO_TIMESTAMP(BEGIN_TIME, 'YYYY/MM/DD HH24:MI:SS')
                END BEGIN_TIME,
                CASE
                  WHEN END_TIME =    'C'                             THEN CURRENT_TIMESTAMP
                  WHEN END_TIME LIKE 'C-S%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(END_TIME, 'C-S'))
                  WHEN END_TIME LIKE 'C-M%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(END_TIME, 'C-M') * 60)
                  WHEN END_TIME LIKE 'C-H%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(END_TIME, 'C-H') * 3600)
                  WHEN END_TIME LIKE 'C-D%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(END_TIME, 'C-D') * 86400)
                  WHEN END_TIME LIKE 'C-W%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(END_TIME, 'C-W') * 86400 * 7)
                  WHEN END_TIME LIKE 'B+S%'                          THEN ADD_SECONDS(TO_TIMESTAMP(BEGIN_TIME, 'YYYY/MM/DD HH24:MI:SS'), SUBSTR_AFTER(END_TIME, 'B+S'))
                  WHEN END_TIME LIKE 'B+M%'                          THEN ADD_SECONDS(TO_TIMESTAMP(BEGIN_TIME, 'YYYY/MM/DD HH24:MI:SS'), SUBSTR_AFTER(END_TIME, 'B+M') * 60)
                  WHEN END_TIME LIKE 'B+H%'                          THEN ADD_SECONDS(TO_TIMESTAMP(BEGIN_TIME, 'YYYY/MM/DD HH24:MI:SS'), SUBSTR_AFTER(END_TIME, 'B+H') * 3600)
                  WHEN END_TIME LIKE 'B+D%'                          THEN ADD_SECONDS(TO_TIMESTAMP(BEGIN_TIME, 'YYYY/MM/DD HH24:MI:SS'), SUBSTR_AFTER(END_TIME, 'B+D') * 86400)
                  WHEN END_TIME LIKE 'B+W%'                          THEN ADD_SECONDS(TO_TIMESTAMP(BEGIN_TIME, 'YYYY/MM/DD HH24:MI:SS'), SUBSTR_AFTER(END_TIME, 'B+W') * 86400 * 7)
                  WHEN END_TIME =    'MAX'                           THEN TO_TIMESTAMP('9999/12/31 00:00:00', 'YYYY/MM/DD HH24:MI:SS')
                  WHEN SUBSTR(END_TIME, 1, 1) NOT IN ('C', 'B', 'M') THEN TO_TIMESTAMP(END_TIME, 'YYYY/MM/DD HH24:MI:SS')
                END END_TIME,
                TIMEZONE,
                HOST,
                CONN_ID,
                STATEMENT_HASH,
                APP_USER,
                DB_USER,
                SQL_PATTERN,
                APP_SOURCE,
                ERROR_CODE,
                ERROR_TEXT,
                ONLY_ERRORS,
                SQL_TEXT_OUTPUT_LENGTH,
                MIN_MEM_GB,
                MAX_MEM_GB,
                MIN_DURATION_S,
                MIN_SQL_TEXT_LENGTH,
                OPERATIONS,
                AGGREGATE_BY,
                ORDER_BY,
                RESULT_ROWS,
                MAP(TIME_AGGREGATE_BY,
                  'NONE',        'YYYY/MM/DD HH24:MI:SS',
                  'HOUR',        'YYYY/MM/DD HH24',
                  'DAY',         'YYYY/MM/DD (DY)',
                  'HOUR_OF_DAY', 'HH24',
                  TIME_AGGREGATE_BY ) TIME_AGGREGATE_BY
              FROM
              ( SELECT                                       /* Modification section */
                  '${BEGIN_DATE} 00:00:00' BEGIN_TIME,                  /* YYYY/MM/DD HH24:MI:SS timestamp, C, C-S<seconds>, C-M<minutes>, C-H<hours>, C-D<days>, C-W<weeks>, E-S<seconds>, E-M<minutes>, E-H<hours>, E-D<days>, E-W<weeks>, MIN */
                  '${END_DATE} 00:00:00' END_TIME,                    /* YYYY/MM/DD HH24:MI:SS timestamp, C, C-S<seconds>, C-M<minutes>, C-H<hours>, C-D<days>, C-W<weeks>, B+S<seconds>, B+M<minutes>, B+H<hours>, B+D<days>, B+W<weeks>, MAX */
                  'SERVER' TIMEZONE,                              /* SERVER, UTC */
                  '%' HOST,
                  -1 CONN_ID,
                  '%' STATEMENT_HASH,
                  '%' APP_USER,
                  '%' DB_USER,
                  '%' SQL_PATTERN,
                  '%' APP_SOURCE,
                  -1 ERROR_CODE,
                  '%' ERROR_TEXT,
                  ' ' ONLY_ERRORS,
                  40  SQL_TEXT_OUTPUT_LENGTH,
                  -1 MIN_MEM_GB,
                  -1 MAX_MEM_GB,
                  -1 MIN_DURATION_S,
                  -1 MIN_SQL_TEXT_LENGTH,
                  'TOTAL' OPERATIONS,     /* TOTAL for total values per statement (AGGREGATED_EXECUTION + CALL + EXECUTE + EXECUTE_DDL + INSERT + UPDATE + DELETE), various individual steps like SELECT or COMPILE */
                  'NONE' AGGREGATE_BY,                         /* TIME, HOST, CONN_ID, HASH, APP_USER, DB_USER, OPERATION, SOURCE, ERROR, BINDS or comma separated combinations, NONE for no aggregation */
                  'NONE' TIME_AGGREGATE_BY,                    /* HOUR, DAY, HOUR_OF_DAY or database time pattern, TS<seconds> for time slice, NONE for no aggregation */
                  'LENGTH' ORDER_BY,                             /* TIME, DURATION, MEMORY, CPU, EXECUTIONS, LENGTH */
                  -1 RESULT_ROWS
                FROM
                  DUMMY
              )
            ) BI INNER JOIN
              M_EXPENSIVE_STATEMENTS ES ON
                CASE BI.TIMEZONE WHEN 'UTC' THEN ADD_SECONDS(ES.START_TIME, SECONDS_BETWEEN(CURRENT_TIMESTAMP, CURRENT_UTCTIMESTAMP)) ELSE ES.START_TIME END BETWEEN BI.BEGIN_TIME AND BI.END_TIME AND
                ES.HOST LIKE BI.HOST AND
                ES.STATEMENT_HASH LIKE BI.STATEMENT_HASH AND
                ( BI.CONN_ID = -1 OR ES.CONNECTION_ID = BI.CONN_ID ) AND
                ( BI.OPERATIONS = 'TOTAL' AND ES.OPERATION IN ('AGGREGATED_EXECUTION', 'CALL', 'EXECUTE', 'EXECUTE_DDL', 'INSERT', 'UPDATE', 'DELETE') OR
                  INSTR(BI.OPERATIONS, ES.OPERATION) != 0 OR
                  BI.OPERATIONS = '%' ) AND
                ES.APP_USER LIKE BI.APP_USER AND
                ES.DB_USER LIKE BI.DB_USER AND
                IFNULL(ES.APPLICATION_SOURCE, '') LIKE BI.APP_SOURCE AND
                ( BI.MIN_MEM_GB = -1 OR ES.MEMORY_SIZE / 1024 / 1024 / 1024 >= BI.MIN_MEM_GB ) AND 
                ( BI.MAX_MEM_GB = -1 OR ES.MEMORY_SIZE / 1024 / 1024 / 1024 <= BI.MAX_MEM_GB ) AND
                ( BI.MIN_DURATION_S = -1 OR ES.DURATION_MICROSEC >= BI.MIN_DURATION_S * 1000000 ) AND
                IFNULL(ES.ERROR_TEXT, '') LIKE BI.ERROR_TEXT AND
                ( BI.ERROR_CODE = -1 OR ES.ERROR_CODE = BI.ERROR_CODE ) AND
                ( BI.ONLY_ERRORS = ' ' OR ES.ERROR_CODE != 0) AND
                UPPER(TO_VARCHAR(SUBSTR(ES.STATEMENT_STRING, 1, 5000))) LIKE UPPER(BI.SQL_PATTERN) LEFT OUTER JOIN
              M_SQL_CLIENT_NETWORK_IO N ON
                N.HOST = ES.HOST AND
                N.PORT = ES.PORT AND
                N.MESSAGE_ID = ES.NETWORK_MESSAGE_ID AND
                N.CONNECTION_ID = ES.CONNECTION_ID LEFT OUTER JOIN
              ( SELECT
                  STATEMENT_EXECUTION_ID,
                  STRING_AGG(TO_DECIMAL(ROUND(MEMORY_SIZE / 1024 / 1024), 10, 0) || CHAR(32) || 'MB (' || EXECUTION_HOST || ':' || EXECUTION_PORT || ')', ';' ORDER BY MEMORY_SIZE DESC) LOCATION_STATISTICS
                FROM
                ( SELECT
                    STATEMENT_EXECUTION_ID,
                    EXECUTION_HOST,
                    EXECUTION_PORT,
                    MAX(MEMORY_SIZE) MEMORY_SIZE
                  FROM
                    M_EXPENSIVE_STATEMENT_EXECUTION_LOCATION_STATISTICS
                  GROUP BY
                    STATEMENT_EXECUTION_ID,
                    EXECUTION_HOST,
                    EXECUTION_PORT
                )
                WHERE
                  STATEMENT_EXECUTION_ID != 0
                GROUP BY
                  STATEMENT_EXECUTION_ID
              ) ESL ON
                ESL.STATEMENT_EXECUTION_ID = ES.STATEMENT_EXECUTION_ID
            GROUP BY
              CASE
                WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'TIME') != 0 THEN 
                  CASE 
                    WHEN BI.TIME_AGGREGATE_BY LIKE 'TS%' THEN
                      TO_VARCHAR(ADD_SECONDS(TO_TIMESTAMP('2014/01/01 00:00:00', 'YYYY/MM/DD HH24:MI:SS'), FLOOR(SECONDS_BETWEEN(TO_TIMESTAMP('2014/01/01 00:00:00', 
                      'YYYY/MM/DD HH24:MI:SS'), CASE BI.TIMEZONE WHEN 'UTC' THEN ADD_SECONDS(ES.START_TIME, SECONDS_BETWEEN(CURRENT_TIMESTAMP, CURRENT_UTCTIMESTAMP)) ELSE ES.START_TIME END) / SUBSTR(BI.TIME_AGGREGATE_BY, 3)) * SUBSTR(BI.TIME_AGGREGATE_BY, 3)), 'YYYY/MM/DD HH24:MI:SS')
                    ELSE TO_VARCHAR(CASE BI.TIMEZONE WHEN 'UTC' THEN ADD_SECONDS(ES.START_TIME, SECONDS_BETWEEN(CURRENT_TIMESTAMP, CURRENT_UTCTIMESTAMP)) ELSE ES.START_TIME END, BI.TIME_AGGREGATE_BY)
                  END
                ELSE 'any' 
              END,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'HOST')      != 0 THEN ES.HOST                                             ELSE MAP(BI.HOST, '%', 'any', BI.HOST)                     END,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'HASH')      != 0 THEN ES.STATEMENT_HASH                                   ELSE MAP(BI.STATEMENT_HASH, '%', 'any', BI.STATEMENT_HASH) END,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'CONN_ID')   != 0 THEN TO_VARCHAR(ES.CONNECTION_ID)                        ELSE MAP(BI.CONN_ID, -1, 'any', TO_VARCHAR(BI.CONN_ID))    END,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'OPERATION') != 0 THEN ES.OPERATION                                        ELSE MAP(BI.OPERATIONS, '%', 'any', BI.OPERATIONS)         END,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'APP_USER')  != 0 THEN ES.APP_USER                                         ELSE MAP(BI.APP_USER, '%', 'any', BI.APP_USER)             END,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'DB_USER')   != 0 THEN ES.DB_USER                                          ELSE MAP(BI.DB_USER, '%', 'any', BI.DB_USER)               END,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'SOURCE')    != 0 THEN ES.APPLICATION_SOURCE                               ELSE MAP(BI.APP_SOURCE, '%', 'any', BI.APP_SOURCE)         END,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'ERROR')     != 0 THEN ES.ERROR_CODE || MAP(ES.ERROR_TEXT, '', '', ' (' || ES.ERROR_TEXT || ')') ELSE 'any'                           END,
              CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'BINDS')     != 0 THEN ES.PARAMETERS                                       ELSE 'any'                                                 END,
              BI.RESULT_ROWS,
              BI.SQL_TEXT_OUTPUT_LENGTH,
              BI.ORDER_BY,
              BI.MIN_SQL_TEXT_LENGTH
          )
          WHERE
            (MIN_SQL_TEXT_LENGTH = -1 OR SQL_TEXT_LENGTH >= MIN_SQL_TEXT_LENGTH )
        )
        WHERE
          ( RESULT_ROWS = -1 OR ROW_NUM <= RESULT_ROWS )
        ORDER BY
          ROW_NUM
EOF

    ${HDBSQL_EXE} -a -c \; -U ${USERSTORE_KEY} -I ${sql_in_ex_rep_tmp} -o ${sql_out_ex_rep_tmp}

    echo "Info:: expensive sql report from ${SAPSID} DB for last ${DAYS_TO_MONITOR} has been generated here - ${sql_out_ex_rep_tmp} ." |& tee -a ${LOGGER}
    echo "Attached is the expensive sql report from ${SAPSID} DB for last ${DAYS_TO_MONITOR}. Below is the execution log of the ${TOOL_NAME}" | mailx -s "Success::Expensive_SQLReport:: SAP System ${SAPSID}." -a ${sql_out_ex_rep_tmp} ${MAILER} < ${LOGGER}
else
    echo "Error:: Your HANA database ${SAPSID} is not running at this moment." |& tee -a ${LOGGER}
    echo "Error:: ${TOOL_NAME} will exit from this execution, you can run me adhoc when the DB is up." |& tee -a ${LOGGER}
    echo "Info:: GoodBye" |& tee -a ${LOGGER}
    echo "${TOOL_NAME} could not generate the expensive sql report from ${SAPSID} DB. Below is the execution log of the ${TOOL_NAME}" | mailx -s "Error::Expensive_SQLReport:: SAP System ${SAPSID}." ${MAILER} < ${LOGGER}
    exit 1
fi

}
# END OF FUNCTION
#==================================================



#==================================================
#Main Body of the Tool

# Tool running options
case ${1} in
        -help)                   tool_help                                 ;;
        -usage)                  tool_help                                 ;;
        -version)                tool_version                              ;;
        -h)                      tool_help                                 ;;
        -v)                      tool_version                              ;;
        -u)                       tool_help                                ;;
        -i)                      tool_info                                 ;;
        -info)                   tool_info                                 ;; 
        *)                       tool_input_check                          ;;
esac
#End of Main Body of the Tool
#==================================================
