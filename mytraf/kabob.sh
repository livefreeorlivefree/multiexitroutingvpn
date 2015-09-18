#!/bin/bash

. ../vars/./environment.sh

function isNumber()
{
    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]] ; then
       echo "error: Not a number" >&2; exit 1
    fi
}

function legitimize_host()
{
    isNumber $1
    if [[ `iptables -t mangle -L -vn | grep -c ${BASE}.$1` -eq 0 ]]
    then
        iptables -t mangle -I PREROUTING -s ${BASE}.$1 -j MARK --set-mark $MARK_CONST
    fi

}

function delegitimize_host()
{
    echo $1
    isNumber $1
    iptables -t mangle -D PREROUTING -s ${BASE}.$1 -j MARK --set-mark $MARK_CONST
}

function legitimize_uid()
{
    iptables -t mangle -A OUTPUT -m owner --uid-owner $1 -j MARK --set-mark $MARK_CONST
}

function legitimize_gid()
{
    iptables -t mangle -A OUTPUT -m owner --gid-owner $1 -j MARK --set-mark $MARK_CONST
}

function delegitimize_uid()
{
    iptables -t mangle -D OUTPUT -m owner --uid-owner $1 -j MARK --set-mark $MARK_CONST
}

function delegitimize_gid()
{
    iptables -t mangle -D OUTPUT -m owner --gid-owner $1 -j MARK --set-mark $MARK_CONST
}

function cycle()
{
    ./dudos.sh down
    ./dudos.sh up fast
}

function get_connections()
{
  /usr/sbin/conntrack -L
}

function legitimize_destination()
{
    iptables -t mangle -A PREROUTING -d $1 -j MARK --set-mark $MARK_CONST
}

function delegitimize_destination()
{
    iptables -t mangle -D PREROUTING -d $1 -j MARK --set-mark $MARK_CONST
}

case $1 in
    'legit-all') legitimize_host $2
    ;;
    'legit-port') legitimize_port $2 $3
    ;;
    'delegit-all') delegitimize_host $2
    ;;
    'delegit-port') delegitimize_port $2 $3
    ;;
    'legit-uid') legitimize_uid $2
    ;;
    'delegit-uid') delegitimize_uid $2
    ;;
    'legit-gid') legitimize_gid $2
    ;;
    'delegit-gid') delegitimize_gid $2
    ;;
    *) echo "usage: ./kabob.sh [legit-all|legit-port|delegit-all|delegit-port|cycle|legit-uid|legit-gid|deleigt-uid|delegit-gid|legit-dest|delegit-dest] [ip|protocol port|uid|gid|hostname]"
    ;;
esac
