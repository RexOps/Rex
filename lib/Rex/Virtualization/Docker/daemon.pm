#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::Docker::daemon;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, %opt ) = @_;

  my $bind = defined $opt{bind} ? $opt{bind} : '0.0.0.0';
  my $host = defined $opt{host} ? $opt{host} : 'unix:///var/run/docker.sock';

  Rex::Logger::debug("starting docker daemon");

  i_run "docker -d -H $host -ip $bind", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error starting docker daemon");
  }

}

1;
