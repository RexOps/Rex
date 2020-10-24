#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Constants;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(present absent latest running started stopped);

sub present { return "present"; }
sub absent  { return "absent"; }
sub latest  { return "latest"; }
sub running { return "running"; }
sub started { return "started"; }
sub stopped { return "stopped"; }

1;
