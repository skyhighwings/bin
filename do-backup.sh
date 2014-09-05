#!/bin/bash
# Rylee Fowler 2014

eval `keychain --noask --quiet --eval id_rsa F637E333` || exit 1
backup_dirs=( $HOME/eggdrop $HOME/eggdrop.info $HOME/cool $HOME/.ssh\
	$HOME/.ssl $HOME/code/resume $HOME/code/dotfiles\
	$HOME/.tmuxinator $HOME/public_html $HOME/code/Terminus-Bot\
	$HOME/irclogs $HOME/.vim $HOME/code/dotfiles $HOME/bin
	)
weechats=( $HOME/.weechat/ $HOME/nexus/.weechat/ $HOME/dawn/.weechat/ $HOME/xmpp-weechat/.weechat/ )
weechat_owners=( rylee nexus dawn hangouts )
tmpdir="$(mktemp -d)"
backups_dir=backups/
servers=( davion citadel )
mykey=F637E333

# Usage: backup_file $local_file
# Copies a given file to the $backups_dir on the backup server.
backup_file() {
	local local_file="$1";
	for server in "${servers[@]}"; do
		scp -q "$1" "$server:$backups_dir/";
	done;
}

# Usage: backup_dir $local_dir $remote_dir
# Copies a given directory to the $remote_dir in the $backups_dir on the backup server.
backup_dir() {
	local local_dir="$1";
	local remote_dir="$2";
	for server in "${servers[@]}"; do
		rsync --quiet --recursive --copy-links --copy-dirlinks "$1/" "$server:$backups_dir/$2";
	done;
}

# Usage: encrypt_dir $dir
# Will set global variable $gpg_loc to the location of the encrypted file.
encrypt_dir() {
	local dir="$1";
	gpgname="$(basename "$dir")";
	gpgname="${gpgname#.}.gpg"; # Remove leading dot
	gpg_loc="$tmpdir/$gpgname";
	# Some explaining:
	# - Using -h because some of the files I want to keep are symlinked (in $HOME/bin, for example).
	# - We change directory to $(dirname $dir) and tar up $(basename $dir)
	#   so that we have *relative* file paths, not absolutes (i.e. not
	#   hardcoded to extract into /home/rylai/$whatever
	tar  cz --warning=no-file-changed -h --exclude=cm_socket --exclude=.dbox -C "$(dirname $dir)" "$(basename $dir)" | gpg --encrypt -r "$mykey" > "$gpg_loc";
}

# Usage: encrypt_weechat $dir $owner
# The given directory will be encrypted _excluding_ logs, and named as $owner-weechat.gpg
# Will set global variable $gpg_loc to the location of the encrypted file
encrypt_weechat() {
	local dir="$1";
	local owner="$2";
	gpg_loc="$tmpdir/$owner-weechat.gpg";
	tar cz -h --warning=no-file-changed --exclude=logs -C "$(dirname $dir)" "$(basename $dir)" | gpg --encrypt -r "$mykey" > "$gpg_loc";
}

trap "{ rm -rf \"$tmpdir\"; }" EXIT

for dir in "${backup_dirs[@]}"; do
	encrypt_dir "$dir"
done
for i in "${!weechats[@]}"; do
	encrypt_weechat "${weechats[$i]}" "${weechat_owners[$i]}";
done

# We GPG encrypt everything and then sync it across to all hosts with rsync.
# This way is definitely better, trust me.
backup_dir "$tmpdir" ""
