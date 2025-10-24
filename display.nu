
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
