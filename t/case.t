BEGIN {
   use Test::More tests => 8;
   use_ok 'Rex::Commands';
   Rex::Commands->import;
};

my $test = "Debian";

my $var = case $test, {
             Debian  => "foo",
             default => "bar",
          };

ok($var eq "foo", "string equality");


$var = case $test, {
          qr{debian}i => "baz",
          default     => "this is bad",
       };

ok($var eq "baz", "regexp match");

$var = case $test, {
          debian => "some",
          default => "this is good",
       };

ok($var eq "this is good", "return default");

$var = case $test, {
          debian => "tata",
       };

ok(! $var, "var is undef");

$var = case $test, {
          Debian => sub { return "this is debian"; },
          default => sub { return "default"; }
       };

ok($var eq "this is debian", "use a sub - string match");

$var = undef;

$var = case $test, {
          qr{debian}i => sub { return "this is debian"; },
          default => sub { return "default"; }
       };

ok($var eq "this is debian", "use a sub - regexp match");

$var = undef;

$var = case $test, {
          debian  => sub { return "this is debian"; },
          default => sub { return "default"; }
       };

ok($var eq "default", "use a sub - return default");


