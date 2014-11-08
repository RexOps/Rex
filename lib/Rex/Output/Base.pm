#
# (c) Nathan Abu <aloha2004@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Output::Base;

use strict;
use warnings;

sub write { die "Must be implemented by inheriting class" }
sub add   { die "Must be implemented by inheriting class" }
sub error { die "Must be implemented by inheriting class" }

1;
