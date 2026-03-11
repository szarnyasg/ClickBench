#!/bin/bash

set -euo pipefail

# Install
export HOME=${HOME:=~}
curl https://install.duckdb.org | sh
export PATH=$HOME'/.duckdb/cli/latest':$PATH

if [ "$(uname)" == "Darwin" ]; then
    # macOS
    TIME_COMMAND="command gtime -f '%e'"
    GREP_COMMAND="ggrep"
    SED_COMMAND="gsed"
    # trigger the sudo password prompt
    sudo ls
else
    # Linux
    TIME_COMMAND="command time -f '%e'"
    GREP_COMMAND="grep"
    SED_COMMAND="sed"
fi

# Load the data
wget --continue --progress=dot:giga 'https://datasets.clickhouse.com/hits_compatible/hits.parquet'

echo -n "Load time: "
${TIME_COMMAND} duckdb hits.db -storage_version latest -f create.sql -f load.sql

# Run the queries

./run.sh 2>&1 | tee log.txt

echo -n "Data size: "
wc -c hits.db

cat log.txt |
  ${GREP_COMMAND} -P '^\d|Killed|Segmentation|^Run Time \(s\): real' |
  ${SED_COMMAND} -r -e 's/^.*(Killed|Segmentation).*$/null\nnull\nnull/; s/^Run Time \(s\): real\s*([0-9.]+).*$/\1/' |
  awk '{ if (i % 3 == 0) { printf "[" }; printf $1; if (i % 3 != 2) { printf "," } else { print "]," }; ++i; }'
