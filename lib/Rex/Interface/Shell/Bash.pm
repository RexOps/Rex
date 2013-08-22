#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   

package Rex::Interface::Shell::Bash;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = {};
    $self->{path} = undef;
    bless($self, $class);
    
    return $self;
}

sub path {
    my ($self, $path ) = @_;
    $self->{path} = $path;
}

sub parse_profile {
    my ($self, $parse) = @_;
    $self->{parse_profile} = $parse;
}

sub set_locale {
    my ($self, $locale) = @_;
    $self->{locale} = $locale;
}

sub exec {
    my ($self, $cmd) = @_;
    my $complete_cmd = $cmd;

    if ($self->{path}) {
        $complete_cmd = "PATH=$self->{path}; export PATH; $complete_cmd ";
    }

    if ($self->{locale}) {
        $complete_cmd = "LC_ALL=$self->{locale} ; export LC_ALL; $complete_cmd ";
    }

    if ($self->{parse_profile}) {
        $complete_cmd = ". /etc/profile &> /dev/null ; $complete_cmd";
    }

# this is due to a strange behaviour with Net::SSH2 / libssh2
# it may occur when you run rex inside a kvm virtualized host connecting to another virtualized vm on the same hardware
    if(Rex::Config->get_sleep_hack) {
      $complete_cmd .= " ; f=\$? ; sleep .00000001 ; exit \$f");
    }

    return $complete_cmd;
}

1;
