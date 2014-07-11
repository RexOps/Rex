use Test::More tests => 2;

use_ok 'Rex::Helper::Encode';

my $input =
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#+~*`´!\"§\$%&/()=?\\|<>,.-_'^°";
my $output =
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789%23%2B%7E%2A%60%C2%B4%21%22%C2%A7%24%25%26%2F%28%29%3D%3F%5C%7C%3C%3E%2C%2E%2D_%27%5E%C2%B0";

ok( Rex::Helper::Encode::url_encode($input) eq $output,
  "encode everything except a-z0-9_" );

