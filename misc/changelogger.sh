#!/bin/sh

changelog="ChangeLog"
tmp_file="changelog.tmp"
lasttag=`git tag --sort=-v:refname | head -n1`
date=`date +%Y-%m-%d`

release_manager=$1
email=$2
version=$3

firstline="$date $release_manager <$email> ($version)"

git checkout $changelog

echo $firstline > $tmp_file
git log --format='  * %s - %an' $lasttag..HEAD \
    | grep -Piv 'Merge pull request' \
    | grep -Piv 'perltidy' \
    | grep -Piv 'Update list of contributors' \
    | grep -Piv 'version bump' \
    | grep -Piv 'updated? (changelog|version)' \
    >> $tmp_file
echo >> $tmp_file
cat $changelog >> $tmp_file
mv $tmp_file $changelog

$EDITOR $changelog
