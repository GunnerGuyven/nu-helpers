# A numeric @menuentry is an error. A doc comment and the include flag do not replace it.

use ../../display.nu [
	create_menu_entries_from_subcommands
	"attr menuentry"
]
use std/assert

# Nice description
@menuentry 3
def "main number" [] {}

const self_path = path self

def main [] {
	let raised = try {
		create_menu_entries_from_subcommands $self_path --include-non-menuentry-subcommands | collect
		false
	} catch {|e|
		assert str contains $e.rendered "Badly formed menuentry"
		true
	}
	assert $raised "expected a badly formed menuentry"
}
