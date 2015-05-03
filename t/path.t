use Test::More;

use Rex::Helper::Path;

my $path = Rex::Helper::Path::resolv_path( "/home/foo/bar/baz", 1 );
is( $path, "/home/foo/bar/baz", "local test absolute path" );

if ( $^O !~ m/^MSWin/ ) {
  $path = Rex::Helper::Path::resolv_path( "~/bar/baz", 1 );
  like( $path, qr{^/}, "expanded \$HOME" );

  $path = Rex::Helper::Path::resolv_path("~/bar/baz");
  like( $path, qr{^/}, "expanded \$HOME - no local" );
}

done_testing();
