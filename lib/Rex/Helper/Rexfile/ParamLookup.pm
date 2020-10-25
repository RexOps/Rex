#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Helper::Rexfile::ParamLookup;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Devel::Caller;
use Data::Dumper;
require Rex::Exporter;
require Rex::Commands;

use base qw(Rex::Exporter);
use vars qw (@EXPORT);

@EXPORT = qw(param_lookup);

sub param_lookup {
  my ( $key, $default ) = @_;

  my $ret;

  my ($caller_pkg) = caller(0);

  my @args = Devel::Caller::caller_args(1);
  if ( ref $args[0] eq "HASH" ) {
    if ( exists $args[0]->{$key} ) {
      $ret = $args[0]->{$key};
    }
  }

  if ( !$ret ) {

    # check if cmdb is loaded
    my ($use_cmdb) = grep { m/CMDB\.pm/ } keys %INC;
    if ($use_cmdb) {

      # look inside cmdb
      my $cmdb_key = "${caller_pkg}::$key";
      $ret = Rex::Commands::get( Rex::CMDB::cmdb($cmdb_key) );

      if ( !$ret ) {

        # check in resource
        if ( Rex::Resource->is_inside_resource ) {
          $cmdb_key =
            Rex::Resource->get_current_resource->display_name . "::$key";
          $ret = Rex::Commands::get( Rex::CMDB::cmdb($cmdb_key) );
        }

        if ( !$ret ) {

          # check in task
          my $task = Rex::Commands::task();
          if ($task) {
            my $task_name = $task->{name};
            $task_name =~ s/:/::/;
            $cmdb_key = $task_name . "::$key";
            $ret      = Rex::Commands::get( Rex::CMDB::cmdb($cmdb_key) );
          }
        }
      }

      if ( !$ret ) {

        # check in global namespace
        $ret = Rex::Commands::get( Rex::CMDB::cmdb($key) );
      }
    }
  }

  if ( !$ret ) {
    $ret = $default;
  }

  if ( Rex::Resource->is_inside_resource ) {
    Rex::Resource->get_current_resource()->set_parameter( $key => $ret );
  }

  if ( !Rex::Resource->is_inside_resource ) {
    Rex::Commands::task()->set_opt( $key => $ret );
  }

  return $ret;
}

1;

=pod

=head1 NAME

Rex::Helper::Rexfile::ParamLookup - A command to manage task parameters.

A command to manage task parameters. Additionally it register the parameters as template values.

This module also looks inside a CMDB (if present) for a valid key.


=head1 SYNOPSIS

 task "setup", sub {
   my $var = param_lookup "param_name", "default_value";
 };

=head1 LOOKUP

First I<param_lookup> checks the task parameters for a valid parameter. If none is found and if a CMDB is used, it will look inside the cmdb.

If your module is named "Rex::NTP" than it will first look if the key "Rex::NTP::param_name" exists. If it doesn't exists it checks for the key "param_name".

=cut
