use strict;
use warnings;

use Test::More tests => 21;
use Rex::Template::NG;
use Rex::Commands;
use Rex::Config;

my $t = Rex::Template::NG->new;

my $content = 'one two three';

is( $t->parse( $content, {} ), "one two three", "just text" );

$content = '{
1
}';

my $content_ok = '{
1
}';

is( $t->parse( $content, {} ), $content_ok, "curly braces" );

$content = 'Hello this is <%= $::name %>';
is(
  $t->parse( $content, { name => "foo" } ),
  "Hello this is foo",
  "simple variable"
);

$content = 'Hello this is <%=$::name%>';
is(
  $t->parse( $content, { name => "bar" } ),
  "Hello this is bar",
  "simple variable - no spaces around tag"
);

$content = '<% if($::logged_in) { %>
Logged in!
<% } else { %>
Logged out!
<% } %>';

$content_ok = "
Logged in!
";

is( $t->parse( $content, { logged_in => 1 } ), $content_ok, "if condition" );

$content = 'Hello this is <%= $::name %>';
is(
  Rex::Config->get_template_function()->( $content, { name => "baz" } ),
  "Hello this is baz",
  "get template function"
);

is(
  $t->parse( $content, name => "bar" ),
  "Hello this is bar",
  "simple variable without hashRef"
);

$Rex::Template::BE_LOCAL = 1;
$Rex::Template::BE_LOCAL = 1;

$content = 'Hello this is <%= $foo %>';
is( $t->parse( $content, { foo => "baz" } ), "Hello this is baz",
  "local vars" );

$content = '<%= join(",", @{ $arr }) %>';
is( $t->parse( $content, { arr => [qw/one two three/] } ),
  "one,two,three", "local var with array" );

$content = 'This is a false value: <%= $value %>';

$content_ok = 'This is a false value: 0';

is( $t->parse( $content, value => 0 ), $content_ok, 'false value passed' );

#
# old variable style
#

$content = 'one two three';

is( $t->parse( $content, {} ), "one two three", "just text" );

$content = 'Hello this is <%= $::name %>';
is(
  $t->parse( $content, { name => "foo" } ),
  "Hello this is foo",
  "simple variable"
);

$content = '<% if($::logged_in) { %>
Logged in!
<% } else { %>
Logged out!
<% } %>';

$content_ok = "
Logged in!
";

is( $t->parse( $content, { logged_in => 1 } ), $content_ok, "if condition" );

$content = 'Hello this is <%= $::name %>';
is(
  Rex::Config->get_template_function()->( $content, { name => "baz" } ),
  "Hello this is baz",
  "get template function"
);

is(
  $t->parse( $content, name => "bar" ),
  "Hello this is bar",
  "simple variable without hashRef"
);

$content = 'Hello this is <%= $::foo %> <%= $::veth1_0_ip %>';
is(
  $t->parse( $content, { foo => "baz", "veth1.0_ip" => "10.1.2.3" } ),
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
  is(
    $var_name,
    $v->{$key}->{name},
    "$var_name is equal to " . $v->{$key}->{name}
  );
}

