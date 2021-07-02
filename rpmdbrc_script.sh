#RPM Database Recovery  Script
#testing
# "#######################################################"
# "##	1)Database Checking                             ##"
# "##	2)Database fixing                       	##"
# "##	3)Database Backup                       	##"
# "##	4)Database Info                         	##"
# "##	5)Database Integrity                    	##"
# "##	6)Database third-party                  	##"
# "#######################################################"


red=`tput setaf 1`
green=`tput setaf 2`
normal=`tput sgr0`

case "$1" in
    #Checking the database
    -c | --check)
   		 echo "Database checking will take time please wait... "
	   	 #Using db_verify to check /var/lib/rpm/Pacakages
   		 db_verify /var/lib/rpm/Packages
   		 #Checking for return value of db_verify.db_verify returns 0 on successful execution
   		 if [ $(echo $?) != 0 ]
   			 then
    			 echo "Fixing the Database is Required.Use rpmdbrc --dbfix"
   		 fi   

		error=`timeout 60s rpm -qa | echo $?`
		 if [  $error != 0  ]
	 	 then 
	 		echo "${red}Database is not well Check and recover it if needed${normal}"
	         	#	break
		else	

   		 	#Calculating total number of packages and determining if the database is in good state or not
   		 	total_packages=`rpm -qa | wc -l` 
   		 	if [ total_packages > 300 ]
   			 	then
     				 echo -e "The Database is in...${green} (Good State)${normal}"
   		 	else
     				 echo  "The Database is in...${red}(Bad State)${normal}"
   		 	fi
		fi	
     			 ;;
	 
    #Fixing the Database
    -f| --dbfix )   
   		 db_verify /var/lib/rpm/Packages
   		 if [ $(echo $?) != 0 ]
   			 then
     			 echo "Fixing the Database will take time please wait..."
     			 mv -v  /var/lib/rpm/Packages /var/lib/rpm/Packages.bad
    			 #Removing stale lock files
     		 rm -rvf /var/lib/rpm/__db*
    			 #Rebuilding the database
     		 rpm --rebuilddb
      		 #The utility db_dump dumps the database into a readable format that is read by db_load
      			 db_dump /var/lib/rpm/Packages.bad |db_load /var/lib/rpm/Packages
	 
     			 rpm -vv --rebuilddb
           		 #Verifying the database again and checking the return value for db_verify
   		 db_verify2=`db_verify /var/lib/rpm/Packages | echo $?`
     				 if [ $db_verify2 == 0 ]
    		     		 then
      		     		 echo "Database is recovered ${green}Successfully${normal}."
     				 else
      					 echo "Database recovery ${red}Failed${normal}.Please try alternate methods."
   				 fi
   		 else
   	     	 echo "Database is ${green}Ok${normal} no need to Fix it."
   		 fi
     			 ;;    
    
    #Taking the backup of database
    -b | --backup )
	 echo "* * * * 5 /usr/sbin/rpmdbrc -b" > /etc/cron.weekly/rpmdbrc-backup
   	 echo "Please wait while taking the Backup..."
	   total_backup=`ls -l /var/preserve/rpmdb-* 2> /dev/null| wc -l `
		if [ $total_backup -gt "10" ]
			then
			echo "${red}You can Delete the Previous Backups if not required to Free the space of hardisk${normal}"	
			echo "Type YES/NO and [press Enter] to take backup "
			read excess_backup
		
		else
			excess_backup="yes" 
		fi
		case $excess_backup in 
			yes | YES)
			rpm_checking_1=`rpm -qa `
			#checking the Database	
			if [ $(echo $?) == 0 ]
			then 
			rm -rf /var/lib/rpm/__db*
		 	#timestamp
		   	 TIME=`date +%d-%m-%y-%H-%M-%S`  
   			 #backup filename, given according to the timestamp
		   	 FILENAME=rpmdb-$TIME.tar.gz
   			 #Source directory i.e the database
		  	 SRCDIR=/var/lib/rpm/*
		   	 #Destination directory i.e this is where the backup is stored
   			 DESDIR=/var/preserve/
	   		 #The Number of files present in /var/lib/rpm/ is stored in total_rpm_files
	   		 ls -l /var/lib/rpm/* | wc -l > total_rpm_files
			 rpmdb_file=`cat total_rpm_files`
   			 #Checking if files are available. If not then there is some issue in the database
   	 		 if [[ $rpmdb_file != 0 ]]
	   		 then
   		        #Creating an archive of the source directory(/var/lib/rpm/*) in the destination directory(/var/preserve)
   		 	 tar -cvf $DESDIR/$FILENAME $SRCDIR
   			 backing=`echo $?`
			 #Listing all files in the archive verbosely i.e checking if it is restorable
       			 tar -tvf $DESDIR/$FILENAME
   			 restoreable=`echo $?`   	 
 			 #Verifying   
   			 if [[ $backing == "0" && $restoreable == "0" ]]
       			 then
       			 echo "Backup Creation and Restoration ${green}Successful${normal}"
   			 else
   				 echo "Backup Creation or Restoration ${red}Failed${normal}"
   			 fi
   		         else
   		  	 echo "Some issue occured in the database. Rectify and try again."
   		       fi
		  fi 
		;;
		no | NO)
		echo "${red}You are not a good system admin Who is Saying no to create Backup. Make some space and create the backup of database. !!!IT IS VERY IMPORTANT!!!${normal}"
		;;
	
		*)
		echo "Invalid Option..."
		;;
		esac
	  
	 ;;

    	#Displaying information about Packages
    -i| --info )
   		 echo -n "Total Packages : "
   		 rpm -qa | wc -l
   		 echo -n "Packages by Redhat : "
   	 #Number of Packages owned by Red Hat
   		 rpm -qa --queryformat '%{NAME} %{VENDOR}\n' | egrep 'Red Hat, Inc' | wc -l
   		 echo -n "Third Party Packages : "
   	 #Number of third party Packages
   		 rpm -qa --queryformat '%{NAME} %{VENDOR}\n' | egrep -v 'Red Hat, Inc' | wc -l
    
   		      ;;
    -ivd |--info-details)
                 echo -n "Total Packages : "
                 rpm -qa | wc -l
                 echo -n "Packages by Redhat : "
         #Number of Packages owned by Red Hat
                 rpm -qa --queryformat '%{NAME} %{VENDOR}\n' | egrep 'Red Hat, Inc' | wc -l
                 echo -n "Third Party Packages : "
         #Number of third party Packages
                 rpm -qa --queryformat '%{NAME} %{VENDOR}\n' | egrep -v 'Red Hat, Inc' | awk '{ print $1 }'

                      ;;

    
    #Checking for integrity i.e checking for corrupted files
    -I| --integrity )
   	 echo -n "This will take 4-5 Minutes have patience... "
   		 #Verifies all the packages skipping the configuration files. Then sorts unquely the last field of rpm -Va output
   	 #and redirects to /var/preserve/integrity.txt. The obtained packages should be reinstalled.
   	 rpm -Va|egrep -v " c " |awk '{print $NF}'|xargs rpm -qf|sort|uniq > /var/preserve/integrity.txt
   		
		numberpkg=`cat /var/preserve/integrity.txt | wc -l`
		
		if [ $numberpkg != 0 ]
		then
			echo "${red}You need to reinstall these Packages${normal}"
			cat /var/preserve/intergrity.txt
		else
			echo "Your system is ${green}OK${normal}"
		fi   		
	 
	;;

    #Finds out all the packages that are not owned by Red Hat and redirects them to /var/preserve/allfiles.txt
    -t | --thirdparty )    
   		 echo -n "This will take 4-5 Minutes please wait..."
   	 #Looks for all libraries and binaries and redirects the output to /var/preserve/allfiles.txt
   		 find /lib/ /lib64/ /usr/lib /usr/lib64 /usr/bin /usr/sbin /sbin/ /bin/ |\
   		 xargs rpm -qf --queryformat '%{name} ${red}is owned by Vendor ${normal} "%{vendor}"\n' &> /var/preserve/allfiles.txt
   	 #Searching for binaries which are not owned by Red Hat or not owned by any rpm in allfiles.txt and
   	 #redirecting the obtained output (third party binaries) to /var/preserve/third-party.txt
   		 egrep -v "Red Hat, Inc.|not owned" /var/preserve/allfiles.txt >\
			 /var/preserve/third-party.txt
   	 #Searching for files/binaries that are not owned by any rpm in allfiles.txt and redirecting to /var/preserve/not-owned.txt
   		 egrep "not owned" /var/preserve/allfiles.txt > /var/preserve/not-owned.txt
   		 echo ===========================================================
   		 #Displaying the content in /var/preserve/third-part.txt uniquely
   	 echo "${red}Third Party${normal} rpms are as follows: "
   		 cat /var/preserve/third-party.txt | sort | uniq
   		 echo ===========================================================
   		 #Displaying the file name only (omitting the fields 'file' and 'is not owned by any package')
   	 echo "Files not owned by any rpms, i.e. manually created or compiled) :"
   		 cat /var/preserve/not-owned.txt | \
   		 sed -r 's/is not owned by any package//g'| \
   		 sed -r 's/file//g'
   			 ;;
    
    #Displays in detail about different options that needs to be used for proper execution of the script    
    --help)
   		 echo " USAGE: rpmdbrc [OPTION]..."
   		 echo -e "\n -c, --check\t\tchecks the rpm database state\n -f, --dbfix\t\tto fix corrupted database\n -b, --backup\t\tCreates an archive of the database\n -i, --info\t\tDisplays total number of pacakges\n -I, --integrity\tchecks for corrupted packages\n -t, --thirdparty\tShows all the third party Package information\n -ivd, --info-details\tlists the third party package names"       	 
   			 ;;

    #If the option you provided did'nt work try out the --help option
    *)
   		 echo "USAGE : rpmdbrc [OPTION]"
   		 echo "Try --help for more information"
    
   		 ;;
esac


