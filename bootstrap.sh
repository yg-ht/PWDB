#!/bin/bash

control_c()
{
  echo -en "\n*** User Signalled to Exit ***\n"
  exit $?
}
trap control_c SIGINT

#set vars and move to working directory:
awesomemachine=1
enablecracking=0
extendedracking=0
version="0.1.17 - 20150806"
path="/data/felix/PWDB"
toolspath="/root"
dictionariespath="/data/wordlists"
pipalpath="pipal"
packpath="pack"
hashcatpath="ocl-2.01"
hashcatbinary="oclHashcat64.bin"
#hashcatoptions=""
hashcatoptions=" --force --gpu-loops=1024 --gpu-accel=256 --gpu-temp-abort=100"
logfile="bootstrap.log"
messages="messages.log"
currentdate=`date +%Y-%V`
cd $path/working

#empty the working directory
if [ "$enablecracking" = "1" ]
then
   rm -f $path/working/*
fi

echo "Prepared the working directory" >> $logfile
workingdirectoryfiles=`ls -l $path/working/ | grep -v "^d" | awk {'print $9'} | wc -l`
if [ "$workingdirectoryfiles" != "2" ] && [ "$enablecracking" = "1" ]
then
   echo "Unable to clear working directory - exiting"
   exit
else
   touch NTLM.crack
   touch LM.crack
   touch cracked-NTLM-import.tsv
   touch cracked-LM-import.tsv
fi

#check PostgreSQL is alive
postgresqlStatus=`/bin/systemctl status postgresql.service | grep "Active: active (running)" | wc -l` >> $messages
if [ "$postgresqlStatus" != "1" ]
then
   echo "Database does not appear to be started - cannot continue. Perhaps run 'service postgresql start' ?" >> $logfile
   exit
else
   echo "Database appears to be online - continuing" >> $logfile
fi

echo "" >> $logfile
echo "PWDB automated cracking scripts and database management" >> $logfile
echo "" >> $logfile
echo "Written by Felix Ryan" >> $logfile
echo "" >> $logfile
echo "Version $version" >> $logfile
echo "" >> $logfile
echo "This run started at:" >> $logfile
echo `date -u` >> $logfile

#get pwdummp file list:
pwdumpfiles=`ls -l $path | grep '.pwdump' | grep -v '^d' | awk {'print $9'}`
if [ "$pwdumpfiles" = "" ]
then
   echo "No *.pwdump files found - exiting" >> $logfile
   exit
fi

echo "PWDump file(s) detected:" >> $logfile
echo "$pwdumpfiles" >> $logfile
echo "" >> $logfile

#get client name:
clientname=`echo $pwdumpfiles | awk -F ".pwdump" {'print $1'}`
if [ "$clientname" = "" ]
then
   echo "Unable to determine client name - exiting" >> $logfile
   exit
fi
echo "Client is:" >> $logfile
echo "$clientname" >> $logfile
echo "" >> $logfile

#get related file list:
clientfiles=`ls -l $path | grep "$clientname" | grep -v "^d" | awk {'print $9'}`
if [ "$clientfiles" = "" ]
then
   echo "" >> $logfile
   echo "+=+=+=+" >> $logfile
   echo "WARNING" >> $logfile
   echo "+=+=+=+" >> $logfile
   echo "No supporting client files found! (e.g. [CLIENTNAME].domainenum)" >> $logfile
   echo "No additional processing can be completed" >> $logfile
fi
echo "Detected client files:" >> $logfile
echo "$clientfiles" >> $logfile
echo "" >> $logfile

#copy the files to the working directory:
echo "Copying client files to working directory" >> $logfile
for file in $( echo $clientfiles ); do cp $path/$file $path/working; done
workingdirectoryfiles=`ls -l $path/working/ | grep -v "^d" | awk {'print $9'}`
if [ "$workingdirectoryfiles" = "" ]
then
   echo "Unable to copy files to working directory - exiting" >> $logfile
   exit
fi

#cleanup previous job
echo "Cleaning up the Database" >> $logfile
psql pwdb -q -c "TRUNCATE currentclient, currentclientdomainadmins, currentclientliveusers, importcrackedlm, importcrackednt"

#ensure pwdump is clean:
echo "Sanitizing pwdump file" >> $logfile
mv $clientname.pwdump unclean0.pwdump
cat unclean0.pwdump | tr [:upper:] [:lower:] > unclean1.pwdump
cat unclean1.pwdump | sed "s/no password\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*:::/31d6cfe0d16ae931b73c59d7e0c089c0:::/g" > unclean2.pwdump
cat unclean2.pwdump | sed "s/no password\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*/aad3b435b51404eeaad3b435b51404ee/g" > unclean3.pwdump
cat unclean3.pwdump | sed "s/00000000000000000000000000000000/aad3b435b51404eeaad3b435b51404ee/g" > unclean4.pwdump
cat unclean4.pwdump | tr '\200-\377' '*' > clean.pwdump

