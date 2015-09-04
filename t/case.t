use Test::More tests => 7;
use Rex::Commands;

my $test = "Debian";

my $var = case $test, {
  Debian    => "foo",
    default => "bar",
};

is( $var, "foo", "string equality" );

$var = case $test, {
  qr{debian}i => "baz",
    default   => "this is bad",
};

is( $var, "baz", "regexp match" );

$var = case $test, {
  debian    => "some",
    default => "this is good",
};

is( $var, "this is good", "return default" );

$var = case $test, {
  debian => "tata",
};

ok( !$var, "var is undef" );

$var = case $test, {
  Debian    => sub { return "this is debian"; },
    default => sub { return "default"; }
};

is( $var, "this is debian", "use a sub - string match" );

$var = undef;

$var = case $test, {
  qr{debian}i => sub { return "this is debian"; },
    default   => sub { return "default"; }
};

is( $var, "this is debian", "use a sub - regexp match" );

$var = undef;

$var = case $test, {
  debian    => sub { return "this is debian"; },
    default => sub { return "default"; }
};

is( $var, "default", "use a sub - return default" );
