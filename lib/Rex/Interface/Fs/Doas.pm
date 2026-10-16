#
# (c) Jan Gehring <jan.gehring@gmail.com>
# Adapted for doas support by Rafael Medina <rafael@medina.me>
#

package Rex::Interface::Fs::Doas;

use v5.14.4;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Interface::Exec;
use Rex::Interface::Fs::Sudo;

use base qw(Rex::Interface::Fs::Sudo);

sub _exec {
  my ( $self, $cmd, $path, $option ) = @_;

  my $exec = Rex::Interface::Exec->create('Doas');

  return $exec->exec( $cmd, $path, $option );
}

1;
