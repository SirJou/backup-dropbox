#!/bin/bash
#COMPROBAR QUE EL USUARIO SEA ROOT
if [ "$(whoami)" != "root" ]
then
	echo "Start the script as superuser!!"
	exit
fi
#COMPROBAR QUE TENGA EL CURL INSTALADO
if [ "$(which curl | cut -d/ -f4)" != "curl" ]
then
    echo 'Please install "curl"....'
    apt install curl
fi    

function menu
{
    #MUESTRA AL FICHERO/DIRECTORIO ELEGIDO
    file_state=$(cat /etc/backup.conf | grep "current_file=" | cut -d"=" -f2)
    api_state=$(cat /etc/backup.conf | grep "api_key=" | cut -d"=" -f2)
    cron_state=$(cat /etc/backup.conf | grep "current_cron=" | cut -d"=" -f2)
    clear
    echo "===== CRON BACKUP ====="
    echo ""
    echo "1 - Select file  [ $(tput setaf 2)$file_state$(tput sgr 0) ]"
    echo "2 - Select folder"
    echo "3 - Set time  [ $(tput setaf 2)$cron_state$(tput sgr 0) ]"
    echo "4 - Set your API KEY  [ $(tput setaf 2)$api_state$(tput sgr 0) ]"
    read option1

    case $option1 in
        1)
        select_file;;
        2)
        select_folder;;
        3)
        set_time;;
        4)
        write_api_key;;
        *)
        menu;;
    esac
}

function write_api_key
{
    echo "Write your new api key:"
    read -p"> " new_api_key

    #SUSTITUYE EL ARCHIVO DEL BACKUP
        number_current_api=$(cat /etc/backup.conf | grep -n "api_key=" | cut -d: -f1)
        sed -i "$number_current_api d" "/etc/backup.conf"
        echo "api_key=$new_api_key" >> /etc/backup.conf
        menu
}

function set_time
{
    me=$(basename "$0")
    dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    chmod 777 $dir/$me
    #ESTABLECER CRONTAB
    clear
    me=$(basename "$0")
    dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    user_name=$(ls -l $dir | grep "$me" | tr -s " " | cut -d" " -f3)
    echo "===== SET CRON ===== "
    echo ""
    echo 'To select ALL press "*"'
    read -p'Month: (1 = January ,12 =December) ("*" ALL) > ' month_cron
    read -p'Day of the month: Ex: 25 ("*" ALL) > ' month_day
    read -p'Day of the week: (Ex: mon, tue, wed, thu, fri, sat, sun) ("*" ALL) > ' week_day
    read -p'Hour: Ex: 16 > ' hour_cron
    read -p'Minute: Ex: 45 or 00 > ' minute_cron
    #AÑADIR A ARCHIVO CRONTAB
    grep_dir_me=$(cat /var/spool/cron/crontabs/root | grep $dir/$me | cut -d" " -f6 | tr -d " ")
    if [ "$dir/$me" = "$grep_dir_me" ]
    then
        num_grep_dir_me=$(cat /var/spool/cron/crontabs/root | grep -n $dir/$me | cut -d: -f1)
        sed -i "$num_grep_dir_me d" "/var/spool/cron/crontabs/root"
    fi
    echo "$minute_cron $hour_cron $month_day $month_cron $week_day $dir/$me >/dev/null 2>&1" >> /var/spool/cron/crontabs/root
    systemctl cron restart
    #AÑADIR A LA CONFIGURACIÓN DEL BACKUP
        number_current_cron=$(cat /etc/backup.conf | grep -n "current_cron=" | cut -d: -f1)
        sed -i "$number_current_cron d" "/etc/backup.conf"
    echo "current_cron=$minute_cron $hour_cron $month_day $month_cron $week_day $dir/$me >/dev/null 2>&1" >> /etc/backup.conf
    menu
}

