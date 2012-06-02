use strict;
use warnings;

BEGIN {
   use Test::More tests => 8;

   use_ok 'Rex::Shared::Var';
   Rex::Shared::Var->import;

   share(qw($scalar @array %hash));
}

$scalar = "scalar";
ok($scalar eq "scalar", "scalar test");

@array = qw(one two three four);
ok(join("-", @array) eq "one-two-three-four", "array test");

%hash = (
   name => "joe",
   surename => "doe",
   multi => {
      key1 => "foo",
      arr1 => [
         qw/bar baz/
      ],
   }
);

ok($hash{name} eq "joe", "hash test, key 1");
ok($hash{surename} eq "doe", "hash test, key 2");
ok($hash{multi}->{key1} eq "foo", "multidimension, key1");
ok($hash{multi}->{arr1}->[0] eq "bar", "multidimension, arr1 - key0");
ok($hash{multi}->{arr1}->[1] eq "baz", "multidimension, arr1 - key1");

unlink("vars.db");
unlink("vars.db.lock");

