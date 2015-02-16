#!/bin/bash
#
# NOTE1: You must have AWS API/CLI tools installed on the
#		machine you are running this script on.
#
# Version 1.3 
#

#Get the date
month=`date "+%m-%d-%Y" | awk 'BEGIN{FS="-"} {print $1}'`
day=`date "+%m-%d-%Y" | awk 'BEGIN{FS="-"} {print $2}'`
daynegone=""`expr $day - 1`""
rds-snapshot=
#===== Add your servers here =====
snapshotidentifier=`aws rds describe-db-snapshots | grep rds-snapshot | grep $month-$day | awk 'BEGIN{FS=" "} {print $5}'`
tempinstanceidentifier="add your new temp instance here"

testsnapshot=$snapshotidentifier
echo "snapshotidentifier:$snapshotidentifier"
echo "testsnapshot:$testsnapshot"
#=================================

#===Options for how the server is built ====
option=default:sqlserver-ee-11-00
secgroup="add your security group here"
serversize="rds instance here"
#=================================

removetemprds=/tmp/rmrds.tmp
#==== Logging ======
logfile=~/scripts/rds/rds.log
logfolder=~/scripts/rds
#Start the logging
exec >> $logfile 2>&1


echo "====== Starting LOGGING `date`======"
if
	#Testing to see if the remove RDS file is placed.
	[ -f $removetemprds ]
then
		echo "Deleting DB-instance"
		aws rds delete-db-instance --db-instance-identifier $tempinstanceidentifier --skip-final-snapshot
		rm $removetemprds
		statusremove=`aws rds describe-db-instances --db-instance-identifier $tempinstanceidentifier`
		aws ses send-email --from sender@company.com --to receiver@company.com receiver2@company.com --subject "AWS temp RDS has been removed" --text "$statusremove"
else
		
			#Test to see is Temp instance is there
			if
				
				[ "`aws rds describe-db-instances | grep $tempinstanceidentifier | grep $serversize | awk 'BEGIN{FS=" "} {print $8}'`" == "available" ]
				
			then

				echo "===== Temp server already built exiting ====="
				exit 0
			fi

			
			#Creating new temperary RDS instance
			
			if
				echo "Test:$testsnapshot"
				[ -z $testsnapshot ]
			then
				
				echo "Snapshot does not exist....exiting"
				exit
			else
				echo "Creating new temp instance from snapshot"
				aws rds restore-db-instance-from-db-snapshot --db-instance-identifier $tempinstanceidentifier --db-snapshot-identifier $snapshotidentifier --db-instance-class $serversize --option-group $option
				
			fi
			
			#Waiting for the new instance to come on-line
			until 
				[ "`aws rds describe-db-instances --db-instance-identifier $tempinstanceidentifier | awk 'BEGIN{FS=" "} {print $8}'`" == "available" ]
			do
				echo "Waiting for the temp RDS server to enter available"
				echo "Sleeping for 30sec"
				echo `date`
				sleep 30
			done
			echo "==== Changing sec group ===="
			aws rds modify-db-instance --db-instance-identifier $tempinstanceidentifier --db-security-groups $secgroup
			if
				[ "`aws rds describe-db-instances --db-instance-identifier $tempinstanceidentifier | awk 'BEGIN{FS=" "} {print $8}'`" == "available" ]
			then
				echo "==== Server is built `date` ===="
				status=`aws rds describe-db-instances --db-instance-identifier $tempinstanceidentifier`
				aws ses send-email --from sender@company.com --to receiver@company.com receiver2@company.com --subject "AWS Temp RDS is now up" --text "$status"
			else
				echo "Need to exit, server is not there or not in a good state"
				exit
			fi
fi
