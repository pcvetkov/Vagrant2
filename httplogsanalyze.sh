#!/bin/bash
#  Поскольку  access.log  файла содержит данные за 14 агуста 2019 года, то необходимо делать
# выборку именно по этой старой дате, но указывая актуальные часы из текущего системного времени
# Мы должны сформировать такую дату, которая имела бы старую дату, но при этом - реальные показатели часовой стрелки
BetweenDays=$((($(date  +%s) - $(date -d "Aug 14 2019" +%s))/60/60/24))
CurrTime=`LANG=c; date +"%d/%b/%Y:%H"  --date "${BetweenDays} days ago"`
echo "We search data for ${CurrTime}:x:x "
#  чистим  старые файлы с ранее полученными результатами
rm -f /tmp/*url.txt; rm -f /tmp/*hour.txt; rm -f /tmp/*hourep* ;rm -f /tmp/*iprep* ; rm -f /tmp/*urlrep.txt; rm -f  /tmp/*httprep*
#  делаем выборку из файла  - все строки за текущий час
grep $CurrTime access.log >/tmp/$$hour.txt
if [ -z /tmp/$$hour.txt ]
then
echo "No information for $CurrTime found in access.log file! Exiting ... "
exit 0
fi

function cleanup ()

#  удаляем  pid  файл в случае аварийного останова скрипта - по Control C  в том числе
{
    rm -f  /tmp/.httprep.pid
    exit
}

function err_msg ()
{
echo $0 is already running! exiting ... ; exit 0
}

function get_num ()

#  находим четыре  максимальных вхождений данного указанного параметра  (IP, urls, http code) из выборки за текущий час
{
NAME=$1
IN_FILE=$2
OUT_FILE=$3
shift; shift; shift
LIST=$*
for i in $LIST
do 
echo " ${NAME} = ${i} `grep -c $i ${IN_FILE}` "  >> $OUT_FILE
done
cat $OUT_FILE | sort -r -n -k4 | head -4
}



function ip_info ()
{
IPLIST=`cat  /tmp/$$hour.txt | awk '{print $1}' | sort | uniq`
echo IP and requests:
get_num IP /tmp/$$hour.txt  /tmp/$$iprep.txt $IPLIST
}

function url_info ()
{
URLs=`cut -d'"' -f2 /tmp/$$hour.txt  | cut -d' ' -f2 |sort|uniq`
echo "Urls and requests: "
get_num URL /tmp/$$hour.txt /tmp/$$urlrep.txt $URLs
}

function err_info ()
{
echo "Errors if any: "
grep -i error /tmp/$$hour.txt || echo "No errors"
}

function http_info ()
{
HTTPs=`cut -d'"' -f3 /tmp/$$hour.txt | awk '{print $1}'|sort|uniq`
echo "Http codes and number of codes : "
get_num HTTP_code /tmp/$$hour.txt /tmp/$$httprep.txt $HTTPs
}

function check_run ()
{
#  проверяем, не запущен ли второй раз тот же скрипт, проверяя существование признака -  pid file
#   если нет - создаем его. 

if [ ! -f /tmp/.httprep.pid ]
then
touch /tmp/.httprep.pid
else
echo "httplogsanalyze is already running! Exiting..."
exit 0
fi
}

# Main section

#  перехватываем прерывание, чтобы вызвать функцию  cleanup,  удаляющую   pid file
#  если это не сделать, то  после прерывания работы скрипта по  Control C  второй раз его не запустить - останется  pid file
trap cleanup 1 2 3 6
#  проверяем, не запущен ли скрипт уже .  Если запущен - выходим из скрипта  
check_run
ip_info
url_info
err_info
http_info

#  удаляем  pid file  после  отработки скрипта
rm -f /tmp/.httprep.pid
