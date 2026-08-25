
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

# Takes in path to a torrent file and outputs the list of files in that torrent
export def torrent_files [] : string -> list<string> {
	if (plugin list | where name == 'from_bencode' | is-empty) {
		error make {
			msg: "Plugin 'from_bencode' required for this operation"
		}
	}

	$in | do { nu -c $"open '($in)' | from bencode | to nuon --raw" }
	| from nuon | get info.files | where attr? != p | get path | flatten
}

export def super_rename [] {
	let files = $in
	if ( $files | is-empty ) {
		print $"(ls | length) Files in current directory"
		print -n 'Enter Filter Criteria: '

		loop {
			let k = (input listen --types [key])

			if $k.code == 'enter' or $k.code == 'return' {
				break
			}

			$k | table --expand | print

		}

	}

}

# Watch a file and run a command when it changes.
#
# Create, Write, and Rename events on `file_path` trigger `--action`.
# With no `--action`, the file is executed as a Nu script (`nu $file_path`).
# Press Ctrl+C to stop.
@search-terms watcher reload filesystem
@example 'Re-run a script when it is saved' { run_on_change ./script.nu }
@example 'Run tests whenever a file changes' { run_on_change ./app.nu --action { cargo test } }
@example 'Separate runs with a marker line' { run_on_change ./script.nu --show-after '---' }
export def run_on_change [
  file_path: string # file to watch
  --action: closure # command to run on each change (default: { nu $file_path })
  --show-before: string # printed before each run
  --show-after: string = '---' # printed after each run
]: nothing -> nothing {

  let target = $file_path | path parse | default --empty '.' parent

  let action = $action | default {{ nu $file_path }}

  # child job used to suppress terminal spam when cancelling watcher with CTRL+C
  let parent = job id
  let watcher = job spawn --description run_on_change {
    for ev in (watch $target.parent --recursive false --glob $"($target.stem).($target.extension)" --quiet) {
      if $ev.operation in [Create Write Rename] {
        $ev | job send $parent
      }
    }
  }
  loop {
    let ev = try { job recv } catch { null }
    if $ev == null { break }
    print $show_before
    try { do $action }
    print $show_after
  }
  try { job kill $watcher } catch { null }
}
