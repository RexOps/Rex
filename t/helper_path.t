use strict;
use warnings;

use Test::More tests => 8;

use File::Basename;
use Cwd 'getcwd';
use Rex::Helper::Path;

my $rexfile  = "Rexfile";
my $file     = Rex::Helper::File::Spec->join( "files", "foo.txt" );
my $path     = Rex::Helper::Path::get_file_path( $file, "main", $rexfile );
my $expected = $file;

is( $path, $expected, "got file path if called from Rexfile" );

my $cwd = getcwd;
$file     = Rex::Helper::File::Spec->join( $cwd, "ChangeLog" );
$path     = Rex::Helper::Path::get_file_path( $file, "main", $rexfile );
$expected = $file;

is( $path, $file, "got file path if called from Rexfile - absolute path" );

$rexfile  = Rex::Helper::File::Spec->join( "this",  "is", "Rexfile" );
$file     = Rex::Helper::File::Spec->join( "files", "foo.txt" );
$path     = Rex::Helper::Path::get_file_path( $file, "main", $rexfile );
$expected = Rex::Helper::File::Spec->join( "this", "is", "files", "foo.txt" );

is( $path, $expected, "got file path if called Rexfile from other directory" );

$rexfile = Rex::Helper::File::Spec->join( Rex::Helper::File::Spec->rootdir(),
  "this", "is", "Rexfile" );
$file     = Rex::Helper::File::Spec->join( "files", "foo.txt" );
$path     = Rex::Helper::Path::get_file_path( $file, "main", $rexfile );
$expected = Rex::Helper::File::Spec->join( Rex::Helper::File::Spec->rootdir(),
  "this", "is", "files", "foo.txt" );

is( $path, $expected,
  "got file path if called Rexfile from other directory (absolute)" );

my $module_path =
  Rex::Helper::File::Spec->join( "lib", "File", "Foo", "__module__.pm" );
$path = Rex::Helper::Path::get_file_path( $file, "File::Foo", $module_path );
$expected =
  Rex::Helper::File::Spec->join( "lib", "File", "Foo", "files", "foo.txt" );

is( $path, $expected, "got file path for File::Foo module" );

$path = Rex::Helper::Path::get_tmp_file();
my ( $filename, $directory, $suffix ) = fileparse( $path, '.tmp' );

ok( defined $filename, 'Got temp filename' );
is( $suffix, '.tmp', 'Got filename with .tmp suffix' );
ok( defined $directory, 'Got temp directory' );
