use display.nu [
	disable_cursor
	show_await_task
	show_task_array_status
	show_countdown
]

def main [] {}
def "main countdowns" [] {

	disable_cursor

	show_await_task 5sec { sleep 1sec ; {success:false result:"refused on initial request"}} {sleep 1sec ; {done:false}}
	show_await_task 5sec { sleep 1sec ; {success:true task:[]}} {sleep 1sec ; {done:true fail:true result:"refused after consideration"}}
	show_await_task 5sec { sleep 1sec ; {success:true task:[]}} {sleep 1sec ; {done:false}} --repeat-duration 3sec --repeat-max 5
	show_await_task 5sec { sleep 1sec ; {success:true task:[]}} {sleep 1sec ; {done:true fail:false result:"we did it!"}}
	(show_await_task 5sec --repeat-duration 3sec
	{ sleep 1sec ; {success:true task:123}}
	{ sleep 1sec ; {done:(if ($in.try > 2) {true} else {false}) fail:false result:"we did it (after a few tries)!"}}
	)
	let x = [abc def ghi jkl mno pqr stu vwx yz]
	for $i in 1..($x | length) {
		$x | enumerate
		| each {|t|
			if $t.index < $i {
				{ status: SUCCESS name: $t.item }
			} else { {status: PENDING name: $t.item }  }
		}
		| show_task_array_status
		sleep 150ms
	}
	for $i in 1..($x | length) {
		$x | enumerate
		| each {|t|
			if $t.index < $i {
				{ status: SUCCESS name: $t.item }
			} else { {status: PENDING name: $t.item }  }
		}
		| show_task_array_status
		| if not $in {
			show_countdown 2sec --starting-column 45 --no-newline --label-prefix 'Rechecking Status in '
		}
	}
}
