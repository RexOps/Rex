use Test::More;
use Test::PerlTidy;

if ($ENV{CI} && $ENV{TRAVIS}) {
   plan skip_all => q{perltidy tests don't work on TravisCI yet};
}

run_tests(
  exclude => [
    'Makefile.PL', '.build/', 'blib/', 'misc/', qr{t/(author|release)-.*\.t}
  ],
);
