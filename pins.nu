use display.nu [color]

# Compare pinned package versions in a Containerfile with the versions those sources publish now.
#
# Alpine `name=version` pins use the `FROM` line (`alpine3.24` -> v3.24) and the
# x86_64 main and community indexes. `pecl install` names use PECL's stable
# version. `pie install` names use the newest stable Packagist version.
# `msodbcsql18` and `mssql-tools18` apk filenames use the ODBC 18 Alpine
# block of Microsoft's install doc. A pin should change when the published
# version is newer.

def download-text [url: string] {
	let result = (^curl -fsSL --retry 2 $url | complete)
	if $result.exit_code != 0 {
		error make {msg: $"download failed: ($url)"}
	}
	$result.stdout
}

def version-parts [version: string] {
	let with_rel = $version | parse --regex '^(?P<upstream>.+)-r(?P<rel>[0-9]+)$'
	let parts = if not ($with_rel | is-empty) {
		$with_rel | first
	} else {
		let dashed = $version | parse --regex '^(?P<upstream>.+)-(?P<rel>[0-9]+)$'
		if not ($dashed | is-empty) {
			$dashed | first
		} else {
			{upstream: $version, rel: "0"}
		}
	}
	{
		nums: ($parts.upstream | split row "." | each {|seg| $seg | into int})
		rel: ($parts.rel | into int)
	}
}

def cmp-list [left: list<any>, right: list<any>] {
	if ($left | is-empty) and ($right | is-empty) {
		0
	} else {
		let a = $left | get --optional 0 | default 0
		let b = $right | get --optional 0 | default 0
		if $a < $b {
			-1
		} else if $a > $b {
			1
		} else {
			cmp-list ($left | skip 1) ($right | skip 1)
		}
	}
}

# True when `published` is a newer pin than `pinned`.
# Numeric segments compare in order, then an Alpine `-rN` or a trailing `-N`.
export def version-is-newer [published: string, pinned: string] {
	let published_parts = (version-parts $published)
	let pinned_parts = (version-parts $pinned)
	let cmp = (cmp-list $published_parts.nums $pinned_parts.nums)
	if $cmp != 0 {
		$cmp > 0
	} else {
		$published_parts.rel > $pinned_parts.rel
	}
}

# Alpine `name=version` pins. Each row has package, pinned, and source `alpine`.
export def alpine-pins [text: string] {
	$text
	| lines
	| each {|line|
		let hit = $line | parse --regex '\s*(?P<package>[A-Za-z0-9][A-Za-z0-9+_.-]*)=(?P<pinned>[0-9][A-Za-z0-9.+_-]*)'
		if ($hit | is-empty) {
			null
		} else {
			$hit | first | insert source "alpine"
		}
	}
	| compact
}

# `pecl install` package versions. `pdo_sqlsrv` is matched before `sqlsrv`.
export def pecl-pins [text: string] {
	$text
	| lines
	| where {|line| $line | str contains "pecl install"}
	| each {|line|
		$line
		| split row " "
		| each {|token|
			let hit = $token | parse --regex '^(?P<package>pdo_sqlsrv|sqlsrv)-(?P<pinned>[0-9]+\.[0-9]+\.[0-9]+)$'
			if ($hit | is-empty) {
				null
			} else {
				$hit | first | insert source "pecl"
			}
		}
	}
	| flatten
	| compact
}

# `pie install` package versions. `vendor/name-1.2.3` and `vendor/name:1.2.3`.
# A leading `v` on the version is dropped. Constraints such as `^1.2` are not pins.
export def pie-pins [text: string] {
	$text
	| lines
	| where {|line| $line | str contains "pie install"}
	| each {|line|
		$line
		| str replace --all "\t" " "
		| split row " "
		| where {|token| not ($token | is-empty)}
		| each {|token|
			let hit = $token | parse --regex '^(?P<package>[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*)(?::|-)v?(?P<pinned>[0-9]+(?:\.[0-9]+)+)$'
			if ($hit | is-empty) {
				null
			} else {
				$hit | first | insert source "pie"
			}
		}
	}
	| flatten
	| compact
}

