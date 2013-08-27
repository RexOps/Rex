use strict;
use warnings;

use Test::More tests => 7;
use Cwd 'getcwd';

use_ok 'Rex::Helper::Path';

$::rexfile = "Rexfile"; $::rexfile = "Rexfile";

my $path = Rex::Helper::Path::get_file_path("files/foo.txt", "main", "Rexfile");
ok($path eq "files/foo.txt", "got file path if called from Rexfile");

my $cwd = getcwd;
$path = Rex::Helper::Path::get_file_path("$cwd/Makefile.PL", "main", "Rexfile");
ok($path eq "$cwd/Makefile.PL", "got file path if called from Rexfile - absolute path");

$path = Rex::Helper::Path::get_file_path("files/foo.txt", "main", "this/is/Rexfile");
ok($path eq "this/is/files/foo.txt", "got file path if called Rexfile from other directory");

print STDERR "\n\npath: $path\n\n";

$path = Rex::Helper::Path::get_file_path("files/foo.txt", "main", "/this/is/Rexfile");
ok($path eq "/this/is/files/foo.txt", "got file path if called Rexfile from other directory (absolute)");

$path = Rex::Helper::Path::get_file_path("files/foo.txt", "File::Foo", "lib/File/Foo/__module__.pm");
ok($path eq "lib/File/Foo/files/foo.txt", "got file path for File::Foo module");

$path = Rex::Helper::Path::get_tmp_file();
if($^O =~ m/^MSWin/) {
   ok($path =~ m/c:\//i, "found windows directory");
}
else {
   ok($path =~ m/^\/tmp/);
}
