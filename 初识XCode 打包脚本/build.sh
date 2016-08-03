#!/bin/sh

#############################
#
#   修改脚本参数
#
#############################

project_path= ./                            						   #项目文件的路径，将编译脚本放在项目目录中可以使用相对路径
adhoc_macro_setting='${inherited} ADHOC=1'             		           #adhoc模式下的宏定义
adhoc_profile="GSUser_AdHoc"                               	           #adhoc模式下使用的provision文件
development_macro_setting='${inherited} DEVELOPMENT=1'                 #develoment模式下的宏定义
develoment_profile="GSUser-Dev-Profile"                                #development模式下使用的provision文件
appstore_macro_setting='${inherited} APP_STORE=1'         			   #appstore模式下的宏定义
appstore_profile="GSUser-Pro-Profile"                                  #appstore模式下使用的provision文件

app_name="GasStation"                        					       #应用名字
scheme="GasStation"                       							   #工程文件中应用的scheme名字（一般和target名字相同）
workspace="GasStation.xcworkspace"             					       #工程文件的名字
configuration
configFileName
logFile=GSUserBuild.log
############################



#############################
#
#   根据证书名获取证书的UDID
#
#############################
get_provisioning_id()
{
    provisionpath="$HOME/Library/MobileDevice/Provisioning Profiles"
    provisions=$( ls "$provisionpath" )
    provisioningid=""
    for prv in $provisions
    do
        result=$(security cms -D -i "$provisionpath/$prv" | grep -i '<key>Name</key>' -A 2 | grep -i "<string>$1</string>")

        if [ "$result" != "" ]
        then
            provisioningid=${prv%%.*}
            echo "Found Provisioning Profile For $1 : "$prv
            break
        fi
    done

    if [ "$provisioningid" == "" ]
    then
        errormsg="$errormsg\n fail to find $1"
        echo "error NO Provisioning Profile For $1 was found~"

    fi
}



read -p "请输入打包类型（AdHoc或Develop或Productioin）" mode
 
if [ $mode = "a" ] ;  then
# 内测发布模式
echo "内测发布模式"
macro_setting="$adhoc_macro_setting"
profile="$adhoc_profile"
configuration="AdHoc"
configFileName="Config_GSUser_AdHoc.xcconfig"

elif [ $mode = "d" ] ; then
# 开发模式
echo "开发模式"
macro_setting="$development_macro_setting"
profile="$develoment_profile"
configuration="Debug"
configFileName="Config_GSUser_Debug.xcconfig"


elif [ $mode = "p" ] ; then
#APP STORE模式
    read -p "你是否确认已正确地修改了APP的版本号与Build Number?(y/n)" confirm
    if [ $confirm != "y" ] ;  then
        echo "请正确修改后重试"
        exit 1
    fi

macro_setting="$appstore_macro_setting"
profile="$appstore_profile"
configuration="Release"
configFileName="Config_GSUser_Release.xcconfig"

else
echo "模式无法识别！"
exit 1

fi

# 删除log 文件
rm  -f build.log
echo "remove build.log file"
 
rm  -f fir.log
echo "remove fir.log file"

cd "$project_path"

#删除之前的打包文件
export_path=GSUserExports
rm -rf $export_path
mkdir $export_path

#archive and export ipa
archive_path=$export_path/"$app_name".xcarchive
app_path=$export_path/"$app_name".ipa


get_provisioning_id "$profile"
PROVISIONING_PROFILE=$provisioningid


# 修改configFileName 下的Xcode 配置文件中的CUSTOM_PROVISIONING_PROFILE 的值为Provision 的UDID
 sed -i "" "s/^CUSTOM_PROVISIONING_PROFILE.*$/CUSTOM_PROVISIONING_PROFILE = $PROVISIONING_PROFILE/g"  Config/"$configFileName"


echo "workspace : $workspace" >> $logFile
echo "scheme : $scheme" >> $logFile
echo "configuration : $configuration" >> $logFile
echo "profile : $profile" >> $logFile
echo "profile UDID: $provisioningid" >> $logFile

echo "cleanning ....."
xcodebuild clean -workspace "$workspace" -scheme "$scheme" -configuration "$configuration"


# 执行大包
echo "building ....."
xcodebuild -scheme "$scheme" -configuration "$configuration" archive -archivePath $archive_path -workspace "$workspace" GCC_PREPROCESSOR_DEFINITIONS="${macro_setting}" >> $logFile

echo "Archive ....."
xcodebuild -exportArchive -exportFormat ipa -archivePath $archive_path -exportPath $app_path -exportProvisioningProfile $profile >> $logFile


#############################
#
#   发布到分发平台
#
#############################

# 发布到fir
echo "firing ....."
fir_user_key="f7ba0bfcc7e87cd0c59b0951f15d247b"
fir p $app_path -T "$fir_user_key"  >> $logFile

#发布到pre.im
pre_im_user_key="xxx"
curl -F "file=@${app_path}" -F "user_key=${pre_im_user_key}" -F "update_notify=1" -F "app_resign=1" http://pre.im/api/v1/app/upload >> $logFile

mv $logFile  $export_path
echo "Done! 😄😄😄😄😄😄😄😄😄😄😄😄😄😄😄😄"
# 发布到蒲公英
# uKey="xxxxx"
# apiKey="xxxx"
# password="xxxx"
# curl -F "file=@${app_path}" -F "uKey=${uKey}" -F "_api_key=${apiKey}" -F "publishRange=2" -F "password=${password}" http://www.pgyer.com/apiv1/app/upload