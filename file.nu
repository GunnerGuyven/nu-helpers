
# Replaces the contents of a given file
#
# Current content is piped into the `new_content` closure
# By default a backup is created with `date now` appended to the filename
@example 'update a simple file' { replace_file test.nuon { update def zzz } }
export def replace_file [
	file_path:string # path of file to replace
	new_content:closure # produce new version of file (old version is piped)
	--no-backup # do not leave behind a copy of the original file
] {
	let backup_file_path = $file_path | path parse | $'($in.stem).(date now | into int).($in.extension)'
	open $file_path	| do $new_content | save $backup_file_path
	if $no_backup {
		mv -f $backup_file_path $file_path
	} else {
		mv $backup_file_path ($backup_file_path + '.1')
		mv $file_path $backup_file_path
		mv ($backup_file_path + '.1') $file_path
	}
}
