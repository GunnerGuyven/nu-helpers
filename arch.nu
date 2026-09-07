use display.nu [ color show_menu show_prompt ]

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
	| update OutOfDate {if ( $in | is-not-empty ) { into datetime -f '%s' } }

	$repo | join --left $remote package
	| insert ltoi {|r| compare-version $r.local $r.installed }
	| insert ltor {|r| compare-version $r.local $r.remote }
}

def aur-list-present [] {
		update installed {|r| if ($r.ltoi < 0) { color blue } else { color grey } }
	| update remote    {|r| if ($r.ltor < 0) { color blue } else { color grey } }
	| update local     {|r| if ($r.ltoi > 0) { color blue } else { color grey } }
	| update package   {|r| if ($r.ltoi > 0) { color blue } else { color grey } }
	| update OutOfDate {if ($in | is-not-empty) { date humanize | color red } }
	| drop column 2
}

def aur-sync [] {
	aur sync -c --upgrades
}

def aur-local-cleanup [] {
	let selection = aur-list | input list --multi 

	let repo_entries = aur repo --json | from json
	| join $selection Name package

	$repo_entries
	| each {
	  let pkg = $in.Name
	  let file = $in.FileName
	  let db = $in.DBPath
	  repo-remove $db $pkg
	  rm ($db | path parse | get parent | path join $file)
	}
}

# Search the AUR. Keywords may be positional or a single piped string
# (split into words so `'daddy time' | aur-search` matches `aur search daddy time`).
# No matches → empty table (aur exits 1 with empty stdout).
def aur-search [...terms: string] {
  let keywords = if ($terms | is-not-empty) {
    $terms
  } else {
    $in | default '' | into string | str trim | split words
  }
  if ($keywords | is-empty) {
    error make { msg: "aur-search: no search terms (pass args or pipe a string)" }
  }
  let result = aur search ...$keywords --json | complete
  if $result.exit_code != 0 or ($result.stdout | str trim | is-empty) {
    return []
  }
  $result.stdout | from json
}

def aur-search-prompt [] {
  let results = input "Search: " | aur-search
  if ($results | is-empty) {
    print "No packages found."
    return
  }

  let pkg = $results
  | update FirstSubmitted { into datetime -f '%s' | date humanize }
  | update LastModified { into datetime -f '%s' | date humanize }
  | move --first Name Version Description LastModified Maintainer
  | input list --fuzzy

  if ($pkg | is-not-empty) {
    print $pkg
    [ [label action];
      ['Build this package and store into local repo' {aur sync -c $pkg.Name}]
      ['Open this package on the AUR website' { start $"https://aur.archlinux.org/packages/($pkg.Name)" }]
      [(' Back' | color red) null]
    ] | show_menu
  }
}

def "main test" [] {
	aur-search-prompt
}

export def main [] {
	[
		[label action];
		["Show Local Packages" { aur-list | aur-list-present | print }]
		["Search AUR for Packages to Add" { aur-search-prompt }]
		["Sync Remote to Local" { aur-sync | print }]
		["Pick Local Packages to Remove" { aur-local-cleanup }]
		[("Exit" | color red) null]
	] | show_menu
}

