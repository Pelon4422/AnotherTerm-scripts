#!/system/bin/sh

# Different linux rootfs archives from linuxcontainers.org install script.

set -e

if [ -z "$1" -o -z "$2" ]
then
echo 'Usage:'
echo "	$0 <distro> <release> [<target_subdir_name>]"
exit 1
fi

DISTRO="$1"
RELEASE="$2"
NAME="$3"
REGULAR_USER_NAME='my_acct'
SHELL='bash'

exit_with() {
echo $* >&2
exit 1
}

prompt() {
echo -n "$1 [$2]: "
read V
echo "${V:-"$2"}"
}

to_uname_arch() {
case "$1" in
armeabi-v7a)
echo armv7a
;;
arm64-v8a)
echo aarch64
;;
x86)
echo i686
;;
x86_64)
echo amd64
;;
*)
echo "$1"
;;
esac
}

PROOTS='proots'
NAME="${NAME:-"linuxcontainers-$DISTRO-$RELEASE"}"

NAME="$(prompt "Installation subdir name $PROOTS/___" "$NAME")"

ROOTFS_DIR="$PROOTS/$NAME"
MINITAR="$DATA_DIR/minitar"

# There is no uname on old Androids.
ARCH=$(uname -m 2>/dev/null || ( aa=($("$TERMSH" arch)) ; to_uname_arch "${aa[0]}" ))

VARIANT=''
SDK="$(grep -e '^ro\.build\.version\.sdk=' /system/build.prop 2>/dev/null || echo '')"
SDK="${SDK#*=}"
if [ -n "$SDK" -a "$SDK" -lt 21 ]
then
VARIANT='-pre5'
fi

export TMPDIR="$DATA_DIR/tmp"
mkdir -p "$TMPDIR"

to_minitar_arch() {
case "$1" in
armv7a)
echo armeabi-v7a
;;
aarch64)
echo arm64-v8a
;;
i686)
echo x86
;;
amd64)
echo x86_64
;;
*)
echo "$1"
;;
esac
}

to_lco_arch() {
case "$1" in
armv7a)
echo armhf
;;
aarch64)
echo arm64
;;
i686)
echo i386
;;
amd64)
echo amd64
;;
*)
echo "$1"
;;
esac
}

to_lco_link() {
R="$( { "$TERMSH" cat 'https://us.images.linuxcontainers.org/meta/1.0/index-user' || exit_with 'Cannot download index from linuxcontainers.org' ;} \
| { grep -e "^$DISTRO;$RELEASE;$(to_lco_arch "$1");default;" || exit_with 'Cannot find specified rootfs' ;} )" || exit 1
P="${R##*;}"
echo "https://us.images.linuxcontainers.org/$P/rootfs.tar.xz"
}

echo "Arch: $ARCH"
echo "Variant: $VARIANT"
echo "$DISTRO $RELEASE"
echo

ROOTFS_URL="$(to_lco_link "$ARCH")"

echo "Source: $ROOTFS_URL"
echo

cd "$DATA_DIR"
(
echo 'Getting minitar...'
"$TERMSH" cat \
"https://raw.githubusercontent.com/green-green-avk/build-libarchive-minitar-android/master/prebuilt/$(to_minitar_arch "$ARCH")/minitar" \
> "$MINITAR"
chmod 755 "$MINITAR"
echo 'Getting PRoot...'
"$TERMSH" cat \
"https://raw.githubusercontent.com/green-green-avk/build-proot-android/master/packages/proot-android-$ARCH$VARIANT.tar.gz" \
| "$MINITAR"
mkdir -p "$ROOTFS_DIR/root"
mkdir -p "$ROOTFS_DIR/tmp"
cd "$ROOTFS_DIR/root"
echo 'Getting Debian...'
"$TERMSH" cat "$ROOTFS_URL" | "$MINITAR" || echo 'Possibly URL was changed: recheck on the site.' >&2

cat etc/passwd
REGULAR_USER_NAME="$(prompt 'Regular user name' "$REGULAR_USER_NAME")"
SHELL="$(prompt 'Preferred shell' "$SHELL")"

echo 'Setting up run script...'
mkdir -p etc/proot
RUN="$("$TERMSH" cat \
'https://raw.githubusercontent.com/green-green-avk/AnotherTerm-scripts/master/assets/run-tpl')"
RUN="${RUN/'@USER@'/"$REGULAR_USER_NAME"}"
RUN="${RUN/'@SHELL@'/"$SHELL"}"
echo "$RUN" > etc/proot/run
chmod 755 etc/proot/run
rm -rf ../run
ln -s root/etc/proot/run ../run # KitKat can only `ln -s'

echo 'Configuring...'
cat << EOF > etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

cat << EOF > etc/profile.d/locale.sh
if [ -f /etc/default/locale ]
then
. /etc/default/locale
export LANG
fi
EOF
cat << EOF > etc/profile.d/ps.sh
PS1='\[\e[32m\]\u\[\e[33m\]@\[\e[32m\]\h\[\e[33m\]:\[\e[32m\]\w\[\e[33m\]\\$\[\e[0m\] '
PS2='\[\e[33m\]>\[\e[0m\] '
EOF

# We have no adduser or useradd here...
cp -a etc/skel home/$REGULAR_USER_NAME 2>/dev/null || mkdir -p home/$REGULAR_USER_NAME
echo \
"$REGULAR_USER_NAME:x:$USER_ID:$USER_ID:guest:/home/$REGULAR_USER_NAME:$SHELL" \
>> etc/passwd

echo 'Creating favorites...'
"$TERMSH" view -N -r 'green_green_avk.anotherterm.FavoriteEditorActivity' \
-u "local_terminal:/opts?execute=%24DATA_DIR%2F${ROOTFS_DIR/\//%2F}%2Frun%200%3A0&name=$NAME%20(root)"
"$TERMSH" view -N -r 'green_green_avk.anotherterm.FavoriteEditorActivity' \
-u "local_terminal:/opts?execute=%24DATA_DIR%2F${ROOTFS_DIR/\//%2F}%2Frun&name=$NAME"
echo
echo 'Done, see notifications.'
)