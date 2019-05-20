#!/bin/bash

#*****************************************************************************************
#用例名称：NIC_BASIC_Negotiation_003
#用例功能：GE电口关闭自协商后重新自协商功能
#作者：hwx653129
#完成时间：2019-1-29

#前置条件：
# 	1.单板启动正常
# 	2.所有GE电口各模块加载正常

#测试步骤：
# 	1.网口正常初始化后，使用ethtool命令先关闭自协商ethtool -s 网口 autoneg off，
#	再分别设置为10M 半双工、10M 全双工、100M 半双工、100M 全双工，命令执行成功。
#	命令参照：10M半双工/全双工命令：ethtool -s 网口 speed 10 duplex half/full
# 	2.ping对端成功
# 	3.输入重新自协商命令：ethtool -r 网口，ping对端

#测试结果:
# 	重新自协商命令执行失败，ping包成功                                             
#*****************************************************************************************

#加载公共函数,具体看环境对应的位置修改
#. ./utils/test_case_common.inc
#. ./utils/error_code.inc
. ../../../../../utils/error_code.inc
. ../../../../../utils/test_case_common.inc
. ../../../../../utils/sys_info.sh
. ../../../../../utils/sh-test-lib
. ../../../../../utils/env_parameter.inc     
 
#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPFILE=${TMPDIR}/${test_name}.tmp
#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result

#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"
test_result="pass"



