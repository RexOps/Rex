#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Constants;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(present absent latest running started stopped);

sub present { return "present"; }
sub absent  { return "absent"; }
sub latest  { return "latest"; }
sub running { return "running"; }
sub started { return "started"; }
sub stopped { return "stopped"; }

1;
