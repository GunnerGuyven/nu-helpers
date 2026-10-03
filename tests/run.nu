# Run the menu fixtures.
#
# Each fixture exits 0 when its assertions hold. Fixtures run under
# `nu --no-config-file` so the caller's display hook cannot change their output.

use std/assert

const self_path = path self

def main [] {
	let dir = $self_path | path dirname | path join fixtures
	let names = [
		menu-entries.nu
		menu-bad-record.nu
		menu-bad-number.nu
		menu-bad-span.nu
	]
	for name in $names {
		let path = $dir | path join $name
		let result = ^nu --no-config-file $path | complete
		assert equal $result.exit_code 0 $"($name)\n($result.stdout)($result.stderr)"
	}
	print $"passed ($names | length) fixtures"
}
