#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Command::Common;

use strict;
use warnings;

# VERSION

require Exporter;
require Rex::Config;
use Data::Dumper;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(function);

sub function {
  my ( $name, $options, $function ) = @_;
  my $name_save = $name;

  my $caller_pkg = caller;

  if ( ref $options eq "CODE" ) {
    $function = $options;
    $options  = {};
  }
  
  $options->{name_idx} //= 0;
  
  my $app = Rex->instance;

  # TODO add dry run
  # TODO add reporting
  my $func = sub {
    $app->output->print_s({title => $name, msg => $_[$options->{name_idx}]});
    my $ret;
    eval {
      $ret = $function->($app, @_);
      $app->output->endln_ok();
      1;
    } or do {
      $app->output->endln_failed();
      die "Error running command: $name.\nError: $@\n";
    };

    return $ret->{value};
  };

  if ( $name_save !~ m/^[a-zA-Z_][a-zA-Z0-9_]+$/ ) {
    Rex::Logger::info(
      "Please use only the following characters for function names:", "warn" );
    Rex::Logger::info( "  A-Z, a-z, 0-9 and _", "warn" );
    Rex::Logger::info( "Also the function should start with A-Z or a-z",
      "warn" );
    die "Wrong function name syntax.";
  }

  my ( $class, $file, @tmp ) = caller;

  if (!$class->can($name)
    && $name_save =~ m/^[a-zA-Z_][a-zA-Z0-9_]+$/ )
  {
    no strict 'refs';
    Rex::Logger::debug("Registering resource: ${class}::$name_save");

    my $code = $_[-2];
    *{"${class}::$name_save"} = $func;
    use strict;
  }
  elsif ( ( $class ne "main" && $class ne "Rex::CLI" )
    && !$class->can($name_save)
    && $name_save =~ m/^[a-zA-Z_][a-zA-Z0-9_]+$/ )
  {
    # if not in main namespace, register the function as a sub
    no strict 'refs';
    Rex::Logger::debug(
      "Registering function (not main namespace): ${class}::$name_save");
    my $code = $_[-2];
    *{"${class}::$name_save"} = $func;

    use strict;
  }

  if ( exists $options->{export} && $options->{export} ) {
    no strict 'refs';

    # register in caller namespace
    push @{ $caller_pkg . "::ISA" }, "Rex::Exporter"
      unless ( grep { $_ eq "Rex::Exporter" } @{ $caller_pkg . "::ISA" } );
    push @{ $caller_pkg . "::EXPORT" }, $name_save;
    use strict;
  }
}

1;
