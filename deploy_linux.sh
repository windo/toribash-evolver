#!/bin/sh

HERE=$(basename $(readlink -f $0))

DEST=$1; shift
[ -z "$DEST" ] && echo "Usage: $0 <toribash dir>" && exit 1
! [ -d "$DEST/data/script" ] && echo "Directory $DEST/data/script does not exist"

# remove old files
for f in $(cat $DEST/data/script/evolve/files.txt 2> /dev/null); do
	rm -f $DEST/data/script/$f
done

# deploy new files
if [ "$1" != "clean" ]; then
	mkdir -p $DEST/data/script/evolve/data
	find src -type f -not -wholename 'src/evolve/data/*' | sed -e 's#^src/##' > $DEST/data/script/evolve/files.txt
	cat $DEST/data/script/evolve/files.txt | while read FILE; do
		cp src/$FILE $DEST/data/script/$FILE
	done
fi