#remove the machine accounts:
echo "Excluding the machine accounts from processing" >> $logfile
cat clean.pwdump | grep -v "\\$" > useraccountsonly.pwdump

#make client import (for DB):
echo "Preparing the User/NTLM/LM1/LM2 details for database import" >> $logfile
cat useraccountsonly.pwdump | tr '[:upper:]' '[:lower:]' | awk -F ":" {'print $1"\t"$4"\t"substr($3,0,16)"\t"substr($3,17,16)'} > useraccountsonly-import.tsv

#import users and hashes
echo "Importing User/NTLM/LM1/LM2 into DB" >> $logfile
psql pwdb -c "\COPY currentclient FROM 'useraccountsonly-import.tsv'"

if [ "$clientfiles" != "" ]
then
   #Find Domain Admins:
   echo "Finding interesting accounts (admins)" >> $logfile
   grep "^Group 'Domain Admins'\|^Group 'Enterprise Admins'" $clientname.domainenum | tr [:upper:] [:lower:] | awk -F "\\" {'print $2'} | sort -u > domainadmins.tsv

   #import user detail and admin membership
   echo "Importing User Detail and Admin Group membership into DB" >> $logfile
   psql pwdb -c "\COPY currentclientdomainadmins FROM 'domainadmins.tsv'"

   #Find interesting detail about users:
   echo "Getting detail from DomainEnum on users" >> $logfile
   grep index $clientname.domainenum | sed 's/,/\,/g' | cut -d ':' -f 5- | sed 's/Name: //g' | sed 's/Desc: //g' | sed 's/^ //g' | awk -F "\t" '{print $1",\""$2"\",\""$3"\""}' > userdetail.tsv

   #Find domain controllers:
   echo "Finding Domain Controllers" >> $logfile
   grep "Group 'Domain Controllers" $clientname.domainenum | grep "has member"| awk {'print $8'} | cut -d "\\" -f 2 | cut -d "\$" -f 1 > $clientname.domaincontrollers

   #Finding live users
   echo "Finding Live Users" >> $logfile
   cat $clientname.pwprofile | sed "s/\"//g" | awk -F "," {'print $1,$6'} | grep True | awk {'print $1'} | tr [:upper:] [:lower:] > $clientname.liveusers

   #import liveusers
   echo "Importing Live Users into DB" >> $logfile
   psql pwdb -c "\COPY currentclientliveusers FROM '$clientname.liveusers'"
fi

#download those not already cracked on previous jobs
echo "Downloading those already cracked on previous jobs" >> $logfile
psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackedlm) TO 'cracked-LM.tsv'"
psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackednt) TO 'cracked-NT.tsv'"
echo "Downloading those that are not already cracked" >> $logfile
psql pwdb -c "\COPY (SELECT * FROM listuserswithuncrackedlm) TO 'uncracked-LM.tsv'"
psql pwdb -c "\COPY (SELECT * FROM listuserswithuncrackednt) TO 'uncracked-NTLM.tsv'"

#seperate the LM hashes out and put them together:
echo "Filtering LM hashes out ready for cracking" >> $logfile
cat uncracked-LM.tsv | awk -F "\t" {'print $2'} > LM-hashesonly.list
cat uncracked-LM.tsv | awk -F "\t" {'print $3'} >> LM-hashesonly.list

#seperate the NTLM hashes out:
echo "Filtering NT hashes out ready for cracking" >> $logfile
cat uncracked-NTLM.tsv | awk -F "\t" {'print $2'} | sort -u > NTLM-hashesonly.list

#end of prep

customdicfile=`ls -l | grep "$clientname.dic" | grep -v "^d" | awk {'print $9'}`
if [ "$customdicfile" != "" ] && [ "$enablecracking" = "1" ]
then
   echo "Cracking using customdictionary supplied with pwdump" >> $logfile
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove --session=hashdumpNTLM-custom3-dic -m1000 NTLM-hashesonly.list $clientname.dic --rules $path/sundries/all.rule -o NTLM.crack >> $messages
fi

