#!/bin/bash

. vars/./environment.sh

# get all tunnel interfaces
function get_interfaces 
{
    interfaces=`$ifconfig | grep tun | awk '{print $1}'`
}

# delete all default routes
function clean_routes 
{
    get_interfaces

    for ifs in $interfaces
    do
        $ip route del 0.0.0.0/1 dev $ifs 2>/dev/null
	    delete_gw=`$ip route | grep '128.0.0.0/1' | grep "dev $ifs"`
        if [[ $delete_gw != '' ]]
        then
            $ip route del $delete_gw
        fi
    done
}

# open openvpn connections
function open_connections
{
    tun=0
    for group in `ls $CONFIG_DIR/vpns/`
    do
        if [[ -d $CONFIG_DIR/vpns/$group ]]
        then
            limit=`cat $CONFIG_DIR/vpns/$group/group_settings | grep limit | awk '{print $2}'`
            if [[ $limit == "" ]]
            then
                limit=`ls $CONFIG_DIR/vpns/$group/*.ovpn | grep -c ovpn`
            fi
            ltun=1
            for vpn in `ls $CONFIG_DIR/vpns/$group/*.ovpn | sort --random-sort`
                do
                if [[ $ltun -le $limit ]]
                then
                    echo -n "Connecting to $vpn (expecting interface tun$tun) [ $ltun / $limit ]"
		            $(cd $CONFIG_DIR/vpns/$group/; $openvpn --dev tun${tun} ${PERSIST_OPTS} --config $vpn > "$LOG_DIR/${vpn//$CONFIG_DIR\/vpns\/$group\//_log_}" &)
                    timeout=0
                    while [[ `$ip route | grep -c tun${tun}` -lt 2 && $timeout -lt $TIMEOUT_VALUE ]]
                    do
                        echo -n "."
                        sleep 1
                        timeout=`expr $timeout + 1`
                    done
                    echo ""
                    if [[ $timeout -ge $TIMEOUT_VALUE ]]
                    then
                        pid=`ps aux | grep "openvpn --dev tun${tun} ${PERSIST_OPTS} --config $vpn" | grep -v "grep" | awk '{print $2}'`
                        echo "Timeout! killing process {$pid}"
                        kill -9 $pid
                    else
                        tun=`expr $tun + 1`
                        ltun=`expr $ltun + 1`
                    fi
                    sleep 2
                    clean_routes
                fi
            done
        fi
    done
    clean_routes 
}


# setup simple balanced gateways
function setup_gateways_simple
{
    $iptables -t nat -F POSTROUTING
    for ifs in $interfaces
    do
	defaultGW=`echo "$defaultGW nexthop dev $ifs weight 1 "`
        $iptables -t nat -A POSTROUTING -o $ifs -j MASQUERADE
    done
}

# tests speed of the tunnels and sorts them by throughput
function setup_gateways_fast()
{
    if [[ $1 -ne 'cache' ]]
    then
	    rm .weight_cache
    fi
    $iptables -t nat -F POSTROUTING

    touch .speeds

    for ifs in $interfaces
    do
        $iptables -t nat -A POSTROUTING -o $ifs -j MASQUERADE
        echo "Testing speed of interface $ifs"
        $ip route del default 2>/dev/null
        $ip route add default dev $ifs
	    $ip route flush cache
        ping ${PING_HOST} -c 1 > /dev/null

        if [[ $? != 0 ]]
        then
    	    echo "Tunnel $ifs failure (no ping). Will not be included in gateway list."
        else
            download=`curl -s -k -o /dev/null -w %{speed_download} ${DOWNLOAD_TEST_FILE} | sed 's/,/./g' | xargs printf "%.*f" 0`
            echo "$ifs|$download" >> .speeds
	    fi

	    $ip route del default dev $ifs
    done

    top=`cat .speeds | sed 's/|/\ /g' | awk '{print $2}' | sort -r | head -n 1`
    for result in `cat .speeds`
    do
        result=`echo $result | sed 's/|/\ /g'`
        interface=`echo $result | awk '{print $1}'`
        speed=`echo $result | awk '{print $2}'`
        weight=`echo "scale=0; ($speed * 100) / $top" | bc -l`
        weight=`expr $weight + 1`
        if [[ $weight -gt 254 ]]
        then
            weight=254 #cap.
        fi
        echo "$interface weight: $weight (higher is better)"
        defaultGW=`echo "$defaultGW nexthop dev $interface weight $weight "`
    done

    rm .speeds
}

