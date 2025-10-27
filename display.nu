
export def disable_cursor [] { print (ansi -e ?25l) --no-newline }

export def color [ color:string ] {	$'(ansi $color)($in)(ansi reset)' }
# export def c_blue [] { color blue }
# export def c_lblue [] { color light_blue }
# export def c_cyan [] { color cyan }
# export def c_green [] { color light_green }
# export def c_yellow [] { color yellow }
# export def c_red [] { color red }
# export def c_purple [] { color purple }
# export def c_magenta [] { color magenta }
# export def c_gray [] { color dark_gray }

export def p0 [ width:int = 2  ] { fill --width $width --alignment right --character 0   }
export def p_ [ width:int = 10 ] { fill --width $width --alignment right --character ' ' }

export def highlight_rows [row_indexes:list<int> --highlight-color:string = yellow] {
	let $table = $in
	$row_indexes | reduce --fold $table {|idx| update $idx {|row| $row | update cells { color $highlight_color }}}
}

export def show_match [
	field_name:string
	match:string
	--show:string
	--highlight-color:string = red
	--max-rows:int = 20
	--regex
	--all
] {
	let data = $in
	let s = if ($show | is-empty) {
		if $regex { '$1' } else { $match }
		| color $highlight_color
	} else { $show }

	let matches = $data | if $regex {
		where { get $field_name | $in =~ $match }
	} else {
		where { get $field_name | str contains $match }
	}
	| update $field_name { str replace --all=$all --regex=$regex $match $s}

	{ total: ($matches | length) summary: ($matches | take $max_rows) }
}

export def show_match_presentation [
	field_name:string
	match:string
	--match-display:string
	on_found?:closure
	--show:string
	--max-rows:int = 20
	--regex
	--all

	--color-highlight:string = red
	--color-fieldname:string = green
	--color-matchcount:string = yellow
] {
	let data = $in
	let m = if ($match_display | is-empty) { $match } else { $match_display }

	$data	| (
		show_match
		$field_name
		$match
		--show $show
		--highlight-color $color_highlight
		--max-rows $max_rows
		--regex=$regex
		--all=$all
	)
	| if $in.total > 0 {
		let result = $in
		print $result.summary
		print $'Found ($result.total | color $color_matchcount) instances of ($m | color $color_highlight) in field ($field_name | color $color_fieldname)'
		if $on_found != null { $result | do $on_found }
	} else {
		print $'No instances of ($m | color $color_highlight) found in field ($field_name | color $color_fieldname)'
	}
}

export def show_prompt [
	message:string
	on_yes:closure
	--decline-message:string = $'(ansi blue)  Back(ansi reset)'
] {
	[	[label confirm];
		[$message true]
		[$decline_message false]
	] | input list -d label | if $in.confirm { do $on_yes }
}

export def show_countdown [
	how_long:duration
	--label-prefix:string = ''
	--label-counter:string = ''
	--label-completed:string = 'Done'
	--starting-column:int = 0
	--no-newline
] {
	let z = ansi -e 0K # terminal code for clearing to the right (overwriting)
	let r = ansi -e $'($starting_column)G'
	let seconds = ($how_long / 1sec) | into int

	for i in 0..($seconds - 1) {
		let until = $how_long - ($i | into duration --unit sec)
		print $"($r)($label_prefix)($label_counter)($until)($z)\r" --no-newline
		sleep 1sec
	}
	print $"($r)($label_prefix)($label_completed)($z)" --no-newline=$no_newline
}

export def show_countdown_repeat [
	how_long:duration
	is_done_check : closure

	--label-prefix:string = ''
	--label-counter:string = ''
	--label-pending:string = 'Performing Check'
	--label-completed:string = 'Done'
	--no-newline

	--repeat-duration:duration = 10sec
	--repeat-label-prefix:string
	--repeat-label-counter:string
	--repeat-label-pending:string
	--repeat-label-completed:string
	--repeat-on-newline

	--repeat-max:int = 30
] {
	( show_countdown $how_long
		--label-prefix $label_prefix
		--label-counter $label_counter
		--label-completed $label_pending
		--no-newline=(not $repeat_on_newline) )

	let repeat_labels = {
		prefix: (if $repeat_label_prefix != null { $repeat_label_prefix } else { $label_prefix })
		counter: (if $repeat_label_counter != null { $repeat_label_counter } else { $label_counter })
		pending: (if $repeat_label_pending != null { $repeat_label_pending } else { $label_pending })
		completed: (if $repeat_label_completed != null { $repeat_label_completed } else { $label_completed })
	}

	let z = ansi -e 0K # terminal code for clearing to the right (overwriting)
	for i in 1..$repeat_max {
		let m = {iteration:$i}
		let check = $i | do $is_done_check
		if $check.done {
			if $check.fail {
				return {success:false result:{result:$check.result}}
			} else {
				if not $repeat_on_newline { print "\r" --no-newline }
				if $i > 1 {
					print $'($repeat_labels.prefix)($repeat_labels.completed)($z)' --no-newline=$no_newline
				} else {
					print $'($label_prefix)($label_completed)($z)' --no-newline=$no_newline
				}
				return {success:true result:$check.result}
			}
		} else {
			print "\r" --no-newline
			( show_countdown $repeat_duration
				--label-prefix $repeat_labels.prefix
				--label-counter ($m | format pattern $repeat_labels.counter)
				--label-completed $repeat_labels.pending
				--no-newline=(not $repeat_on_newline) )
		}
	}
	{success:false result:{result:'Maximum Retries Exceeded'}}
}

