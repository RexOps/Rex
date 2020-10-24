#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Args;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use vars qw(%rex_opts);
use Rex::Logger;
use Data::Dumper;

our $CLEANUP = 1;

sub args_spec {
  return (
    a => {},
    C => {},
    c => {},
    q => {},
    Q => {},
    F => {},
    T => {},
    h => {},
    v => {},
    d => {},
    s => {},
    m => {},
    y => {},
    w => {},
    S => { type => "string" },
    E => { type => "string" },
    o => { type => "string" },
    f => { type => "string" },
    M => { type => "string" },
    b => { type => "string" },
    e => { type => "string" },
    H => { type => "string" },
    u => { type => "string" },
    p => { type => "string" },
    P => { type => "string" },
    K => { type => "string" },
    G => { type => "string" },
    g => { type => "string" },
    z => { type => "string" },
    O => { type => "string" },
    t => { type => "string" },
  );
}

sub parse_rex_opts {
  my ($class) = @_;

  my %args = $class->args_spec;

  #### clean up @ARGV
  my $runner = 0;
  for (@ARGV) {
    if ( /^\-[A-Za-z]+/ && length($_) > 2 && $CLEANUP ) {
      my @args = map { "-$_" } split( //, substr( $_, 1 ) );
      splice( @ARGV, $runner, 1, @args );
    }

    $runner++;
  }

  #### parse rex options
  my @params = @ARGV;
  for my $p (@params) {

    # shift off @ARGV
    my $shift = shift @ARGV;

    if ( length($p) >= 2 && substr( $p, 0, 1 ) eq "-" ) {
      my $name_param = substr( $p, 1, 2 );

      # found a parameter

      if ( exists $args{$name_param} ) {
        Rex::Logger::debug("Option found: $name_param ($p)");
        my $type = "Single";

        if ( exists $args{$name_param}->{type} ) {
          $type = $args{$name_param}->{type};

          Rex::Logger::debug("  is a $type");
          shift @params; # remove the next parameter, because it must be an option

          if (
            !exists $ARGV[0]
            || ( length( $ARGV[0] ) == 2
              && exists $args{ substr( $ARGV[0], 1, 2 ) }
              && substr( $ARGV[0], 0, 1 ) eq "-" )
            )
          {
            # this is a typed parameter without an option!
            Rex::Logger::debug("  but there is no parameter");
            Rex::Logger::debug( Dumper( \@params ) );
            print("No parameter for $name_param\n");
            CORE::exit 1;
          }
        }
        elsif ( exists $args{$name_param}->{func} ) {
          Rex::Logger::debug("  is a function - executing now");
          $args{$name_param}->{func}->();
        }

        my $c = "Rex::Args::\u$type";
        eval "use $c";
        if ($@) {
          die("No Argumentclass $type found!");
        }

        if ( exists $rex_opts{$name_param} && $type eq "Single" ) {
          $rex_opts{$name_param}++;
        }
        else {
          # multiple params defined, create an array
          if ( exists $rex_opts{$name_param} ) {
            if ( !ref $rex_opts{$name_param} ) {
              $rex_opts{$name_param} = [ $rex_opts{$name_param} ];
            }
            push @{ $rex_opts{$name_param} }, $c->get;
          }
          else {
            $rex_opts{$name_param} = $c->get;
          }
        }
      }
      else {
        Rex::Logger::debug("Option not known: $name_param ($p)");
        next;
      }
    }
    else {
      # unshift the last parameter
      unshift @ARGV, $shift;
      last;
    }
  }
}

sub getopts { return %rex_opts; }

sub is_opt {
  my ( $class, $opt ) = @_;
  if ( exists $rex_opts{$opt} ) {
    return $rex_opts{$opt};
  }
}

sub get {
  my ($class) = @_;

  my $task = Rex::TaskList->create->current_task;
  if ($task) {
    return $task->get_opts();
  }
  else {
    return _read_old_way();
  }
}

sub _read_old_way {
  #### parse task options
  my %task_opts;

  for my $p (@ARGV) {
    my ( $key, $val ) = split( /=/, $p, 2 );

    $key =~ s/^--//;

    if ( defined $val ) { $task_opts{$key} = $val; next; }
    $task_opts{$key} = 1;
  }

  return %task_opts;
}

1;
