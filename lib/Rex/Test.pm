#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Test;

use Rex -base;
use Data::Dumper;

task run => make {
  Rex::Logger::info("Running integration tests...");

  my @files;
  LOCAL {
    @files = list_files "t";
  };

  for my $file (@files) {
    Rex::Logger::info("Running test: t/$file.");
    eval { do "t/$file"; 1; } or do { print "Error: $@"; };
  }
};

1;
