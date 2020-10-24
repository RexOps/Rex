#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::SCM - Sourcecontrol for Subversion and Git.

=head1 DESCRIPTION

With this module you can checkout subversion and git repositories.

Version <= 1.0: All these functions will not be reported.

All these functions are not idempotent.

=head1 SYNOPSIS

 use Rex::Commands::SCM;
 
 set repository => "myrepo",
    url => 'git@foo.bar:myrepo.git';
 
 set repository => "myrepo2",
    url      => "https://foo.bar/myrepo",
    type     => "subversion",
    username => "myuser",
    password => "mypass";
 
 task "checkout", sub {
   checkout "myrepo";
 
   checkout "myrepo",
     path => "webapp";
 
   checkout "myrepo",
     path   => "webapp",
     branch => 1.6;    # branch only for git
 
   # For Git only, will replay any local commits on top of pulled commits
   checkout "myrepo",
     path   => "script_dir",
     rebase => TRUE;
 
   checkout "myrepo2";
 };


=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::SCM;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Config;

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT %REPOS);
@EXPORT = qw(checkout);

Rex::Config->register_set_handler(
  "repository" => sub {
    my ( $name, %option ) = @_;
    $REPOS{$name} = \%option;
  }
);

=head2 checkout($name, %data);

With this function you can checkout a repository defined with I<set repository>. See Synopsis.

=cut

sub checkout {
  my ( $name, %data ) = @_;

  my $type  = $REPOS{"$name"}->{"type"} ? $REPOS{$name}->{"type"} : "git";
  my $class = "Rex::SCM::\u$type";

  my $co_to = exists $data{"path"} ? $data{"path"} : "";

  if ( $data{"path"} ) {
    $data{"path"} = undef;
    delete $data{"path"};
  }

  eval "use $class;";
  if ($@) {
    Rex::Logger::info( "Error loading SCM: $@\n", "warn" );
    die("Error loading SCM: $@");
  }

  my $scm = $class->new;

  my $repo = Rex::Config->get("repository");
  Rex::Logger::debug("Checking out $repo -> $co_to");
  $scm->checkout( $REPOS{$name}, $co_to, \%data );
}

1;
