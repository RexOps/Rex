use Test::More tests => 2;

use Rex::MultiSub::ValidatedHash;

my $sub = Rex::MultiSub::ValidatedHash->new(
  name     => "testfunc",
  function => sub {
    my (%x) = @_;
    return $x{name};
  },
  params_list => [
    name => { isa => 'Str' },
  ],
);
$sub->export("main");

my $sub2 = Rex::MultiSub::ValidatedHash->new(
  name     => "testfunc",
  function => sub {
    my (%x) = @_;
    return $x{name} . "=" . $x{age};
  },
  params_list => [
    name => { isa => 'Str' },
    age  => { isa => 'Int' },
  ],
);
$sub2->export("main");

is( testfunc( name => "rex" ), "rex", "called function with name key" );
is( testfunc( name => "rex", age => 5 ),
  "rex=5", "called function with name and age key" );

