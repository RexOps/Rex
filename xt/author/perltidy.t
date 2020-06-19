use strict;
use warnings;

use Test::More;
use Test::PerlTidy;

plan skip_all => 'these tests are for testing by the author'
  unless $ENV{AUTHOR_TESTING};

plan tests => 2;

subtest 'files in bin', sub {
  my @bin_files = glob('bin/*');

  plan tests => scalar @bin_files;

  for my $file (@bin_files) {
    ok( Test::PerlTidy::is_file_tidy($file), "$file is tidy" );
  }
};

subtest 'standard files', sub {
  run_tests(
    exclude => [
      'Makefile.PL',                  '.build/',
      'blib/',                        'misc/',
      qr{xt/author/(?!perltidy\.t$)}, qr{xt/release/},
    ],
  );
};
