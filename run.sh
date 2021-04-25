#!/bin/bash

jocaml server.ml 1 0 61 0 61 12345 &
jocaml server.ml 2 0 61 61 122 12346 &
jocaml server.ml 3 61 122 0 61 12347 &
jocaml server.ml 4 61 122 61 122 12348 &

echo "Press any key to terminate"
while [ true ] ; do
	read -t 3 -n 1
	if [ $? = 0 ] ; then :
		ps -ef | grep 'jocaml' | grep -v grep | awk '{print $2}' | xargs -r kill -9 ;
		exit ; 
	else 
		echo "waiting..."
	fi
done