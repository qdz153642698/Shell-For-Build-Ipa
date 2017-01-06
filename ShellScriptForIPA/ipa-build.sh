#为保护公司相关信息，项目名称使用PROJECTNAME代替、用户名邮箱使用userName@163.com代替，firimApiToken使用123456代替
#本文作者：亓大志
#gitHub：qdz153642698
#gitHub地址：https://github.com/qdz153642698

#!/bin/bash
function getAppProfileUUID(){  #筛选本地相匹配的Provisioning Profiles，获取该配置文件的UUID
	currentPath=`pwd`
	cd $HOME/Library/MobileDevice/Provisioning\ Profiles
	for line in $(ls); do
         security cms -D -i $line >/tmp/tmp.plist 2>/dev/null    #将mobileprovision文件解析到tmp/tmp.list
         name=`/usr/libexec/plistBuddy -c "print Name" /tmp/tmp.plist`  #输出tmp.list中的Name，并赋值给name
		 if [[ $1 == "adhoc" ]]; then
		 	if [[ $name == $adhocDistributionProfileName ]]; then
		 		echo `/usr/libexec/plistBuddy -c "print UUID" /tmp/tmp.plist`   #输出tmp.list中的UUID，并返回该值
		 		break
		 	fi
		 else
		 	if [[ $name == $appStoreDistributionProfileName ]]; then
			 	echo `/usr/libexec/plistBuddy -c "print UUID" /tmp/tmp.plist`
			 	break
			 fi
		 fi	 
	done
	cd $currentPath
}

function savaArchiveFile(){   #已经理解用法，Go on baby
	currentPath=`pwd`
    dateString=`date +%Y-%m-%d`   #获取当前时间
	archivePath="$HOME/Library/Developer/Xcode/Archives"
	cd $archivePath
    if [[ ! -e $dateString ]]; then   #判断当前目录下有没有名称为 $dateString 的文件夹
		mkdir $dateString             #如果不存在这个文件件， 创建
	fi
	cd $currentPath
    cp -R ${buildResultPath}/${projectName}.app.dSYM $archivePath/$dateString/${projectName}_$1_$2.app.dSYM    #复制文件 （目录A） -> （目录B）
}

#  ag -g "${projectName}.xcodeproj" | head -1  :  查询projectName.xcodeProj 下面的所有文件路径，取出第一条
#  ag -g "${projectName}.xcodeproj" | head -1 |sed "s/${projectName}.xcodeproj\/project.pbxproj//g"  ： 上面取出第一条之后（projectName.xcodeproj/project.pbxproj）,然后替换掉此路径为空
function getInfoPlistPath(){  #理解， Go on baby
	searchXcodeprojPath=`ag -g "${projectName}.xcodeproj" | head -1 |sed "s/${projectName}.xcodeproj\/project.pbxproj//g"`
	if [[ $searchXcodeprojPath == '' ]]; then
		infoPlistName=`ls $projectName| grep 'Info.plist'`
		echo $projectName/$infoPlistName
	else
		 infoPlistName=`ls ${searchXcodeprojPath}${projectName} | grep 'Info.plist'`
		 echo ${searchXcodeprojPath}$projectName/$infoPlistName
	fi
}
set -e   #
IFS=$(echo -en "\n\b")
firimApiToken='123456'      #Fir API Token
adhocDistributionProfileName='newuseAppAdHocDistribution'  #测试包  profile名
appStoreDistributionProfileName='newuserDistribution'      #App store线上包 profile名
projectName='PROJECTNAME' #工程名称
workspaceName=''       #工作空间名称
username='userName@163.com'  #账号

#password :
#security find-generic-password -gs applicationLoader 2>&1 >/dev/null (从钥匙串中读取名称为applocationLoader的钥匙串的密码，并将错误信息重定向到输出路径，输出信息重定向到垃圾箱)
#sed 's/ //g' ： 替换（删除）空格
#sed 's/\"//g' ：替换（删除）引号
#cut -f2 -d ':' 按照：分割，取出第2部分
password=`security find-generic-password  -gs applicationLoader 2>&1 >/dev/null | sed 's/ //g'|sed 's/\"//g'| cut -f2 -d ':'`  #密码

altool='/Applications/Xcode.app/Contents/Applications/Application Loader.app/Contents/Frameworks/ITunesSoftwareService.framework/Support/altool'  #上传工具地址（命令行地址）
distDir="compiler/package" #构建ipa完成的文件夹路径
currentDir=`pwd`        #当前文件路径
projectInfoPlistPath=$(getInfoPlistPath)  #获取项目中的info.plist文件的路径
version=`/usr/libexec/plistBuddy -c "print CFBundleShortVersionString" $projectInfoPlistPath`  #从info.plist文件中获取CFBundleShortVersionString信息
buildNumber=`/usr/libexec/plistBuddy -c "print CFBundleVersion" $projectInfoPlistPath`  #从info.plist文件中获取CFBundleVersion信息
buildLogPath="compiler/logs/build-log.txt"      #构建ipa文件的log日志路径
uploadLogPath="compiler/logs/upload-log.txt"    #上传ipa文件的log日志路径

