#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Test;

use Rex -base;
use Data::Dumper;
use Rex::Commands::Box;

desc 'Run tests specified with --test=testfile (default: t/*.t)';
task run => make {
  Rex::Logger::info("Running integration tests...");

  my $parameters = shift;
  my @files;

  LOCAL {
    @files =
      defined $parameters->{test} ? glob( $parameters->{test} ) : glob('t/*.t');
  };

  for my $file (@files) {
    Rex::Logger::info("Running test: $file.");
    do "$file";
    Rex::Logger::info( "Error running $file: $@", "error" ) if $@;
  }
};

1;