export def show_await_task [
	how_long:duration
	create_task:closure
	check_task_status:closure

	--label-task:string           = 'Performing Asynchronous Task'
	--label-launch:string         = 'Creating Task'
	--label-counter:string        = 'Checking Status in '
	--label-counter-repeat:string = 'Re-checking Status ({c_}{i}{c_cr}) in '
	--label-pending:string        = 'Performing Check'
	--label-success:string        = 'SUCCESS'
	--label-failure:string        = "FAILED ({extra}{c_f})"
	--label-failure-extra:string  = '{result}'

	--color-task:string           = blue
	--color-launch:string         = yellow
	--color-counter:string        = yellow
	--color-counter-repeat:string = yellow
	--color-pending:string        = yellow
	--color-success:string        = green
	--color-failure:string        = red
	--color-failure-extra:string  = white

	--repeat-duration:duration    = 10sec
	--repeat-max:int              = 30
] {

	let failure_extra = $label_failure_extra | color $color_failure_extra
	let color = {
		c_t: (ansi $color_task)
		c_l: (ansi $color_launch)
		c_c: (ansi $color_counter)
		c_cr:(ansi $color_counter_repeat)
		c_p: (ansi $color_pending)
		c_s: (ansi $color_success)
		c_f: (ansi $color_failure)
		c_fe:(ansi $color_failure_extra)
		c_:  (ansi reset)
	}
	let label = {
		task:      ($color | format pattern $label_task    | color $color_task)
		launch:    ($color | format pattern $label_launch  | color $color_launch)
		counter:   ($color | format pattern $label_counter | color $color_counter)
		counter_r: ({...$color i:'{iteration}'} | format pattern $label_counter_repeat | color $color_counter_repeat)
		pending:   ($color | format pattern $label_pending | color $color_pending)
		success:   ($color | format pattern $label_success | color $color_success)
		failure:   ({...$color extra:$failure_extra} | format pattern $label_failure | color $color_failure)
	}

	print $"($label.task) : ($label.launch)\r" --no-newline
	let create = do $create_task
	if not $create.success {
		print ($create | format pattern $"($label.task) : ($label.failure)(ansi -e 0K)")
		return $create
	}
	let is_done_check = { {task:$create.task try:$in} | do $check_task_status }
	let awaited_task = ( show_countdown_repeat $how_long $is_done_check
		--label-prefix $'($label.task) : '
		--label-counter $label.counter
		--label-pending $label.pending
		--label-completed $label.success
		--repeat-label-counter $label.counter_r
		--repeat-duration $repeat_duration --repeat-max $repeat_max
	)
	if not $awaited_task.success {
		print ($awaited_task.result | format pattern $"\r($label.task) : ($label.failure)(ansi -e 0K)")
	}
	$awaited_task
}

export def show_task_array_status [
	--hide-summary
	--max-line-width:int = 150

	--label-summary:string = 'Operation in Progress'

	--color-success:string = green
	--color-failure:string = red
	--color-pending:string = dark_gray
	--color-active:string = purple
	--color-summary:string = blue
] {
	let tasks = $in
	let tasks_count = $tasks | length
	let w = $tasks_count | $'($in)' | str length
	let grid_width = [$max_line_width (term size | get columns)] | math min
	let complete_count = $tasks | where {|t| $t.status in [SUCCESS FAILURE CANCELLED]} | length

	let grid = $tasks | each {|t|
		match $t.status {
			'SUCCESS' => { $'(ansi $color_success)  ' }
			'ERROR' => { $'(ansi $color_failure)  ' }
			'CANCELLED' => { $'(ansi $color_failure)󰜺  ' }
			'IN_PROGRESS' => { $'(ansi $color_active)  ' }
			_ => { $'(ansi $color_pending)  ' }
		} | $'($in)($t.name)(ansi reset)'
	} | grid --width $grid_width --separator '  '

	if not $hide_summary {
		let count_display = $' ($complete_count | p0 $w) / ($tasks_count) '
		print $"\r(ansi $color_summary)($label_summary) [(ansi reset)($count_display)(ansi $color_summary)](ansi reset) :(ansi -e 0K)"
	}
	print $grid --no-newline

	if $complete_count != $tasks_count {
		let sum_lines = if $hide_summary { 0 } else { 1 }
		let back_rows = $'(($grid | lines | length) + $sum_lines)F'
		print -n $'(ansi -e $back_rows)'
		false
	} else { true }
}
