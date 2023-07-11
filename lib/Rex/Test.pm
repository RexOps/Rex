#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Test;

use v5.12.5;
use warnings;
use Rex -base;
use Data::Dumper;
use Rex::Commands::Box;
require Rex::CLI;

our $VERSION = '9999.99.99_99'; # VERSION

BEGIN {
  use Rex::Shared::Var;
  share qw(@exit);
}

Rex::CLI->add_exit(
  sub {
    if ( scalar @exit > 0 ) {
      CORE::exit(1);
    }
  }
);

sub push_exit {
  push @exit, shift;
}

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
    do "./$file";
    Rex::Logger::info( "Error running $file: $@", "error" ) if $@;
  }
};

1;
