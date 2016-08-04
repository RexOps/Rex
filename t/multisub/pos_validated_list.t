use Test::More tests => 2;

use Rex::MultiSub::PosValidatedList;

my $sub = Rex::MultiSub::PosValidatedList->new(
  name     => "testfunc",
  function => sub {
    my ($name) = @_;
    return $name;
  },
  params_list => [
    name => { isa => 'Str' },
  ],
);
$sub->export("main");

my $sub2 = Rex::MultiSub::PosValidatedList->new(
  name     => "testfunc",
  function => sub {
    my ( $name, $age ) = @_;
    return $name . "=" . $age;
  },
  params_list => [
    name => { isa => 'Str' },
    age  => { isa => 'Int' },
  ],
);
$sub2->export("main");

is( testfunc("rex"), "rex", "called function with name key" );
is( testfunc( "rex", 5 ), "rex=5", "called function with name and age key" );

