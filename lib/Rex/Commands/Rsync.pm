#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Rsync;

use strict;
use warnings;

require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(sync_down sync_up);


sub sync_down {
   my ($source, $dest, $opts) = @_;

}

sub sync_up {
   my ($source, $dest) = @_;
}


1;
