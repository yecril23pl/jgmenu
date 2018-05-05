#!/bin/sh

# 'jgmenu init' creates/updates jgmenurc

config_file=~/.config/jgmenu/jgmenurc
prepend_file=~/.config/jgmenu/prepend.csv

xdg_config_dirs="${XDG_CONFIG_HOME:-$HOME/.config} ${XDG_CONFIG_DIRS:-/etc/xdg}"
xdg_data_dirs="$XDG_DATA_HOME $HOME/.local/share $XDG_DATA_DIRS \
/usr/share /usr/local/share /opt/share"

theme=
verbose=f

regression_items="max_items min_items ignore_icon_cache color_noprog_fg \
color_title_bg show_title search_all_items ignore_xsettings arrow_show \
read_tint2rc tint2_rules tint2_button multi_window"

JGMENU_EXEC_DIR=$(jgmenu_run --exec-path)
. "${JGMENU_EXEC_DIR}"/jgmenu-init--prepend.sh

say () {
	printf "%b\n" "$@"
}

die () {
	printf "fatal: %b\n" "$@"
	exit 1
}

verbose_info () {
	test "$verbose" = "t" || return
	printf "info: %b\n" "$@"
}

usage () {
	say "\
usage: jgmenu init [<options>]\n\
Create/amend config files\n\
Options include:\n\
    --config-file=<file>  Specify config file\n\
    --theme=<theme>       Create config file with a particular theme\n\
    --list-themes         Display all available themes\n\
    --verbose             Be more verbose\n"
}

check_config_file () {
	if ! test -e ${config_file}
	then
		say "info: creating config file 'jgmenurc'"
		cp ${JGMENU_EXEC_DIR}/jgmenurc ${config_file}
	else
		jgmenu_run config amend --file "${config_file}"
	fi
}

# Check for jgmenurc items which are no longer valid
check_regression () {
	for r in ${regression_items}
	do
		if grep ${r} ${config_file} >/dev/null 2>&1
		then
			printf "%b\n" "warning: ${r} is no longer a valid key"
		fi
	done
}

