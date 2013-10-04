use Test::More;

use_ok 'Rex::Helper::Path';

my $path = Rex::Helper::Path::resolv_path("/home/foo/bar/baz", 1);
ok($path eq "/home/foo/bar/baz", "local test absolute path");

if($^O !~ m/^MSWin/) {
   $path = Rex::Helper::Path::resolv_path("~/bar/baz", 1);
   ok($path =~ m/^\//, "expanded \$HOME");

   $path = Rex::Helper::Path::resolv_path("~/bar/baz");
   ok($path =~ m/^\//, "expanded \$HOME - no local");
}

done_testing();
