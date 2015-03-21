use strict;
use warnings;

use Cwd 'getcwd';
my $cwd = getcwd;

BEGIN {
  use Test::More tests => 57;
  use Data::Dumper;

  use_ok 'Rex';
  use_ok 'Rex::Commands::File';
  use_ok 'Rex::Interface::Exec';
  Rex::Commands::File->import;
  Rex::Interface::Exec;->import;
}

my $tmp_dir = "/tmp";
if ( $^O =~ m/^MSWin/ ) {
  $tmp_dir = $ENV{TMP};
}

my $filename = "${tmp_dir}/test-$$.tgz";
my $to = "myfile_extracted/";

my $exec = Rex::Interface::Exec->create;
my $cmd = "tar cfvz ${filename} /usr/local/bin/";
$exec->exec($cmd);

ok( is_file($filename), "file '${filename}' created" );

extract(
  $filename,
  owner => "root",
  group => "root",
  to    => $to
);

ok( is_dir($to), "file '${filename}' extracted into '${to}'" );

1;
