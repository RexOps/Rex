#
# (c) Nathan Abu <aloha2004@gmail.com>
#

package Rex::Output::Base;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

sub write { die "Must be implemented by inheriting class" }
sub add   { die "Must be implemented by inheriting class" }
sub error { die "Must be implemented by inheriting class" }

1;
