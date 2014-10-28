use strict;
use warnings;

use Test::More tests => 9;
use File::Basename;
use Cwd 'getcwd';

use_ok 'Rex::Helper::Path';

my $path =
  Rex::Helper::Path::get_file_path( "files/foo.txt", "main", "Rexfile" );
ok( $path eq "./files/foo.txt", "got file path if called from Rexfile" );

my $cwd = getcwd;
$path = Rex::Helper::Path::get_file_path( "$cwd/ChangeLog", "main", "Rexfile" );
ok( $path eq "$cwd/ChangeLog",
  "got file path if called from Rexfile - absolute path" );

$path = Rex::Helper::Path::get_file_path( "files/foo.txt", "main",
  "this/is/Rexfile" );
ok( $path eq "this/is/files/foo.txt",
  "got file path if called Rexfile from other directory" );

$path = Rex::Helper::Path::get_file_path( "files/foo.txt", "main",
  "/this/is/Rexfile" );
ok( $path eq "/this/is/files/foo.txt",
  "got file path if called Rexfile from other directory (absolute)" );

$path = Rex::Helper::Path::get_file_path( "files/foo.txt", "File::Foo",
  "lib/File/Foo/__module__.pm" );
ok(
  $path eq "lib/File/Foo/files/foo.txt",
  "got file path for File::Foo module"
);

$path = Rex::Helper::Path::get_tmp_file();
my ( $filename, $directory, $suffix ) = fileparse( $path, '.tmp' );

ok( defined $filename, 'Got temp filename' );
is( $suffix, '.tmp', 'Got filename with .tmp suffix' );
ok( defined $directory, 'Got temp directory' );
