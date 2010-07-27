#!/bin/bash

DIR=$(readlink -f $(dirname $0))

usage() {
echo <<-EOF

  $0 [options]

  -d driver name (mysql or postgresql)
  -n number of runs
  -r number of records to create
  -h this message

EOF
}

DRIVER='postgresql'
ITER=5
ROWS=500

while getopts "d:n:r:h" OPTION
do
  case $OPTION in
    d) DRIVER=$OPTARG;;
    n) ITER=$OPTARG;;
    r) ROWS=$OPTARG;;
    h) usage; exit 0;;
    *) usage; exit 1;;
  esac
done

echo ""
echo "-- driver: $DRIVER rows: $ROWS runs: $ITER --"
echo ""

$DIR/dm.rb    $DRIVER $ROWS $ITER
$DIR/ar.rb    $DRIVER $ROWS $ITER
$DIR/swift.rb $DRIVER $ROWS $ITER
