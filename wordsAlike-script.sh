#!/bin/bash

words=$(cat text.txt | sed -r 's/([^[:alpha:]]+)$//g' | sed -r 's/([^[:alpha:]]+)/\n/g' | sed -r 's/(.)/\L\1/g' | sort | uniq )

for word in $words; do
	match=$(tre-agrep -B -s -w $word dic.txt | head -n 1)
	numDiff=$(echo $match | sed -r -e 's/^([[:digit:]]+):.*/\1/g')
	if [ "$numDiff" != "0" ]; then
		echo $word:$match
	fi
done

