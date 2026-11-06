const sqlline_path_default = '~/.local/share/sqlline/'

def setup_sqlline [--sqlline-path:path --update] {
  let maven_root = 'https://repo1.maven.org/maven2/sqlline/sqlline'
  let maven_meta = 'maven-metadata.xml'

  let sqlline_path = $sqlline_path | default $sqlline_path_default | path expand
  mkdir $sqlline_path
  cd $sqlline_path

  if ( not ( $maven_meta | path exists ) or $update) {
    print "sqlline: updating information"
    http get $"($maven_root)/($maven_meta)" | save -f $maven_meta
  }

  let version = open $maven_meta | get content
  | where tag == versioning | get content.0
  | where tag == release | get content.0.content.0

  let jar_name = $"sqlline-($version)-jar-with-dependencies.jar"

  if not ($jar_name | path exists) {
    print $"sqlline: downloading release ($version)"
    http get $"($maven_root)/($version)/($jar_name)"
    | save --raw $jar_name --progress
  } # else { print "already downloaded" }

  $jar_name | path expand
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
  let sqlline_path = setup_sqlline
  let jdbc_driver_path = $jdbc_driver_path | path expand
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
#   setup_sqlline
#   # sqlline a b x y z --sql-file abc
# }
