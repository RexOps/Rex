package Rex::Interface::Shell::Zsh;
use strict;

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
    my $comlete_cmd = $cmd;

    if ($self->{path}) {
        $complete_cmd = "set PATH=$self->{path}; ";
    }

    if ($self->{locale}) {
        $complete_cmd = "set LC_ALL=$self->{locale} $complete_cmd; ";
    }

    if ($self->{parse_profile}) {
        $complete_cmd = ". /etc/profile.zsh &> /dev/null ; $complete_cmd";
    }

    return $complete_cmd;
}

1;
