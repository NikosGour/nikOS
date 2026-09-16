#!/bin/env bash

color_reset="\033[0m"
color_red="\033[31m"
color_green="\033[32m"
color_yellow="\033[33m"
color_blue="\033[34m"
color_cyan="\033[36m"
color_magenta="\033[35m"

usage() {
	printf "Usage: $0 [windows][run][release][clean] \n\n\twindows:  build for windows, leave empty for building for linux. If you are compiling for windows make sure to change the windows_user variable in this script\n\trun:      run the built file after building\n\trelease:  build with release flags\n\tclean:    clean the output directory\n"
	exit 1
}

log_info() {
	printf "${color_cyan}$1${color_reset}\n"
}

log_error() {
	printf "${color_red}$1${color_reset}\n"
}

log_success() {
	printf "${color_green}$1${color_reset}\n"
}

print_run() {
	printf "${color_yellow}$*${color_reset}\n"
	"$@"
}


project_name="nikOS"
project_dir=$(realpath $(dirname $0))
out_dir="out"
out_name="$project_name"
linker_flags=""
tags="-tags=static,debug"

echo "Project Directory: $project_dir"
cd $project_dir

# If you are using windows, set the windows username bellow. As it appear under "C:/Users/XXX"
windows_user="ngkil"

windows_flag=false
release_flag=false
clean_flag=false
run_flag=false
app_choice="cli"

# get parameters and set the flags

while [ "$1" != "" ]; do
	case $1 in
	windows)
		windows_flag=true
		;;
	release)
		release_flag=true
		;;
	clean)
		clean_flag=true
		;;
	run)
		run_flag=true
		;;
	# cli)
	# 	app_choice="cli"
	# 	;;
	# gui)
	# 	app_choice="gui"
	# 	;;
	*)
		usage
		;;
	esac
	shift
done

release_flag_setup() {
	out_name="$out_name-release"
	linker_flags="$linker_flags -s -w"
	tags="-tags= "
	if [ "$windows_flag" == "true" ]; then
		linker_flags="$linker_flags -H windowsgui"
	fi
}

add_os_tag() {
	if [ "$windows_flag" == "true" ]; then
		if [ "$release_flag" == "true" ]; then
			tags="-tags=windows_os"
		else
			tags="$tags,windows_os"
		fi
	else
		if [ "$release_flag" == "true" ]; then
			tags="-tags=linux_os"
		else
			tags="$tags,linux_os"
		fi
	fi
}

build_out_dir(){
	out_name=$app_choice'_'$out_name
	if [ "$windows_flag" == "true" ]; then
		out_dir="/mnt/c/Users/$windows_user/Desktop/go_projects/$project_name"
		out_name="$out_name.exe"
	else
		out_dir="$project_dir/$out_dir"
	fi
	log_info "Output Directory: $out_dir"
}

clean_previous_file() {
	if [ "$clean_flag" == "true" ]; then
		log_info "Cleaning previous file"
		print_run rm $out_dir/$out_name 2>/dev/null
	fi
}

set_env_vars() {
	if [ "$windows_flag" == "true" ]; then
		export CC=x86_64-w64-mingw32-gcc
		export GOOS=windows
	else
		export GOOS=linux
	fi

	export GOARCH=amd64

	# CGO env vars + example of libs
	# export CGO_ENABLED=1
	# export CGO_CFLAGS="-I$(pwd)/libs/x86_64-w64-mingw32/include"
	# export CGO_LDFLAGS="-L$(pwd)/libs/x86_64-w64-mingw32/lib -lSDL2 -static"

	echo "---------------------------------"
	log_info "Variables:"
	echo "---------------------------------"
	echo "Output Name: $out_name"
	echo "Linker Flags: $linker_flags"
	echo "Tags: $tags"
	echo "CGO_ENABLED: $CGO_ENABLED"
	echo "CC: $CC"
	echo "CGO_CFLAGS: $CGO_CFLAGS"
	echo "CGO_LDFLAGS: $CGO_LDFLAGS"
	echo "GOOS: $GOOS"
	echo "GOARCH: $GOARCH"
	echo "---------------------------------"
}

go_list(){
	log_info "Files to build:"
 	print_run go list -f '{{.GoFiles}}' $tags ./...
}

go_build(){
	error_output=$(print_run go build -ldflags "$linker_flags" -gcflags "all=-N -l" -o $out_dir/$out_name $tags ./cmd/$app_choice 2>&1 1>/dev/tty)

	if [ $? -ne 0 ]; then
		log_error "Build failed with error:"
		echo "----------------------------------"
		echo "$error_output"
		exit 1
	else
		log_success "Build succeeded"
	fi

}

post_build(){
	if [ "$windows_flag" == "true" ]; then
		log_info "Creating debug script for windows"
		if [ "$release_flag" == "false" ]; then
			printf "$out_name\npause\n" >$out_dir/debug_run.bat
		fi
	else
		#Linux post build
		:
	fi

	log_success "Done Building"
	echo "---------------------------------"
}

run_project() {
	log_info "Running the built file"
	if [ "$windows_flag" == "true" ]; then
		print_run powershell.exe -command "C:/Users/$windows_user/Desktop/go_projects/$project_name/$out_name"
	else
		print_run $out_dir/$out_name
	fi
}

#######################
if [ "$release_flag" == "true" ]; then
	release_flag_setup
fi

add_os_tag

build_out_dir

if [ ! -d "$out_dir" ]; then
	log_info "Creating output directory: $out_dir"
	print_run mkdir -p $out_dir
fi

clean_previous_file

set_env_vars

go_list

go_build

post_build

if [ "$run_flag" == "true" ]; then
	run_project
fi
##################