memcachefile=`ls -l | grep "$clientname.mem" | grep -v "^d" | awk {'print $9'}`
if [ "$memcachefile" != "" ] && [ "$enablecracking" = "1" ]
then
   echo "Creating dictionary from Cached Passwords in Memory extracted by Kiwi / SMBExec v2" >> $logfile
   cat $clientname.mem | awk -F ":" {'print $2'} > mem.dic
   echo "NTLM crack - dictionary - based on passwords extracted from machine cached passwords" >> $logfile
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove --session=hashdumpNTLM-custom2-dic -m1000 NTLM-hashesonly.list mem.dic --rules $path/sundries/all.rule -o NTLM.crack >> $messages

   #import cracked NTLMs to DB
   echo "Now the additonal dictionaries have completed, preparing an importing for the cracked NTLM hashes to the database" >> $logfile
   cat NTLM.crack | awk -F ":" {'print $2"\t"$1'} > cracked-NTLM-import.tsv

   #import the cracked NT hashes from the above
   echo "Now the additonal dictionaries have completed, importing Plain/NTLM into DB" >> $logfile
   psql pwdb -c "\COPY importcrackednt FROM 'cracked-NTLM-import.tsv'"
   psql pwdb -c 'INSERT INTO crackednt (plain, cryptont) SELECT plain, cryptont FROM newcrackednt'

   #download current cracked in case user wants to start playing with newly cracked passwords
   echo "Downloading cracked hashes part way through processing in case the user wants to play" >> $logfile
   psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackedlm) TO 'cracked-LM.tsv'"
   psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackednt) TO 'cracked-NT.tsv'"
fi

#Crack NTLMs using pre-made dictionaries:
if [ "$enablecracking" = "1" ]
then
   echo "NTLM cracking - dictionary - based on the rockyou list and all rule sets" >> $logfile
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove --session=hashdumpNTLM-rockyou -m1000 NTLM-hashesonly.list $dictionariespath/rockyou.dic --rules $path/sundries/all.rule -o NTLM.crack >> $messages

   #import cracked NTLMs to DB
   echo "Now the additonal dictionaries have completed, preparing an importing for the cracked NTLM hashes to the database" >> $logfile
   cat NTLM.crack | awk -F ":" {'print $2"\t"$1'} > cracked-NTLM-import.tsv

   #import the cracked NT hashes from the above
   echo "Now the additonal dictionaries have completed, importing Plain/NTLM into DB" >> $logfile
   psql pwdb -c "\COPY importcrackednt FROM 'cracked-NTLM-import.tsv'"
   psql pwdb -c 'INSERT INTO crackednt (plain, cryptont) SELECT plain, cryptont FROM newcrackednt'

   #download current cracked in case user wants to start playing with newly cracked passwords
   echo "Downloading cracked hashes part way through processing in case the user wants to play" >> $logfile
   psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackedlm) TO 'cracked-LM.tsv'"
   psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackednt) TO 'cracked-NT.tsv'"
fi

#crack the LMs using bruteforce
if [ "$enablecracking" = "1" ] && [ `wc -l LM-hashesonly.list | awk {'print $1'}` != "0" ]
then
   echo "LM Cracking - brute force - all charsets, chars 1-5" >> $logfile
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpLM-bruteAll -m3000 -1 '?a' LM-hashesonly.list -o LM.crack '?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpLM-bruteAll -m3000 -1 '?a' LM-hashesonly.list -o LM.crack '?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpLM-bruteAll -m3000 -1 '?a' LM-hashesonly.list -o LM.crack '?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpLM-bruteAll -m3000 -1 '?a' LM-hashesonly.list -o LM.crack '?1?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpLM-bruteAll -m3000 -1 '?a' LM-hashesonly.list -o LM.crack '?1?1?1?1?1' >> $messages
else
   echo "LM Cracking - no hashes found or cracking disabled" >> $logfile
fi

