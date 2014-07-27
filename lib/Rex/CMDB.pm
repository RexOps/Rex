#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::CMDB;

use strict;
use warnings;

use Rex::Commands;
use Rex::Value;

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(cmdb);

my $CMDB_PROVIDER;

Rex::Config->register_set_handler(
  "cmdb" => sub {
    my ($option) = @_;
    $CMDB_PROVIDER = $option;
  }
);

=item cmdb([$item, $server])

Function to query a CMDB. If this function is called without $item it should return a hash containing all the information for the requested server. If $item is given it should return only the value for $item.

 task "prepare", "server1", sub {
   my $virtual_host = cmdb("vhost");
   my %all_information = cmdb;
 };

=cut

sub cmdb {
  my ( $item, $server ) = @_;
  $server ||= connection->server;

  my $klass = $CMDB_PROVIDER->{type};
  if ( $klass !~ m/::/ ) {
    $klass = "Rex::CMDB::$klass";
  }

  eval "use $klass";
  if ($@) {
    die("CMDB provider ($klass) not found: $@");
  }

  my $cmdb = $klass->new( %{$CMDB_PROVIDER} );
  return Rex::Value->new( value => $cmdb->get( $item, $server ) );
}

1;
