export def get-site-cookies [
	host:string
	--browser=vivaldi
	--out-file=cookies.yaml
	--force-refresh
] {
	mut all_cookies: record = try { open $out_file } catch { {} }

	if $host not-in ($all_cookies | columns) or $force_refresh {
		print 'updating cookies from browser'

		let c = mktemp --suffix .txt --dry
		yt-dlp --cookies-from-browser $browser --cookies $c --skip-download "https://example.com" e> /dev/null | ignore

		let $cookies = open $c
			| lines | where $it like $host | split column "\t" | group-by column0
			| items { |k,v| { ($k | str replace --regex '^\.' ''): ($v | select column5 column6 | transpose --header-row --as-record )}}
			| into record

		$all_cookies = $all_cookies | merge $cookies
		$all_cookies | save -f $out_file

		rm $c
	}

	$all_cookies | get --optional $host | default {}
}