if [ "$awesomemachine" = "1" ] && [ "$enablecracking" = "1" ] && [ `wc -l LM-hashesonly.list | awk {'print $1'}` != "0" ]
then
   #(same again but long time)
   echo "LM Cracking - brute force - awesome machine - all charsets, chars 6 and 7" >> $logfile
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpLM-bruteAll -m3000 -1 '?a' LM-hashesonly.list -o LM.crack '?1?1?1?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpLM-bruteAll -m3000 -1 '?a' LM-hashesonly.list -o LM.crack '?1?1?1?1?1?1?1' >> $messages
elif [ "$enablecracking" = "1" ] && [ `wc -l LM-hashesonly.list | awk {'print $1'}` != "0" ]
then
   echo "LM Cracking - brute force - non-awesome machine - alpha and numbers, chars 6 and 7" >> $logfile
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpLM-bruteUD -m3000 -1 '?u?d' LM-hashesonly.list -o LM.crack '?1?1?1?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpLM-bruteUD -m3000 -1 '?u?d' LM-hashesonly.list -o LM.crack '?1?1?1?1?1?1?1' >> $messages
else
   echo "Extended LM Cracking section - all cracking disabled or no hashes found" >> $logfile
fi

#Deal with cracked LM hashes:
numcrackedlmhashes=`wc -l LM.crack | awk {'print $1'}`
if [ "$numcrackedlmhashes" = "0" ]
then
   echo "Sadly no LM hashes have been cracked so skipping next task" >> $logfile
else
   #import cracked LMs to DB
   echo "Preparing an import for the cracked LM hashes to the database" >> $logfile
   cat LM.crack | awk -F ":" {'print $2"\t"$1'} | sort -u > cracked-LM-import.tsv

   #import the cracked LM hashes from the above
   echo "Importing Plain/LM into DB" >> $logfile
   psql pwdb -c "\COPY importcrackedlm FROM 'cracked-LM-import.tsv'"
   psql pwdb -c 'INSERT INTO crackedlm (plain, cryptolm) SELECT plain, cryptolm FROM newcrackedlm' >> $messages
fi

#download lists of cracked LM hashes
echo "Downloading the list of cracked LM hashes" >> $logfile
psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackedlm) TO 'cracked-LM.tsv'"

#Create dictionary of cracked LM hashes
echo "Creating a dictionary of known passwords from LM cracking for use with NTLM cracking" >> $logfile
psql pwdb -c "\COPY (SELECT * FROM listlmdictionary) TO 'cracked-LM.dic'"

#end of LM

#Crack the NTLM hashes based on the dictionary from the LM cracking (NEEDS BETTER RULE):
echo "NTLM Cracking - dictionary - based on LM cracking" >> $logfile
if [ "$enablecracking" = "1" ]
then
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove --session=hashcrack-NTLM-LMtoNTLM -m1000 NTLM-hashesonly.list cracked-LM.dic --rules $path/sundries/LMtoNTLM.rule -o NTLM.crack >> $messages
fi

if [ "$awesomemachine" = "1" ] && [ "$enablecracking" = "1" ]
then
   echo "NTLM Cracking - dictionary - awesome machine - extra dictionaries and all rule sets" >> $logfile
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -m1000 NTLM-hashesonly.list $dictionariespath/all.dic --rules $path/sundries/all.rule -o NTLM.crack >> $messages
#   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -m1000 NTLM-hashesonly.list $dictionariespath/cracked.dic --rules $path/sundries/all.rule -o NTLM.crack >> $messages
#   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -m1000 NTLM-hashesonly.list $dictionariespath/common.dic --rules $path/sundries/all.rule -o NTLM.crack >> $messages
#   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -m1000 NTLM-hashesonly.list $dictionariespath/english.dic --rules $path/sundries/all.rule -o NTLM.crack >> $messages
#   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -m1000 NTLM-hashesonly.list $dictionariespath/wordlist.dic --rules $path/sundries/all.rule -o NTLM.crack >> $messages

   #import cracked NTLMs to DB
   echo "Now the additonal dictionaries have completed, preparing an importing for the cracked NTLM hashes to the database" >> $logfile
   cat NTLM.crack | awk -F ":" {'print $2"\t"$1'} > cracked-NTLM-import.tsv

   #import the cracked NT hashes from the above
   echo "Now the additonal dictionaries have completed, importing Plain/NTLM into DB" >> $logfile
   psql pwdb -c "\COPY importcrackednt FROM 'cracked-NTLM-import.tsv'"
   psql pwdb -c 'INSERT INTO crackednt (plain, cryptont) SELECT plain, cryptont FROM newcrackednt'

   #download current cracked in case user wants to start playing with newly cracked passwords
   echo "Downloading cracked hashes part way through processing in case the user wants to play" >> $logfile
   psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackedlm) TO 'cracked-LM.tsv'"
   psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackednt) TO 'cracked-NT.tsv'"
