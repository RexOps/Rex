use strict;
use warnings;

use Test::More tests => 11;
use_ok 'Rex::Template';
use_ok 'Rex::Config';

my $t = Rex::Template->new;

Rex::Config->set(foo => "bar");

my $content = 'one two three';

ok($t->parse($content, {}) eq "one two three", "just text");

$content = 'Hello this is <%= $::name %>';
ok($t->parse($content, {name => "foo"}) eq "Hello this is foo", "simple variable");

$content = '<% if($::logged_in) { %>
Logged in!
<% } else { %>
Logged out!
<% } %>';

my $content_ok = "
Logged in!
";

ok($t->parse($content, {logged_in => 1}) eq $content_ok, "if condition");

$content = 'Hello this is <%= $::name %>';
ok(Rex::Config->get_template_function()->($content, {name => "baz"}) eq "Hello this is baz", "get template function");

ok($t->parse($content, name => "bar") eq "Hello this is bar", "simple variable without hashRef");

$content = 'Hello this is <%= $::foo %>';
ok($t->parse($content) eq "Hello this is bar", "get keys from Rex::Config");

ok($t->parse($content, {foo => "baz"}) eq "Hello this is baz", "overwrite keys from Rex::Config");

$Rex::Template::BE_LOCAL = 1; $Rex::Template::BE_LOCAL = 1;

$content = 'Hello this is <%= $foo %>';
ok($t->parse($content, {foo => "baz"}) eq "Hello this is baz", "local vars");

$content = '<%= join(",", @{ $arr }) %>';
ok($t->parse($content, {arr => [qw/one two three/]}) eq "one,two,three", "local var with array");