#如果  构建ipa完成的文件夹 存在，则进入，删除里面的所有元素（ipa文件）
if [[ -e $distDir ]]; then
	cd $distDir
	rm -rf *
	cd $currentDir
fi

#buildPath 和 buildResultPath 是构建的 相对路径，
if [[ $workspaceName == '' ]]; then
	buildPath='build'
	buildResultPath='build'
else
	buildPath="${currentDir}/build"
	buildResultPath="${currentDir}/build/Release-iphoneos"
fi

#targetName : 打包好的ipa文件名
#appProfileUUID ： 发布证书的配置文件Provisioning Profiles 的UUID
if [[ $# == 0 ]]; then
	targetName=`echo ${projectName}_adhoc_${version}_build_${buildNumber}`
	appProfileUUID=$(getAppProfileUUID adhoc)
else 
	targetName=`echo ${projectName}_appStore_${version}_build_${buildNumber}`
	appProfileUUID=$(getAppProfileUUID appStore)
fi

#如果获取不到Provisioning Profiles的UUID，提示去下载该Provisioning Profiles
if [[ $appProfileUUID == "" ]]; then
	if [[ $# == 0 ]]; then
		echo "Error: Please download $adhocDistributionProfileName profile"
	else
		echo "Error: Please download $appStoreDistributionProfileName profile"
	fi
	exit 
fi

#拉取最新代码
echo "git pull origin master"
git pull origin master

#先清理工程，会在目录下面生成build文件夹，也会生成子文件夹，但是没有相关文件，  （clean ：清理编译过程中生成的所有文件.app、.app.dSYM等文件，，但是保留文件夹）
echo "cleaning project"
if [[ $workspaceName == '' ]]; then
	xcodebuild -target $projectName clean >$buildLogPath
else
	xcodebuild -workspace ${workspaceName}.xcworkspace  -scheme $workspaceName clean  >$buildLogPath
fi

#编译工程     CONFIGURATION_BUILD_DIR=$buildPath，  指定编译生成的app文件目录，如果不指定会在build/Release-iphoneos文件夹下面
echo "building....."
if [[ $workspaceName == '' ]]; then
	xcodebuild -project ${projectName}.xcodeproj -target $projectName -sdk iphoneos  -configuration "Release" CODE_SIGN_IDENTITY="我是可爱的替代码，好吧，我是汉字" PROVISIONING_PROFILE_SPECIFIER=$appProfileUUID CONFIGURATION_BUILD_DIR=$buildPath  >>$buildLogPath
else
	xcodebuild -workspace ${workspaceName}.xcworkspace  -scheme $workspaceName -sdk iphoneos  -configuration "Release" CODE_SIGN_IDENTITY="我是可爱的替代码，好吧，我是汉字" PROVISIONING_PROFILE_SPECIFIER=$appProfileUUID SYMROOT=$buildPath >>$buildLogPath
fi

#生成ipa文件，现在已经不推荐使用PackageApplication,  使用exportArchive替代
xcrun -sdk iphoneos PackageApplication -v "${buildResultPath}/${projectName}.app" -o "/tmp/${targetName}.ipa" >>$buildLogPath
mv /tmp/${targetName}.ipa $distDir
echo "build success: $distDir/${targetName}.ipa"

#上传包到appStore   或者  提交到fir(需要安装fir工具，申请API Token)
if [[ $# > 0 ]]; then
	# AppStore上线包保存原始的archive文件，umeng crash 分析用
	savaArchiveFile $version $buildNumber
	echo "start upload to itunesconnect......"
    $altool -v -f $distDir/$targetName.ipa -u $username -p $password >$uploadLogPath      #验证ipa文件    -v  (可以使用--validate替代)
	$altool --upload-app -f $distDir/$targetName.ipa -u $username -p $password >> $uploadLogPath  #上传ipa文件
	echo "upload ipa success!"
else
	echo "upload to fir.im......."
	# cat compiler/change.txt | mutt qa@163.com   -s "iOS客户端_${version}_build_${buildNumber}提测"  -a  $distDir/$targetName.ipa
	fir publish $distDir/$targetName.ipa -T $firimApiToken  --changelog='compiler/change.txt'
	echo "upload success!"
fi
rm -rf build 


