#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Shell::Ksh;

use strict;
use warnings;

use Rex::Interface::Shell::Bash;

use base qw(Rex::Interface::Shell::Bash);

sub new {
    my $class = shift;
    my $proto = ref($class) || $class;
    my $self = $proto->SUPER::new(@_);

    bless($self, $class);
    
    return $self;
}

1;