check_menu_package_installed () {
	local menu_package_exists=
	for d in $xdg_config_dirs
	do
		if test -e $d/menus/*.menu
		then
			menu_package_exists=t
		fi
	done
	if test "$menu_package_exists" = "t"
	then
		verbose_info "menu package(s) exist"
	else
		say "warn: no menu package installed"
	fi
}

lx_installed () {
	test -e "${JGMENU_EXEC_DIR}"/jgmenu-lx
}

check_lx_installed () {
	if lx_installed
	then
		verbose_info "the lx module is installed"
	else
		say "warn: the lx module is not installed"
	fi
}

check_search_for_unicode_files () {
	for x in $xdg_data_dirs
	do
		test -d "${x}"/applications/ || continue
		if file -i "${x}"/applications/*.desktop \
			| grep -v 'utf-8\|ascii'
		then
			unicode_found=y
		fi
	done

	test "${unicode_found}" = "y" && say "\
warning: unicode files are not XDG compliant and may give unpredicted results"
}

icon_theme_last_used_by_jgmenu () {
	icon_theme=$(grep -i 'Inherits' ~/.cache/jgmenu/icons/index.theme)
	icon_size=$(grep -i 'Size' ~/.cache/jgmenu/icons/index.theme)
	printf "last time, icon-theme '%s-%s' was used\n" ${icon_theme#Inherits=} \
		${icon_size#Size=}
}

get_icon_theme () {
	for d in $xdg_data_dirs
	do
		test -d "${d}"/icons || continue
		ls -1 "${d}"/icons
	done | jgmenu --vsimple --no-spawn 2>/dev/null
}

print_available_themes () {
	ls -1 "${JGMENU_EXEC_DIR}"/jgmenurc.* 2>/dev/null | while read -r theme
	do
		printf "%b\n" ${theme#*.}
	done
}

get_theme () {
	ls -1 "${JGMENU_EXEC_DIR}"/jgmenurc.* 2>/dev/null | while read -r theme
	do
		printf "%b\n" ${theme#*.}
	done | jgmenu --vsimple --no-spawn 2>/dev/null
}

restart_jgmenu () {
	say "Restarting jgmenu..."
	killall jgmenu >/dev/null 2>&1
	nohup jgmenu >/dev/null 2>&1 &
}

set_theme () {
	test $# -eq 0 && die "set_theme(): no theme specified"
	filename="$(jgmenu_run --exec-path)"/jgmenurc."$1"
	test -e $filename || die "theme '$1' does not exist"
	cp -f $filename ~/.config/jgmenu/jgmenurc

	case "$1" in
	bunsenlabs*)
		. "${JGMENU_EXEC_DIR}"/jgmenu-init--bunsenlabs.sh
		setup_theme
		say "Theme '$1' has been set"
		restart_jgmenu
		;;
	neon)
		. "${JGMENU_EXEC_DIR}"/jgmenu-init--neon.sh
		setup_theme
		prepend_items
		say "Theme '$1' has been set"
		restart_jgmenu
		;;
	esac
}

restart_tint2 () {
	unset TINT2_BUTTON_ALIGNED_X1
	unset TINT2_BUTTON_ALIGNED_X2
	unset TINT2_BUTTON_ALIGNED_Y1
	unset TINT2_BUTTON_ALIGNED_Y2
	unset TINT2_BUTTON_PANEL_X1
	unset TINT2_BUTTON_PANEL_X2
	unset TINT2_BUTTON_PANEL_Y1
	unset TINT2_BUTTON_PANEL_Y2
	unset TINT2_CONFIG
	killall tint2 2>/dev/null
	if test -z $1
	then
		nohup tint2 >/dev/null 2>&1 &
	else
		nohup tint2 -c ${1} >/dev/null 2>&1 &
	fi
}

backup_jgmenurc () {
	mkdir -p ~/.config/jgmenu
	test -e ${config_file} && \
		cp -p ${config_file} ${config_file}.$(date +%Y%m%d%H%M)
	test -e ${prepend_file} && \
		cp -p ${prepend_file} ${prepend_file}.$(date +%Y%m%d%H%M)
}

analyse () {
	say "Check for obsolete config options..."
	check_regression
	say "Check installed menu packages..."
	check_menu_package_installed
	say "Check for lx module..."
	check_lx_installed
	say "Check for unicode files..."
	check_search_for_unicode_files
	return 0
}

initial_checks () {
	check_config_file
}

# NOT YET IMPLEMENTED:
#s, setup   = run through all options\n\
#i, icon    = set icon theme\n\
#x, xdg     = check xdg menu package is installed\n\
#u, undo    = revert back to previous set of config files\n\
#a, append  = add items at bottom of root-menu (e.g. lock and exit)\n\
#c, csv     = choose csv generator (i.e. the thing that produces the menu content)\n\
print_commands () {
	printf "%b" "\
*** commands ***\n\
a, analyse = run a number of jgmenu related checks on system\n\
t, theme   = create config files based on templates\n\
p, prepend = add items at top of root-menu (e.g. web browser and terminal)\n\
q, quit    = quit init process\n"
}

prompt () {
	local cmd=

	printf "%b" "What now> "
	read -r cmd
	case "$cmd" in
	analyse|a)
		analyse
		;;
	theme|t)
		set_theme $(get_theme)
		;;
	prepend|p)
		prepend_items
		;;
	quit|q)
		return 1
		;;
	help|h)
		print_commands
		;;
	clear)
		clear ;;
	'')
		;;
	*)
		echo "warn: '$cmd' is not a recognised command"
		print_commands
		;;
	esac
}

await_user_command () {
	print_commands
	while :
	do
		prompt || break
	done
}

while test $# != 0
do
	case "$1" in
	--config-file=*)
		config_file="${1#--config-file=}" ;;
	--theme=*)
		theme="${1#--theme=}" ;;
	--list-themes)
		print_available_themes
		exit 0
		;;
	--verbose)
		verbose=t ;;
	--help)
		usage
		exit 0
		;;
	*)
		printf "fatal: unknown option: '%s'\n" $1
		usage
		exit 1
		;;
	esac
	shift
done

backup_jgmenurc
test -z ${theme} || { set_theme $theme ; exit 0 ; }
initial_checks
await_user_command
