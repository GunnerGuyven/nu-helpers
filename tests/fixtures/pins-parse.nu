# Parsers and version order for pins.nu. No network.

use ../../pins.nu [
	version-is-newer
	alpine-pins
	pecl-pins
	microsoft-pins
	microsoft-published
]
use std/assert

def main [] {
	assert equal (version-is-newer "8.23.0-r0" "8.22.0-r0") true
	assert equal (version-is-newer "8.22.0-r0" "8.22.0-r0") false
	assert equal (version-is-newer "5.13.3" "5.12.0") true
	assert equal (version-is-newer "5.12.0" "5.13.3") false
	assert equal (version-is-newer "18.7.1.1-1" "18.7.1.1-1") false
	assert equal (version-is-newer "17.11-r0" "17.9-r0") true
	assert equal (version-is-newer "7.0.0-r1" "7.0.0-r2") false
	assert equal (version-is-newer "1.2.1-r0" "1.2.0-r1") true

	let text = "FROM php:8.2-fpm-alpine3.24
	curl=8.22.0-r0 \\
	brotli=1.2.1-r0\\
	pecl install sqlsrv-5.12.0 pdo_sqlsrv-5.12.0
	curl -O https://example.test/msodbcsql18_18.7.1.1-1_amd64.apk
	apk add msodbcsql18_18.7.1.1-1_amd64.apk mssql-tools18_18.6.1.1-1_amd64.apk
"

	assert equal (alpine-pins $text | get package) ["curl" "brotli"]
	assert equal (alpine-pins $text | get pinned) ["8.22.0-r0" "1.2.1-r0"]
	assert equal (pecl-pins $text | get package) ["sqlsrv" "pdo_sqlsrv"]
	assert equal (pecl-pins $text | get pinned) ["5.12.0" "5.12.0"]
	assert equal (microsoft-pins $text | select package pinned) [
		[package pinned];
		[msodbcsql18 "18.7.1.1-1"]
		[mssql-tools18 "18.6.1.1-1"]
	]

	let doc = "# [Alpine](#tab/alpine18-install)
curl -O https://download.microsoft.com/download/x/msodbcsql18_18.7.1.1-1_\$architecture.apk
curl -O https://download.microsoft.com/download/y/mssql-tools18_18.7.1.1-1_\$architecture.apk
# [Alpine](#tab/alpine17-install)
curl -O https://download.microsoft.com/download/z/msodbcsql17_17.11.1.1-1_amd64.apk
"
	assert equal (microsoft-published $doc) {
		msodbcsql18: "18.7.1.1-1"
		mssql-tools18: "18.7.1.1-1"
	}
}
