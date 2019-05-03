#!/bin/bash

sed -E 's/([^[:alpha:]]+)$//g' text.txt | sed -E 's/([^[:alpha:]]+)/\n/g' | sed -E 's/(.)/\L\1/g' | sort | uniq | awk '{like = "tre-agrep -B -s -w " $0 " dic.txt | head -n 1"; like | getline result; split(result, a, ":"); if(a[1]!=0) print $0 ":" result}'