function curl_backup
{
    #subir fichero a dropbox
    backslashes=$(cat /etc/backup.conf | grep current_file | cut -d"=" -f2 | grep -o "/" | wc -l)
    let backslashes=backslashes+1
    file=$(cat /etc/backup.conf | grep current_file | cut -d"=" -f2 | cut -d/ -f"$backslashes")
    fichero=$(cat /etc/backup.conf | grep current_file | cut -d"=" -f2 | tr -d " ")
    get_pwd=$(pwd)
    if [ -d $fichero ]
    then
        #comprime el directorio y añade la fecha de backup
        tar -zcvf "$file""$(date +%Y-%m-%d_%H-%M)".tar.gz "$fichero"
        last_mod_file=$(ls -lt | head -2 | tail -1 | tr -s " " | cut -d" " -f9)
            /usr/bin/curl -X POST -s https://content.dropboxapi.com/2/files/upload --header "Authorization: Bearer $(cat /etc/backup.conf | grep "api_key=" | cut -d"=" -f2)" --header "Dropbox-API-Arg: {\"path\": \"$get_pwd/$last_mod_file\"}" --header "Content-Type: application/octet-stream" --data-binary @$last_mod_file > /dev/null
    else
        #copia el fichero al path actual y añade la fecha al nombre
        cp $fichero $file$(date +%Y-%m-%d_%H-%M)
        last_mod_file=$(ls -lt | head -2 | tail -1 | tr -s " " | cut -d" " -f9)
            /usr/bin/curl -X POST -s https://content.dropboxapi.com/2/files/upload --header "Authorization: Bearer $(cat /etc/backup.conf | grep "api_key=" | cut -d"=" -f2)" --header "Dropbox-API-Arg: {\"path\": \"$get_pwd/$last_mod_file\"}" --header "Content-Type: application/octet-stream" --data-binary @$last_mod_file > /dev/null

    fi
}

function select_file
{
      #Seleccionar un archivo
    fichero=$(zenity --file-selection "$HOME")
    #COMPRUEBA QUE NO SE HAYA CANCELADO LA SELECCIÓN
    if [ "$fichero" = "" ]
    then
        echo "You haven't selected any file"
        sleep 2
        menu
    else
        #SUSTITUYE EL ARCHIVO DEL BACKUP
        number_current_file=$(cat /etc/backup.conf | grep -n "current_file=" | cut -d: -f1)
        sed -i "$number_current_file d" "/etc/backup.conf"
        echo "current_file=$fichero" >> /etc/backup.conf
        menu
    fi
}

function select_folder
{
    #seleccionar un directorio
    fichero=$(zenity --file-selection "$HOME" --directory)
    #COMPRUEBA QUE NO SE HAYA CANCELADO LA SELECCIÓN
    if [ "$fichero" = "" ]
    then
        echo "You haven't selected any file"
        sleep 2
        menu
    else
    #SUSTITUYE EL ARCHIVO DEL BACKUP
        number_current_file=$(cat /etc/backup.conf | grep -n "current_file=" | cut -d: -f1)
        sed -i "$number_current_file d" "/etc/backup.conf"
        echo "current_file=$fichero" >> /etc/backup.conf
        menu
    fi
}
######## OPTION -H #########
############################
if [ "$1" = "-h" ]
then
    echo "BACKUP SCRIPT WITH DROPBOX"
    echo "    -----OPTIONS----
    "
    echo "-h    help. Display help menu
    "
    echo "-c    configuration. Display the configuration menu
    "
    echo "If you don't choose any option you will run the script"
    echo ""
    echo "Joel Revert Vila 2019"
fi

######## OPTION -C #########
############################
if [ "$1" = "-c" ]
then
        #COMPRUEBA QUE "BACKUP.CONF" ESTÉ CREADO Y SI NO LO ESTÁ LO CREA
        if [ -f /etc/backup.conf ]
        then
            menu
        else
            cat << EOC >> /etc/backup.conf
current_file=
api_key=
current_cron=
EOC
            menu
        fi
fi

if [ "$1" = "" ]
then
    curl_backup
fi
