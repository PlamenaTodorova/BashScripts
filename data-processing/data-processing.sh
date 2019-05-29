#!/bin/bash

if [ $# -lt 4 ]
then
	echo "Not enough parameters"
	exit 1
fi

if [ ! -f $1 ]
then
	echo "Log file not found"
	exit 2 #log file not found
fi

if [ ! -f $2 ]
then
	echo "Eeg file not found"
	exit 3 #eeg file not found
fi

if [ ! -e $3 ]
then
	echo "Wav file not found"
	exit 4 #wav file not found
fi

if [ ! -d $4 ]
then
        mkdir -p $4 #create the output directory if it doesn't exist already
fi

if [ "${EEG_TZ}" == "" ]
then
	EEG_TZ="UTC"
fi

samplingRate=$(cat $2 | grep "<SamplingRate>" | sed -E 's/<SamplingRate>([[:digit:]]+).*<\/SamplingRate>/\1/g')
startRecordingDate=$(cat $2 | grep "<StartRecordingDate>" | sed -E 's/<StartRecordingDate>(.*)<\/StartRecordingDate>/\1/g')
startRecordingTime=$(cat $2 | grep "<StartRecordingTime>" | sed -E 's/<StartRecordingTime>(.*)<\/StartRecordingTime>/\1/g')
ticks=$(cat $2 | grep "<tick>")

if [ "${samplingRate}" == "" ]
then
	echo "No sampling rate found in the EEG file"
	exit 5 #no sampling rate
fi

if [ "${startRecordingDate}" == "" ]
then
        echo "No starting recording date found in the EEG file"
        exit 6 #no start recording date
elif [[ !  "${startRecordingDate}" =~ [[:digit:]]{2}\.[[:digit:]]{1,2}\.[[:digit:]]{4} ]]
then
	echo "Date format not matching"
	exit 7 #not matching date format
else
	startRecordingDate=$(echo ${startRecordingDate} | sed -E 's/([[:digit:]]{2})\.([[:digit:]]{1,2})\.([[:digit:]]{4})/\3-\2-\1/g')
fi

if [ "${startRecordingTime}" == "" ]
then
        echo "No starting recording time found in the EEG file"
        exit 8 #no start recording timei
fi

eegStart=$(TZ="${EEG_TZ}" date -d "$(echo "${startRecordingDate}" "${startRecordingTime}")" '+%s')
eegEnd=$(echo "$(echo "${ticks}" | wc -l)/${samplingRate}+${eegStart}" | bc)

if [ $(cat $1 | cut -d ' ' -f1 | sort | uniq -d | wc -l) -ne 0 ]
then
	echo "Invalid log file. There are repeating stimulus"
	exit 9 #repeating stimulus
fi

audioStart=$(cat $1 | grep -w "beep" | cut -d " " -f3)

if [ "${audioStart}" == "" ]
then
	echo "No beep stimul"
	exit 10 #no beep stimul
fi

audioDuration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $3)

if [ "${audioDuration}" == "" ]
then
	echo "$3" "is not an audio file"
	exit 11 #not an audio file
fi

audioEnd=$(echo "${audioStart}+${audioDuration}" | bc)

stimulus=$(cat $1 | grep -v -w "beep")

IFS=$'\n'
for line in $(echo "${stimulus}")
do
	name=$(echo ${line} | cut -d " " -f1)
	begin=$(echo ${line} | cut -d " " -f2)
	end=$(echo ${line} | cut -d " " -f3)
	
	if [ "${name}" == "" -o "${begin}" == "" -o "${end}" == "" ]
	then 
		echo "Stimul has an invalid format"
	elif [ $(echo "${end}-${begin}>0.2" | bc) -eq 0 ]
	then
		echo "Stimul " "${name}" " has a too short time span"
	elif [ $(echo "${eegStart}<=${begin}" | bc) -eq 0 -o $(echo "${eegEnd}>=${end}" | bc) -eq 0 ] 
	then
		echo "Stimul " "${name}" " is out of the eeg file's range"
	elif [ $(echo "${audioStart}<=${begin}" | bc) -eq 0 -o $(echo "${audioEnd}>=${end}" | bc) -eq 0 ]
	then
		echo "Stimul " "${name}" " is out of the audio file's range"
	else
		fromLine=$(echo "((${begin}-${eegStart})*${samplingRate}+1)/1" | bc)
		numLines=$(echo "((${end}-${eegStart})*${samplingRate})/1-${fromLine}" | bc)
		echo "${ticks}" | tail -n +${fromLine} | head -n ${numLines} > $4/"${name}"_eeg.xml

		fromPosition=$(echo "${begin}-${audioStart}" | bc )
		toPossition=$(echo "${end}-${audioStart}" | bc)

		if [ -e "$4/${name}_lar.wav" ]
		then
			echo "Stimul ${name} already existed in the output directory output and would be removed"
			rm "$4/${name}_lar.wav"
		fi

		ffmpeg -ss ${fromPosition} -to ${toPossition} -i $3 $4/${name}_lar.wav &>/dev/null
		echo "Stimul" ${name} "was saved"
	fi
done