fi

#crack passwords based on usernames
if [ "$enablecracking" = "1" ]
then
   echo "Creating a dictionary of usernames in an effort to crack more passwords!" >> $logfile
   psql pwdb -c "\COPY (SELECT username FROM currentclient) TO 'usernames.dic'"
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove --session=hashdumpNTLM-custom-dic -m1000 NTLM-hashesonly.list usernames.dic --rules $path/sundries/all.rule -o NTLM.crack >> $messages
fi

#Crack NTLMs using the passwords that have been cracked so far as a dictionary:
echo "Creating a dictionary of known passwords from NT cracking for use with further NTLM cracking and rules" >> $logfile
psql pwdb -c "\COPY (SELECT * FROM listntdictionary) TO 'cracked-NT.dic'"
echo "NTLM cracking - dictionary - based on the cracked passwords from this session and all the rulesets" >> $logfile
if [ "$enablecracking" = "1" ]
then
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove --session=hashdumpNTLM-custom-dic -m1000 NTLM-hashesonly.list cracked-NTLM.dic --rules $path/sundries/all.rule -o NTLM.crack >> $messages
fi

#import cracked NTLMs to DB
echo "Preparing an import for the cracked NTLM hashes to the database" >> $logfile
cat NTLM.crack | awk -F":" {'print $2"\t"$1'} > cracked-NTLM-import.tsv

#import the cracked NT hashes from the above
echo "Importing Plain/NTLM into DB" >> $logfile
psql pwdb -c "\COPY importcrackednt FROM 'cracked-NTLM-import.tsv'"
psql pwdb -c 'INSERT INTO crackednt (plain, cryptont) SELECT plain, cryptont FROM newcrackednt'

#download current cracked in case user wants to start playing with newly cracked passwords
echo "Downloading cracked hashes part way through processing in case the user wants to play" >> $logfile
psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackedlm) TO 'cracked-LM.tsv'"
psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackednt) TO 'cracked-NT.tsv'"

#Brute force NTLMs to a certain level:
echo "NTLM cracking - brute force - all charsets, chars 1-4" >> $logfile
if [ "$enablecracking" = "1" ]
then
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteAll -m1000 -1 '?a' NTLM-hashesonly.list -o NTLM.crack '?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteAll -m1000 -1 '?a' NTLM-hashesonly.list -o NTLM.crack '?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteAll -m1000 -1 '?a' NTLM-hashesonly.list -o NTLM.crack '?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteAll -m1000 -1 '?a' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1' >> $messages
fi

#(same but long time)
if [ "$awesomemachine" = "1" ] && [ "$enablecracking" = "1" ] && [ "$extendedracking" = "1" ]
then
   echo "NTLM cracking - brute force - awesome machine - all charsets chars 5-6 and lower upper and numbers for chars 7-8" >> $logfile
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteAll -m1000 -1 '?a' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteAll -m1000 -1 '?a' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteAll -m1000 -1 '?l?u?d' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteAll -m1000 -1 '?l?u?d' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1?1?1?1' >> $messages
elif [ "$enablecracking" = "1" ]
then
   echo "NTLM cracking - brute force - non-awesome machine - lower-alpha and digits, numeric, chars 5-7" >> $logfile
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteLD -m1000 -1 '?l?d' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteLD -m1000 -1 '?l?d' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteLD -m1000 -1 '?l?d' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1?1?1' >> $messages
   echo "NTLM cracking - brute force - non-awesome machine - upper-alpha and digits, numeric, chars 5-7" >> $logfile
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteUD -m1000 -1 '?u?d' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteUD -m1000 -1 '?u?d' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteUD -m1000 -1 '?u?d' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1?1?1' >> $messages
   echo "NTLM cracking - brute force - non-awesome machine - lower-alpha and upper-alpha, numeric, chars 5-7" >> $logfile
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteLU -m1000 -1 '?l?u' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteLU -m1000 -1 '?l?u' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1?1' >> $messages
   $toolspath/$hashcatpath/$hashcatbinary$hashcatoptions --remove -a3 --session=hashdumpNTLM-bruteLU -m1000 -1 '?l?u' NTLM-hashesonly.list -o NTLM.crack '?1?1?1?1?1?1?1' >> $messages
