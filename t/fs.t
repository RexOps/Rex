use strict;
use warnings;

use Test::More tests => 1;

use Rex::Commands::Fs;

my $fake_file = "file_that_does_not_exist";
eval { Rex::Commands::Fs::stat($fake_file); };
my $err = $@;
like(
  $err,
  qr/^Can't stat $fake_file/,
  "Trying to stat a non-existent file throws an exception"
);
