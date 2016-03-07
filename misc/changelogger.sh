#!/bin/sh

changelog="ChangeLog"
tmp_file="changelog.tmp"
date=`date +%Y-%m-%d`

release_manager=$1
email=$2
version=$3
lasttag=$4

:${lasttag:=`git tag --sort=-v:refname | head -n1`}

firstline="$date $release_manager <$email> ($version)"

git checkout $changelog

echo $firstline > $tmp_file
git log --format='  * %s - %an' $lasttag..HEAD \
    | grep -Piv 'Merge pull request' \
    | grep -Piv 'Merge (remote-tracking )?branch' \
    | grep -Piv 'merged - ' \
    | grep -Piv 'perl ?tidy - ' \
    | grep -Piv 'tidying code - ' \
    | grep -Piv 'Update list of contributors' \
    | grep -Piv 'version bump - ' \
    | grep -Piv 'bump version - ' \
    | grep -Piv 'updated? (changelog(ger)?|version)' \
    >> $tmp_file
echo >> $tmp_file
cat $changelog >> $tmp_file
mv $tmp_file $changelog

$EDITOR $changelog