else
   echo "Extended NTLM Cracking section - all cracking disabled" >> $logfile
fi

#import cracked NTLMs to DB
echo "Preparing an import for the cracked NTLM hashes to the database" >> $logfile
cat NTLM.crack | awk -F":" {'print $2"\t"$1'} > cracked-NTLM-import.tsv

#import the cracked NT hashes from the above
echo "Importing Plain/NTLM into DB" >> $logfile
psql pwdb -c "\COPY importcrackednt FROM 'cracked-NTLM-import.tsv'"
psql pwdb -c 'INSERT INTO crackednt (plain, cryptont) SELECT plain, cryptont FROM newcrackednt'

#download current cracked in case user wants to start playing with newly cracked passwords
echo "Downloading cracked hashes part way through processing in case the user wants to play" >> $logfile
psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackedlm) TO 'cracked-LM.tsv'"
psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackednt) TO 'cracked-NT.tsv'"
psql pwdb -c "\COPY (SELECT * FROM listuserswithcrackedntincblank) TO 'cracked-NT-incblank.tsv'"

echo "Downloading analysis details" >> $logfile
psql pwdb -c "\COPY (SELECT * FROM passwordlengthanalysis ORDER BY plainlength DESC) TO 'lengthanalysis.list'"
psql pwdb -c "\COPY (SELECT * FROM numdistinctcrackedpasswords) TO 'numdistinctcrackedpasswords.txt'"
psql pwdb -c "\COPY (SELECT * FROM numdistinctpasswords) TO 'numdistinctpasswords.txt'"
psql pwdb -c "\COPY (SELECT * FROM listuserswithverypoorpassword) TO 'userswithverypoorpassword.list'"
psql pwdb -c "\COPY (SELECT * FROM listuserswherepasswordisusername) TO 'userswherepasswordisusername.list'"
psql pwdb -c "\COPY (SELECT * FROM listuserswithnonblanklm) TO 'userswithnonblanklm.list'"
psql pwdb -c "\COPY (SELECT plain FROM listuserswithcrackednt) TO 'cracked-NT.dic'"
#end of NT

#Generate some pretty stats with pipal/pack
echo "Using Pipal to create some nice stats">> $logfile
$toolspath/$pipalpath/pipal.rb cracked-NT.dic > pipal.txt
$toolspath/$packpath/statsgen.py cracked-NT.dic > pack.txt

#This run is in effect completed, just minor bits
echo "" >> $logfile
echo "The hard stuff has been completed this time round.  View the goodies in the 'cracked-NT.tsv' file" >> $logfile
echo "Perhaps the following sir:" >> $logfile
echo "ooffice --calc $path/completed/$clientname/$currentdate/cracked-NT.tsv &" >> $logfile

#Next to confirm these accounts are "live", do this by producing a colon seperated file:
echo "" >> $logfile
echo "Use the following command to find a suitable and local domain controller:" >> $logfile
echo "for host in \$(cat $clientname.domaincontrollers); do ping -c 1 \$host; done" >> $logfile
echo "" >> $logfile
psql pwdb -c "\COPY (SELECT username, plain FROM listuserswithcrackedntincblank) TO 'userColonPass.txt' DELIMITER ':';"
echo "Use the following commands to determine if the users are still live:" >> $logfile
echo "hydra -V -C userColonPass.txt [TARGET IP] smb > $clientname-unclean.liveusers" >> $logfile
echo "grep \"^\\[445\" $clientname-unclean.liveusers | awk {'print \$5'} > $clientname.liveusers" >> $logfile
echo "" >> $logfile
echo "Upload the output file and run the (perhaps in the future) analysis script for nice pictures..." >> $logfile
echo "psql pwdb -c \"\COPY currentclientliveusers FROM '$clientname.liveusers'\"" >> $logfile
echo "" >> $logfile
echo "Then you can download the list of live users with very weakpasswords:" >> $logfile
echo "psql pwdb -c \"\COPY (SELECT username, plain FROM listliveuserswithverypoorpassword) TO 'listliveuserswithverypoorpasswords.tsv';\"" >> $logfile
echo "" >> $logfile
echo "Finished at:" >> $logfile
echo `date -u` >> $logfile
echo "Finally, just performing some tidy up" >> $logfile
mkdir -p $path/completed/$clientname/$currentdate
mv $path/working/* $path/completed/$clientname/$currentdate
