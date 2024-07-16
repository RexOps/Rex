#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Constants;

use v5.12.5;
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