#************************************************************#
# Name        : distinguish_card                               #
# Description : 区分板载和标卡                               #
# Parameters  : 无
# return value：onboard_fibre_card[]   onboard_tp_card[]  standard_card[]              #
#************************************************************#
function distinguish_card(){
   fn_get_physical_network_card total_network_cards
   total_network_cards=(`echo ${total_network_cards[@]}`)
   
   for ((i=0;i<${#total_network_cards[@]};i++))
    do
        driver=`ethtool -i ${total_network_cards[i]} | grep driver | awk '{print $2}'`
        if [ "$driver" == "hns" -o "$driver" == "hns3" ];then
			port=`ethtool ${total_network_cards[i]} | grep "Port:"| awk '{print $2}'`
			if [ "$port" == "FIBRE" ];then
				onboard_fibre_card[i]=${total_network_cards[i]}
				onboard_fibre_card=(`echo ${onboard_fibre_card[@]}`)
			elif [ "$port" == "MII" ];then
				onboard_tp_card[i]=${total_network_cards[i]}
				onboard_tp_card=(`echo ${onboard_tp_card[@]}`)
			fi
        else
            standard_card[i]=${total_network_cards[i]}
            standard_card=(`echo ${standard_card[@]}`)
        fi
    done
}


#************************************************************#
# Name        : verify_connect                               #
# Description : 确认网络连接                               #
# Parameters  : $1=网口
# return value：无              #
#************************************************************#
function verify_connect(){
	network=$1
	IP_table=`cat ../../../../../utils/env_parameter.inc`

	debug=false
	if [ $debug = true ];then
	cat << EOF > IP_table.txt
	client_ip_10=192.168.1.3
	client_ip_20=192.168.10.3
	client_ip_30=192.168.20.3
	client_ip_40=192.168.30.3
	#client_ip_50=192.168.50.11
	
	server_ip_10=192.168.1.6
	server_ip_20=192.168.10.6
	server_ip_30=192.168.20.6
	server_ip_40=192.168.30.6
	#server_ip_50=192.168.50.12
EOF
		IP_table=`cat IP_table.txt`
	fi
	
	local_ip=`ip address show $network |  grep -w inet | awk -F'[ /]+' '{print $3}'`
	remote_ip=`echo $IP_table | sed 's/ /\n/g' | grep -w ${local_ip%.*} | grep -v $local_ip | awk -F = '{print $2}'`
	echo $remote_ip
	ping $remote_ip -c 5
	if [ $? -eq 0 ]
	then 
		PRINT_LOG "INFO" "$remote_ip connect properly."
		fn_writeResultFile "${RESULT_FILE}" "${remote_ip}_connect" "pass"
	else
		PRINT_LOG "FATAL" "$remote_ip connect is not normal."
		fn_writeResultFile "${RESULT_FILE}" "${remote_ip}_connect" "fail"
		ip a
		echo "ping test"
		ping $remote_ip -c 5
		return 1
	fi
	sleep 5
}

#************************************************************#
# Name        : negotiate_test                        #
# Description : 网口自适应测试                                 #
# Parameters  : 无     
# return	  : 无                                      #
#************************************************************#
function negotiate_test(){
	device=$1
	ethtool -r $net
	if [ $? -eq 0 ]
	then
		PRINT_LOG "FATAL" "$device set autoneg command successful, please check it."
		fn_writeResultFile "${RESULT_FILE}" "${device}_negotiate" "fail"
		return 1
	else
		PRINT_LOG "INFO" "$device can't restart autoneg."
		fn_writeResultFile "${RESULT_FILE}" "${device}_negotiate" "pass"
	fi
}

#************************************************************#
# Name        : test_speed_duplex                        #
# Description : 更改速率和双工模式测试                                 #
# Parameters  : 无     
# return	  : 无                                      #
#************************************************************#
function test_speed_duplex(){
	device=$1
	speed=$2
	duplex=$3
#	ethtool -s enp125s0f2 speed 10 duplex half
#	ethtool -s enp125s0f2 speed 10 duplex full
#	ethtool -s enp125s0f2 speed 100 duplex half
#	ethtool -s enp125s0f2 speed 100 duplex full	
#	ethtool -s enp125s0f2 speed 1000 duplex half
#	ethtool -s enp125s0f2 speed 1000 duplex full	
	ethtool -s $device speed $speed duplex $duplex
	sleep 5
	ethtool $device | grep "Advertised link modes" | grep $speed | grep -i $duplex
	if [ $? -eq 0 ]
	then
		PRINT_LOG "INFO" "$device it can set up network format, speed is $speed, duplex is $duplex."
		fn_writeResultFile "${RESULT_FILE}" "${device}_${speed}_${duplex}" "pass"
	else
		PRINT_LOG "FATAL" "$device it can not set up network format, please check it."
		PRINT_LOG "INFO" "exec<ethtool -s $device speed $speed duplex $duplex>"
		fn_writeResultFile "${RESULT_FILE}" "${device}_${speed}_${duplex}" "fail"
		return 1
	fi
}

#预置条件
function init_env()
{
    #检查结果文件是否存在，创建结果文件：
    fn_checkResultFile ${RESULT_FILE}
    
    #root用户执行
    if [ `whoami` != 'root' ]
    then
        PRINT_LOG "WARN" " You must be root user " 
        return 1
    fi
	sshpass -h || fn_install_pkg "sshpass" 10
	ethtool -h || fn_install_pkg "ethtool" 10
	distinguish_card
	
	for net in ${onboard_tp_card[@]}
	do
		ethtool -s $net autoneg off
		ethtool -a $net
		sleep 5
	done

    #自定义测试预置条件检查实现部分：比如工具安装，检查多机互联情况，执行用户身份 
      #需要安装工具，使用公共函数install_deps，用法：install_deps "${pkgs}"
      #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
}

#测试执行
function test_case()
{
	for net in ${onboard_tp_card[@]}
	do
		test_speed_duplex $net 10 half
		test_speed_duplex $net 10 full
		test_speed_duplex $net 100 half
		test_speed_duplex $net 100 full
		#test_speed_duplex $net 1000 half
		test_speed_duplex $net 1000 full
		verify_connect $net
		negotiate_test $net
		verify_connect $net
	done	
	
	
    #检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
    check_result ${RESULT_FILE}
}

#恢复环境
function clean_env()
{
    #清除临时文件
    FUNC_CLEAN_TMP_FILE
    #自定义环境恢复实现部分,工具安装不建议恢复
      #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	for net in ${onboard_tp_card[@]}
	do
		ethtool -s $net autoneg on
		sleep 5
		ethtool -a $net
		ip link set dev $net up
		sleep 2
		ip a show $net
	done
}


function main()
{
    init_env || test_result="fail"
    if [ ${test_result} = 'pass' ]
    then
        test_case || test_result="fail"
    fi
    clean_env || test_result="fail"
	[ "${test_result}" = "pass" ] || return 1
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}