const sqlline_path_default = '~/.local/share/sqlline/'

def setup [--sqlline-path:path] {

  let sqlline_path = $sqlline_path | default $sqlline_path_default | path expand

  let maven_root = "https://repo1.maven.org/maven2/sqlline/sqlline"
  let version = http get $"($maven_root)/maven-metadata.xml"
  | get content | where tag == versioning 
  | get content.0 | where tag == release
  | get content.0.content.0

  let jar_name = $"sqlline-($version)-jar-with-dependencies.jar"

  mkdir $sqlline_path

  if ( ls --short-names $sqlline_path | where name == $jar_name | is-empty ) {
    http get $"($maven_root)/($version)/($jar_name)" 
    | save --raw ($sqlline_path | path join $jar_name) --progress
  } # else { print "already downloaded" }

  $sqlline_path | path join $jar_name
}


export def sqlline [
  jdbc_driver_path: path
  jdbc_driver_class: string
  conn_url: string
  conn_user: string
  conn_pass: string
  --sql:string
  --sql-file:path
] {
  let sqlline_path = setup
  let class_path = $sqlline_path | append $jdbc_driver_path | str join ':'

  ( java -cp $class_path sqlline.SqlLine
    --fastConnect=true
    --outputformat=csv
    -d $jdbc_driver_class
    -u $conn_url
    -n $conn_user
    -p $conn_pass
    ...(if ($sql | is-not-empty ) { [-e $sql ] })
    ...(if ($sql_file | is-not-empty ) { [-f $sql_file ] })
  )
}

# def main [] {
#   sqlline a b x y z --sql-file abc
# }
