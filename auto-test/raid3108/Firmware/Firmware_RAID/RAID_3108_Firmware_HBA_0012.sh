#!/bin/bash

#*****************************************************************************************
# *用例名称：RAID_3108_Firmware_HBA_0012                                                        
# *用例功能：测试LSI SAS3108是否可以支持透传SMART命令并查询SATA硬盘SMART状态。                                         
# *作者：fwx654472                                                                       
# *完成时间：2019-1-21                                                                   
# *前置条件：                                                                            
#   1、服务器1台，配置LSI SAS3108卡
#   2、1块正常硬盘，将slot0槽位硬盘创建RAID0（Write Policy设置成WB模式），安装Linux OS，安装过程将硬盘分为系统和非系统分区；1块正常SATA硬盘，接入slot1
#   3、3108管理软件storcli
#   4、smartctl软件（一般系统自带）
#   5、设置串口重定向监控RAID卡
# *测试步骤：                                                                               
#   1、给服务器上电进入OS
#   2、使能RAID卡JBOD，并将slot1的SATA硬盘设置为JBOD盘
#       (1)使能RAID卡JBOD
#       ./storcli64 /c0 set jbod=on
#       (2)设置slot1硬盘为JBOD盘
#       ./storcli64 /c0/e9/s1 set jbod
#   3、用smartctl软件查询slot1硬盘基本信息，预期结果A
#       (1)smartctl软件查询命令（设slot1硬盘对应OS中设备为/dev/sdb）
#       smartctl -i /dev/sdb
# *测试结果：                                                                            
#   A：可以查询到SATA硬盘基本信息如型号、序列号、容量等信息
#*****************************************************************************************

#加载公共函数
. ../../../../utils/error_code.inc
. ../../../../utils/test_case_common.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib     
#. ./error_code.inc
#. ./test_case_common.inc

#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPFILE=${TMPDIR}/${test_name}.tmp
#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result
TMPCFG=${TMPDIR}/${test_name}.tmp_cfg
test_result="pass"


#预置条件
function init_env()
{
    #检查结果文件是否存在，创建结果文件：
    PRINT_LOG "INFO" "*************************start to run test case<${test_name}>**********************************"
    fn_checkResultFile ${RESULT_FILE}
    fio -h || fn_install_pkg smartctl 3
    cp ../../../utils/tools/storcli64 ./. || PRINT_LOG "INFO" "cp storiclib is fail"
    chmod 777 storcli64
}



#测试执行
function test_case()
{
    #测试步骤实现部分

    ./storcli64 /c0 set jbod=on 
    if [ $? -eq 0 ]
    then
        PRINT_LOG "INFO" "torcli64 /c0 set spinupdelay=20 is success."
    else
        PRINT_LOG "INFO" "torcli64 /c0 set spinupdelay=20 is fail."
    fi

    ./storcli64 /c0/e9/s1 set jbod
    if [ $? -eq 0 ]
    then
        PRINT_LOG "INFO" "storcli64 /c0 set spinupdrivecount=4 is success."
    else
        PRINT_LOG "INFO" "storcli64 /c0 set spinupdrivecount=4 is fail."
    fi


    smartctl -i /dev/sdb
    if [ $? -eq 0 ]
    then
        PRINT_LOG "INFO" "Exec<smartctl -i /dev/sdb> is success."
        fn_writeResultFile "${RESULT_FILE}" "smartctl" "pass"
        
    else
        PRINT_LOG "INFO" "Exec<smartctl -i /dev/sdb> is fail."
        fn_writeResultFile "${RESULT_FILE}" "smartctl" "fail"
    fi



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
    PRINT_LOG "INFO" "*************************end of running test case<${test_name}>**********************************"
}


function main()
{
    init_env || test_result="fail"
    if [ ${test_result} = "pass" ]
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



