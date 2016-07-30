#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Function::Common;

use strict;
use warnings;

# VERSION

require Exporter;
require Rex::Config;
use Data::Dumper;
use base qw(Exporter);
use vars qw(@EXPORT);
use MooseX::Params::Validate;

@EXPORT = qw(function);

my $__lookup_table;

sub function {
  my ( $name, $options, $function ) = @_;
  my $name_save = $name;

  my $caller_pkg = caller;

  if ( ref $options eq "CODE" ) {
    $function = $options;
    $options  = {};
  }

  $options->{name_idx} //= 0;
  $options->{params_list} //= [ name => { isa => 'Str' }, ];

  my $app = Rex->instance;

  push @{ $__lookup_table->{$name} },
    {
    options => $options,
    code    => $function,
    };

  # TODO add dry run
  # TODO add reporting
  my $func = sub {
    $app->output->print_s(
      { title => $name, msg => $_[ $options->{name_idx} ] } );
    my $ret = {};
    eval {
      my $found = 0;
      for my $f (
        sort {
          scalar( @{ $b->{options}->{params_list} } ) <=>
            scalar( @{ $a->{options}->{params_list} } )
        } @{ $__lookup_table->{$name} }
        )
      {
        my @args;
        eval {
          my @_x = @{ $f->{options}->{params_list} };
          my @order = map { $_x[$_] } grep { $_ & 1 } 1 .. $#_x;

          @args = pos_validated_list(
            \@_, @order,
            MX_PARAMS_VALIDATE_NO_CACHE    => 1,
            MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1
          );

          # get only the checked parameter inside @args array.
          @args = splice( @args, 0, scalar(@order) );

          $found = 1;
          1;
        } or do {

          # TODO catch no "X parameter was given" errors
          next;
        };

        my @rest_args = splice( @_, scalar(@args), scalar(@_) );
        if ( scalar(@rest_args) % 2 != 0 ) {
          die "Wrong number of arguments for $name function.";
        }
        my %arg_options = @rest_args;

        # TODO check for common parameters like
        # * timeout
        # * only_notified
        # * only_if
        # * unless
        # * creates

        $ret = $f->{code}->( $app, @args, %arg_options );
        last;
      }
      if ( !$found ) {
        die "Function $name for provided parameter not found.";
      }
      $app->output->endln_ok();
      1;
    } or do {
      $app->output->endln_failed();
      die "Error running command: $name.\nError: $@\n";
    };

    if (wantarray) {
      return split( /\r?\n/, $ret->{value} );
    }

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
