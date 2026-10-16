#
# (c) Jan Gehring <jan.gehring@gmail.com>
# Adapted for doas support by Rafael Medina <rafael@medina.me>
#

package Rex::Interface::File::Doas;

use v5.14.4;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use base qw(Rex::Interface::File::Sudo);

sub _fs {
  return Rex::Interface::Fs->create('Doas');
}

1;
