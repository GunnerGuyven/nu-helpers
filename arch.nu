use display.nu [ color show_menu ]

def compare-version [a?:string b?:string] {
	if ($a | is-empty) and ($b | is-empty ) { return 0 }
	if ($a | is-empty) { return (-1) }
	if ($b | is-empty) { return (1) }
	vercmp $a $b | into int
}

def aur-list [--show-debug-packages] {
	let installed = pacman -Q | detect columns --no-headers | rename package installed

	let repo = aur repo --list --json | from json
	| select Name Version | rename package local | join --left $installed package | move installed --after package
	| if $show_debug_packages { $in } else { where package !~ '-debug' }

	let remote = $repo.package | str join (char nl) | aur query -t info -
	| from json | get results | select Name Version OutOfDate | rename package remote
	| update OutOfDate {if ( $in | is-not-empty ) { into datetime -f '%s' | date humanize | color red } }

	$repo | join --left $remote package
	| insert ltoi {|r| compare-version $r.local $r.installed }
	| insert ltor {|r| compare-version $r.local $r.remote }
	| update installed {|r| if ($r.ltoi < 0) { color blue } else { color grey } }
	| update remote {|r| if ($r.ltor < 0) { color blue  } else { color grey } }
	| update local {|r| if ($r.ltoi > 0) { color blue } else { color grey } }
	| update package {|r| if ($r.ltoi > 0) { color blue } else { color grey } }
	| drop column 2
}

def aur-sync [] {
	aur sync -c --upgrades
}

export def main [] {
	[
		[label action];
		["Show Aur Packages" { aur-list | print }]
		["Sync From Remote" { aur-sync | print }]
		[("Exit" | color red) null]
	] | show_menu
}

