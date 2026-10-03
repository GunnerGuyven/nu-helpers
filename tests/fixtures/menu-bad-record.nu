# A @menuentry record without display is an error.

use ../../display.nu [
	create_menu_entries_from_subcommands
	"attr menuentry"
]
use std/assert

@menuentry {label: "Partial"}
def "main partial" [] {}

const self_path = path self

def main [] {
	let raised = try {
		create_menu_entries_from_subcommands $self_path | collect
		false
	} catch {|e|
		assert str contains $e.rendered "Badly formed menuentry"
		true
	}
	assert $raised "expected a badly formed menuentry"
}
