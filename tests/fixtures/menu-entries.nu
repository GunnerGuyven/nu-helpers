# Labels, color, and per-row actions for create_menu_entries_from_subcommands.

use ../../display.nu [
	create_menu_entries_from_subcommands
	"attr menuentry"
]
use std/assert

def helper [] {}

# Has a description
def "main described" [] { print "RAN described" }

def "main blank" [] { print "RAN blank" }

@menuentry "Pretty label"
def "main tagged" [] { print "RAN tagged" }

# Doc should not win
@menuentry "From attribute"
def "main both" [] { print "RAN both" }

@menuentry ""
def "main emptyattr" [] { print "RAN emptyattr" }

@menuentry {label: "Colored" display: "blue"}
def "main record" [] { print "RAN record" }

@menuentry {label: "Show Local Packages" display: [[0 blue] [5 red] [10 yellow]]}
def "main show" [] { print "RAN show" }

# Sync everything
def "main sync all" [] { print "RAN sync all" }

const self_path = path self

def main [] {
	let off = create_menu_entries_from_subcommands $self_path | collect
	let on = (
		create_menu_entries_from_subcommands $self_path --include-non-menuentry-subcommands
		| collect
	)

	assert equal ($off.label | each { ansi strip } | collect) [
		"Pretty label"
		"From attribute"
		""
		"Colored"
		"Show Local Packages"
	]
	assert equal ($on.label | each { ansi strip } | collect) [
		"Has a description"
		"blank"
		"Pretty label"
		"From attribute"
		""
		"Colored"
		"Show Local Packages"
		"Sync everything"
	]

	let colored = $off | where {|e| ($e.label | ansi strip) == "Colored"} | get label.0
	let spanned = $off | where {|e| ($e.label | ansi strip) == "Show Local Packages"} | get label.0
	assert ($colored != ($colored | ansi strip)) "colored label should contain ansi"
	assert ($spanned != ($spanned | ansi strip)) "span label should contain ansi"

	let run = {|name|
		let action = $on | where {|e| ($e.label | ansi strip) == $name} | get action.0
		do $action | str trim
	}
	assert equal (do $run "blank") "RAN blank"
	assert equal (do $run "Sync everything") "RAN sync all"
}
