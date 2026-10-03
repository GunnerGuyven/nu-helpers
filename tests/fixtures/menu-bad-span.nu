# A display span without at and style is an error.

use ../../display.nu [
	create_menu_entries_from_subcommands
	"attr menuentry"
]
use std/assert

@menuentry {label: "Broken" display: [{nope: 1}]}
def "main broken" [] {}

const self_path = path self

def main [] {
	let raised = try {
		create_menu_entries_from_subcommands $self_path | collect
		false
	} catch {|e|
		assert str contains $e.rendered 'all display spans must specify "at" and "style" components'
		true
	}
	assert $raised "expected a display-span error"
}
