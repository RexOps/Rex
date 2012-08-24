use strict;
use warnings;

use Test::More tests => 6;
use_ok 'Rex::Template';
use_ok 'Rex::Config';

my $t = Rex::Template->new;

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


