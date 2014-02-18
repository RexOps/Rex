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

sub source_global_profile {
    my ($self, $parse) = @_;
    $self->{source_global_profile} = $parse;
}

sub source_profile {
    my ($self, $parse) = @_;
    $self->{source_profile} = $parse;
}

sub set_locale {
    my ($self, $locale) = @_;
    $self->{locale} = $locale;
}

sub set_env {
    my ($self, $env) = @_;
    my $cmd = undef;
    
    die ("Error: env must be a hash")
    	if(ref $env ne "HASH");

    while (my ($k, $v) = each ( $env )) {
        $cmd .= "export $k=$v; ";
    }
    $self->{env} = $cmd;
}

sub exec {
    my ($self, $cmd, $option) = @_;
    my $complete_cmd = $cmd;

    if(exists $option->{path}) {
      $self->path($option->{path});
    }
    
    if(exists $option->{env}) {
        $self->set_env($option->{env});
    }

    if(exists $option->{no_sh}) {

       if(exists $option->{cwd}) {
           $option->{format_cmd} = "cd $option->{cwd} && $option->{format_cmd}";
       }

       if ($self->{path}) {
           $option->{format_cmd} = "PATH=$self->{path}; export PATH; $option->{format_cmd} ";
       }

       if ($self->{locale} && ! exists $option->{no_locales}) {
           $option->{format_cmd} = "LC_ALL=$self->{locale} ; export LC_ALL; $option->{format_cmd} ";
       }

       if ($self->{source_profile}) {
           $option->{format_cmd} = ". ~/.profile >/dev/null 2>&1 ; $option->{format_cmd} ";
       }


       if ($self->{source_global_profile}) {
           $option->{format_cmd} = ". /etc/profile >/dev/null 2>&1 ; $option->{format_cmd} ";
       }

    }
    else {

       if(exists $option->{cwd}) {
         $complete_cmd = "cd $option->{cwd} && $complete_cmd";
       }

       if ($self->{path}) {
           $complete_cmd = "PATH=$self->{path}; export PATH; $complete_cmd ";
       }
       
       if($self->{env}) { 
	  $complete_cmd = "$self->{env} $complete_cmd ";
       }

       if ($self->{locale} && ! exists $option->{no_locales}) {
           $complete_cmd = "LC_ALL=$self->{locale} ; export LC_ALL; $complete_cmd ";
       }

       if ($self->{source_profile}) {
           $complete_cmd = ". ~/.profile >/dev/null 2>&1 ; $complete_cmd";
       }


       if ($self->{source_global_profile}) {
           $complete_cmd = ". /etc/profile >/dev/null 2>&1 ; $complete_cmd";
       }

    }


# this is due to a strange behaviour with Net::SSH2 / libssh2
# it may occur when you run rex inside a kvm virtualized host connecting to another virtualized vm on the same hardware
    if(Rex::Config->get_sleep_hack) {
      $complete_cmd .= " ; f=\$? ; sleep .00000001 ; exit \$f";
    }

    if(exists $option->{preprocess_command} && ref $option->{preprocess_command} eq "CODE") {
      $complete_cmd = $option->{preprocess_command}->($complete_cmd);
    }

    if(exists $option->{format_cmd}) {
      $option->{format_cmd} =~ s/{{CMD}}/$complete_cmd/;
      $complete_cmd = $option->{format_cmd};
    }

    return $complete_cmd;
}

1;
