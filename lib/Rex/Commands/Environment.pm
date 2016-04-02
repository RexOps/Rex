#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Environment - Functions to work with environments

=head1 DESCRIPTION

This module contains the functions you need to work with environments.

=head1 SYNOPSIS

 environment live => sub {
   user "root";
   password "livefoo";
   pass_auth;

   group frontend => "www01", "www02", "www03";
 };


=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Environment;

use strict;
use warnings;

# VERSION

require Rex::Exporter;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(environment);

our ($environments);

=head2 environment($name => $code)

Define an environment. With environments one can use the same task for different hosts. For example if you want to use the same task on your integration-, test- and production servers.

 # define default user/password
 user "root";
 password "foobar";
 pass_auth;

 # define default frontend group containing only testwww01.
 group frontend => "testwww01";

 # define live environment, with different user/password
 # and a frontend server group containing www01, www02 and www03.
 environment live => sub {
   user "root";
   password "livefoo";
   pass_auth;

   group frontend => "www01", "www02", "www03";
 };

 # define stage environment with default user and password. but with
 # a own frontend group containing only stagewww01.
 environment stage => sub {
   group frontend => "stagewww01";
 };

 task "prepare", group => "frontend", sub {
    say run "hostname";
 };

Calling this task I<rex prepare> will execute on testwww01.
Calling this task with I<rex -E live prepare> will execute on www01, www02, www03.
Calling this task I<rex -E stage prepare> will execute on stagewww01.

You can call the function within a task to get the current environment.

 task "prepare", group => "frontend", sub {
   if(environment() eq "dev") {
     say "i'm in the dev environment";
   }
 };

If no I<-E> option is passed on the command line, the default environment
(named 'default') will be used.

=cut

sub environment {
  if (@_) {
    my ( $name, $code ) = @_;
    $environments->{$name} = {
      code        => $code,
      description => $Rex::Commands::Task::current_desc || '',
      name        => $name,
    };
    $Rex::Commands::Task::current_desc = "";

    if ( Rex::Config->get_environment eq $name ) {
      &$code();
    }

    return 1;
  }
  else {
    return Rex::Config->get_environment || "default";
  }
}

sub get_environment {
  my ( $class, $env ) = @_;

  if ( exists $environments->{$env} ) {
    return $environments->{$env};
  }
}

sub get_environments {
  my $class = shift;

  my @ret = sort { $a cmp $b } keys %{$environments};
  return @ret;
}

1;
