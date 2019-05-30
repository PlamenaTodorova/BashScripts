#!/bin/bash

num=$(( (RANDOM % 100) + 1  ))

echo Guess?
read attempt
tries=1

while [ $attempt -ne $num ]
do
	if [ $attempt -lt $num ]
	then
		echo ...bigger!
	else
		echo ...smaller!
	fi
	tries=$(( tries + 1 ))
	echo Guess?
	read attempt
done
echo Right! Guessed $num in $tries tries