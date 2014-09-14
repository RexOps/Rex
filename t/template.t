use strict;
use warnings;

use Test::More tests => 20;
use_ok 'Rex::Template';
use_ok 'Rex::Config';

my $t = Rex::Template->new;

my $content = 'one two three';

ok( $t->parse( $content, {} ) eq "one two three", "just text" );

$content = 'Hello this is <%= $::name %>';
ok( $t->parse( $content, { name => "foo" } ) eq "Hello this is foo",
  "simple variable" );

$content = '<% if($::logged_in) { %>
Logged in!
<% } else { %>
Logged out!
<% } %>';

my $content_ok = "
Logged in!
";

ok( $t->parse( $content, { logged_in => 1 } ) eq $content_ok, "if condition" );

$content = 'Hello this is <%= $::name %>';
ok(
  Rex::Config->get_template_function()->( $content, { name => "baz" } ) eq
    "Hello this is baz",
  "get template function"
);

ok( $t->parse( $content, name => "bar" ) eq "Hello this is bar",
  "simple variable without hashRef" );

$Rex::Template::BE_LOCAL = 1;
$Rex::Template::BE_LOCAL = 1;

$content = 'Hello this is <%= $foo %>';
ok( $t->parse( $content, { foo => "baz" } ) eq "Hello this is baz",
  "local vars" );

$content = '<%= join(",", @{ $arr }) %>';
ok( $t->parse( $content, { arr => [qw/one two three/] } ) eq "one,two,three",
  "local var with array" );

#
# old variable style
#

$content = 'one two three';

ok( $t->parse( $content, {} ) eq "one two three", "just text" );

$content = 'Hello this is <%= $::name %>';
ok( $t->parse( $content, { name => "foo" } ) eq "Hello this is foo",
  "simple variable" );

$content = '<% if($::logged_in) { %>
Logged in!
<% } else { %>
Logged out!
<% } %>';

$content_ok = "
Logged in!
";

ok( $t->parse( $content, { logged_in => 1 } ) eq $content_ok, "if condition" );

$content = 'Hello this is <%= $::name %>';
ok(
  Rex::Config->get_template_function()->( $content, { name => "baz" } ) eq
    "Hello this is baz",
  "get template function"
);

ok( $t->parse( $content, name => "bar" ) eq "Hello this is bar",
  "simple variable without hashRef" );

$content = 'Hello this is <%= $::foo %> <%= $::veth1_0_ip %>';
ok(
  $t->parse( $content, { foo => "baz", "veth1.0_ip" => "10.1.2.3" } ) eq
    "Hello this is baz 10.1.2.3",
  "template with invalid key name"
);

my $v = {
  "foo"      => { val => "val1", name => "foo" },
  "foo_bar"  => { val => "val2", name => "foo_bar" },
  "k-ey"     => { val => "val3", name => "k_ey" },
  "veth0.1"  => { val => "val4", name => "veth0_1" },
  "2nd\\key" => { val => "val5", name => "2nd_key" },
};

for my $key ( keys %{$v} ) {
  my $var_name = Rex::Template::_normalize_var_name($key);
  ok( $var_name eq $v->{$key}->{name},
    "$var_name is equal to " . $v->{$key}->{name} );
}