# `msodbcsql18` and `mssql-tools18` amd64 apk filenames. Repeated names keep the first.
export def microsoft-pins [text: string] {
	$text
	| lines
	| each {|line|
		$line
		| str replace --all "\t" " "
		| split row " "
		| where {|token| not ($token | is-empty)}
		| each {|token|
			let hit = $token | parse --regex '(?P<package>msodbcsql18|mssql-tools18)_(?P<pinned>[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-[0-9]+)_amd64\.apk'
			if ($hit | is-empty) {
				null
			} else {
				$hit | first | insert source "microsoft"
			}
		}
	}
	| flatten
	| compact
	| reduce --fold [] {|row, acc|
		if ($acc | where {|item| $item.package == $row.package} | is-empty) {
			$acc | append $row
		} else {
			$acc
		}
	}
}

# Current x86_64 versions for `packages` from the Alpine `branch` (`v3.24`).
# The record keys are package names.
export def alpine-index [branch: string, packages: list<string>] {
	if ($packages | is-empty) {
		return {}
	}
	let names = $packages | str join ","
	[
		$"https://dl-cdn.alpinelinux.org/alpine/($branch)/main/x86_64/APKINDEX.tar.gz"
		$"https://dl-cdn.alpinelinux.org/alpine/($branch)/community/x86_64/APKINDEX.tar.gz"
	]
	| reduce --fold {} {|url, acc|
		let dir = (mktemp --directory)
		let archive = $dir | path join "index.tar.gz"
		let fetched = (^curl -fsSL --retry 2 -o $archive $url | complete)
		if $fetched.exit_code != 0 {
			rm --recursive --force $dir
			error make {msg: $"download failed: ($url)"}
		}
		let untar = (^tar -xzf $archive -C $dir APKINDEX | complete)
		if $untar.exit_code != 0 {
			rm --recursive --force $dir
			error make {msg: $"download failed: ($url)"}
		}
		let matched = (
			with-env {PIN_NAMES: $names} {
				^awk '
					BEGIN {
						n = split(ENVIRON["PIN_NAMES"], parts, ",")
						for (i = 1; i <= n; i++) want[parts[i]] = 1
					}
					/^P:/ { name = substr($0, 3) }
					/^V:/ { if (name in want) print name "\t" substr($0, 3) }
				' ($dir | path join "APKINDEX")
				| complete
			}
		)
		rm --recursive --force $dir
		if $matched.exit_code != 0 {
			error make {msg: $"download failed: ($url)"}
		}
		$matched.stdout
		| lines
		| where {|line| not ($line | is-empty)}
		| reduce --fold $acc {|line, found|
			let bits = $line | split row "\t"
			$found | upsert ($bits | get 0) ($bits | get 1)
		}
	}
}

# PECL stable version for `package`, from `rest/r/<package>/stable.txt`.
export def pecl-stable [package: string] {
	let url = $"https://pecl.php.net/rest/r/($package)/stable.txt"
	let body = download-text $url | str trim
	let ok = $body | parse --regex '^[0-9]+\.[0-9]+\.[0-9]+$'
	if ($ok | is-empty) {
		error make {msg: $"download failed: ($url)"}
	}
	$body
}

# Newest stable Packagist version for a PIE package (`vendor/name`).
export def pie-stable [package: string] {
	let name = ($package | str lowercase)
	let url = $"https://repo.packagist.org/p2/($name).json"
	let body = (download-text $url | from json)
	let versions = ($body.packages | get --optional $name)
	if $versions == null {
		error make {msg: $"download failed: ($url)"}
	}
	let stable = (
		$versions
		| get version
		| each {|ver|
			let stripped = if ($ver | str starts-with "v") {
				$ver | str substring 1..
			} else {
				$ver
			}
			let ok = ($stripped | parse --regex '^[0-9]+(\.[0-9]+)+$')
			if ($ok | is-empty) { null } else { $stripped }
		}
		| compact
	)
	if ($stable | is-empty) {
		error make {msg: $"download failed: ($url)"}
	}
	$stable | reduce {|ver, newest|
		if (version-is-newer $ver $newest) { $ver } else { $newest }
	}
}

