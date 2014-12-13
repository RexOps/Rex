use Test::PerlTidy;

run_tests(
  exclude => [
    'Makefile.PL', '.build/', 'blib/', 'misc/', qr{t/(author|release)-.*\.t}
  ],
);