#makes some noise on your free time
function noisemaker
{
    
    echo "Not implemented yet (noisemaker)"
    exit 200
}

# does table exist?
function table_exists()
{
    count=`cat /etc/iproute2/rt_tables | grep -c $1`
    if [[ $count -lt 1 ]] 
    then
	newid=`expr \`cat /etc/iproute2/rt_tables | awk '{print $1}' | sort | grep -vE ^25.$ | grep -v '#' | tail -n 1\` + 1`
	if [[ $newid < 250 ]]
	then
	    echo "$newid $1" >> /etc/iproute2/rt_tables
	else
	    echo "Your routing tables are too full. See /etc/iproute2/rt_tables."
	    exit 255
	fi
    fi
}

# copy routes to table
function copy_route()
{
    FROM=$1
    TO=$2
    table_exists $TO
    $ip route flush table $TO
    $ip route show table $FROM | sort | while read ROUTE
    do 
	$ip route add table $TO $ROUTE
    done
}

function iptables_setup
{
    $iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

    $iptables -t mangle -F
    for dest in `cat $CONFIG_DIR/legit_destinations`
    do
        $iptables -t mangle -A PREROUTING -d $dest -j MARK --set-mark $MARK_CONST
    done

    for uid in `cat $CONFIG_DIR/legit_uids`
    do
	$iptables -t mangle -A OUTPUT -m owner --uid-owner $uid -j MARK --set-mark $MARK_CONST
    done

    for gid in `cat $CONFIG_DIR/legit_gids`
    do
        $iptables -t mangle -A OUTPUT -m owner --gid-owner $gid -j MARK --set-mark $MARK_CONST
    done
    
    for pair in `cat $CONFIG_DIR/legit_local_ports`
    do
	$iptables -t mangle -A INPUT -p ${pair%:*} --dport ${pair#*:} -j MARK --set-mark $MARK_CONST
	$iptables -t mangle -A OUTPUT -p ${pair%:*} --sport ${pair#*:} -j MARK --set-mark $MARK_CONST
    done
}

function up()
{
    ping $PING_HOST -c 1 > /dev/null
    if [[ $? != 0 ]]
    then
        service networking restart
    fi
    copy_route main legit

    open_connections

    clean_routes

    $ip route del default
    
    if [[ $1 != 'fast-nocache' ]]
    then
	if [[ $1 != 'fast' ]]
	then
	    setup_gateways_simple
	else
	    setup_gateways_fast
	fi
    else
	setup_gateways_fast # cache would be nice, eh?
    fi
    $ip route del default 2>/dev/null

    copy_route main outerfaces
    $ip route add table outerfaces default scope global $defaultGW
    $ip rule del lookup outerfaces 2>/dev/null
    $ip rule add lookup outerfaces
    $ip rule del fwmark $MARK_CONST table legit 2>/dev/null
    $ip rule add fwmark $MARK_CONST table legit
    
    iptables_setup

    if [[ $2 == 'noisemaker' ]]
    then
	noisemaker
    fi
}

function down
{
    killall openvpn
    copy_route legit main
#    copy_route main default
    $ip rule del lookup outerfaces
    $ip route flush table legit
    $iptables -t mangle -F # TODO: SAVE PREV RULES
#    iptables -t nat -F 	  # SAME TODO
}

function cycle()
{
    down;
    up fast;
}

function heartbeat()
{
  openvpns=`ps ax | grep -v grep | grep -c openvpn`
    if [[ $openvpns -le 1 ]]
    then
        cycle
        exit 0
    fi

    ping -c 1 $PING_HOST > /dev/null
    if [[ $? -ne 0 ]]
    then 
        cycle
        exit 0
    fi
}

# main function
function main()
{
    if [[ $1 == 'up' ]]
    then
        up "$2" "$3"
	exit 0
    fi
    if [[ $1 == 'down' ]]
    then
        down
        exit 0
    fi
    if [[ $1 == 'heartbeat' ]]
    then
        heartbeat
        exit 0
    fi
    if [[ $1 == 'cycle' ]]
    then
        cycle
        exit 0
    fi
    if [[ $1 == 'watchdog' ]]
    then
	while true
	do
	    heartbeat
	    sleep 30
	done
	exit 0
    fi
    echo "Usage: ./mevr.sh up [fast|fast-nocache] [noisemaker]|down|heartbeat|cycle|watchdog"
    exit 254
}

# run.
main $1 $2 $3