# `msodbcsql18` and `mssql-tools18` versions in the ODBC 18 Alpine section of `text`.
export def microsoft-published [text: string] {
	let start = $text | str index-of "alpine18-install"
	if $start < 0 {
		error make {msg: "no alpine18-install section"}
	}
	let rest = $text | str substring $start..
	let end = $rest | str index-of "alpine17-install"
	let section = if $end < 0 { $rest } else {
		$rest | str substring ..<$end
	}
	[msodbcsql18 mssql-tools18]
	| reduce --fold {} {|package, acc|
		let marker = $"($package)_"
		let found = (
			$section
			| lines
			| each {|line|
				let at = $line | str index-of $marker
				if $at < 0 {
					null
				} else {
					let tail = $line | str substring ($at + ($marker | str length))..
					let hit = $tail | parse --regex '^(?P<published>[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-[0-9]+)_'
					if ($hit | is-empty) { null } else { $hit | first | get published }
				}
			}
			| compact
		)
		if ($found | is-empty) {
			error make {msg: $"no ($package) version in alpine18-install section"}
		}
		$acc | upsert $package ($found | first)
	}
}

# Download Microsoft's ODBC install doc and return the Alpine 18 apk versions.
export def microsoft-versions [--url: string = "https://raw.githubusercontent.com/MicrosoftDocs/sql-docs/live/docs/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server.md"] {
	microsoft-published (download-text $url)
}

def alpine-branch [text: string] {
	let branch_hit = (
		$text
		| lines
		| each {|line|
			let hit = $line | parse --regex 'alpine(?P<ver>[0-9]+\.[0-9]+)'
			if ($hit | is-empty) { null } else { $hit | first | get ver }
		}
		| compact
	)
	if ($branch_hit | is-empty) {
		error make {msg: "Containerfile has no alpine version"}
	}
	$"v($branch_hit | first)"
}

# Print every pin in `containerfile`. `should_change` is true when the published version is newer.
export def check [containerfile: string] {
	let text = (open --raw $containerfile)
	let alpine = (alpine-pins $text)
	let pecl = (pecl-pins $text)
	let pie = (pie-pins $text)
	let microsoft = (microsoft-pins $text)
	let alpine_rows = if ($alpine | is-empty) {
		[]
	} else {
		let index = alpine-index (alpine-branch $text) ($alpine | get package)
		$alpine | each {|pin|
			let published = $index | get --optional $pin.package
			$pin | insert published (if $published == null { "absent" } else { $published })
		}
	}
	let pecl_rows = (
		$pecl | each {|pin| $pin | insert published (pecl-stable $pin.package)}
	)
	let pie_rows = (
		$pie | each {|pin| $pin | insert published (pie-stable $pin.package)}
	)
	let microsoft_rows = if ($microsoft | is-empty) {
		[]
	} else {
		let doc_versions = (microsoft-versions)
		$microsoft | each {|pin|
			let published = $doc_versions | get --optional $pin.package
			if $published == null {
				error make {msg: $"no ($pin.package) version in alpine18-install section"}
			}
			$pin | insert published $published
		}
	}

	$alpine_rows ++ $pecl_rows ++ $pie_rows ++ $microsoft_rows
	| each {|row|
		$row | insert should_change (
			$row.published != "absent" and (version-is-newer $row.published $row.pinned)
		)
	}
	| select package pinned published should_change source
}

def check-list-present [] {
	each {|r|
    let tone = if ( $r.should_change ) { 'blue' } else { 'grey' }
    $r | update cells { color $tone }
  } | reject should_change
  | group-by source --prune 
}

export def main [containerfile?: string] {
	let file = $containerfile | default { ls
		| where type == file
		| where ($in.name | str lowercase ) in [containerfile dockerfile]
		| get 0?.name
  }
	if ($file | is-empty) {
		print 'Provide path to containerfile'
	} else {
		print ($file | path expand)
		check $file | check-list-present
	}
}
