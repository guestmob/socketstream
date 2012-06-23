#!/bin/bash

respfile="/tmp/$$.resp"

if [ $# -ne 2 ]
then
	echo "Usage: `basename $0` folder file_to_be_uploaded"
	exit -1
fi

folder=$1
uploadfile=$2

#Authenticate

curl -D $respfile \
	-H "X-Auth-Key: d0ef6407a52bbf2235099ae96e46103e" \
	-H "X-Auth-User: guestmob" \
	--silent https://auth.api.rackspacecloud.com/v1.0

token=`grep "X-Auth-Token:" $respfile | cut -d':' -f2 | tr -d '\r\n'`
storage=`grep "X-Storage-Url:" $respfile | cut -d':' -f2,3 | tr -d '\r\n'` 

#month=`date +"%Y%m"`
#folder="backup_"$month

# Create folder

#curl -X PUT -D - \
#	-H "X-Auth-Token: $token" \
#	--silent $storage/$folder

# Upload the backup file 
ext=`echo $uploadfile | cut -d'.' -f2`
case $ext in
	"js"   ) mime="text/javascript";;
	"css"  ) mime="text/css";;
	*       ) mime="application/octet-stream";;
esac

curl -X PUT -T $uploadfile -D - \
	-H "Content-Type: $mime" \
	-H "X-Auth-Token: $token" \
	--silent $storage/$folder/$uploadfile

rm $respfile

