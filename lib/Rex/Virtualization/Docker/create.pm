#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Docker::create;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Commands::Gather;
use Rex::Hardware;
use Rex::Commands::Fs;
use Rex::Helper::Run;
use Rex::Commands::File;
use Rex::File::Parser::Data;
use Rex::Template;

use XML::Simple;

use Data::Dumper;

sub execute {
  my ( $class, $name, %opt ) = @_;

  my $opts = \%opt;
  $opts->{name} = $name;

  unless ($opts) {
    die("You have to define the create options!");
  }

  if ( !exists $opts->{"image"} ) {
    die("You have to set a base image.");
  }

  if ( !exists $opts->{"command"} ) {
    $opts->{command} = "";
  }

  my $options = _format_opts($opts);

  my @out = i_run "docker run -d $options $opts->{'image'} $opts->{'command'}";
  my $id  = pop @out;

  return $id;
}

sub _format_opts {
  my ($opts) = @_;

# -name=""
# Assign the specified name to the container. If no name is specific docker will generate a random name
  if ( !exists $opts->{"name"} ) {
    die("You have to give a name.");
  }

  # -m=""
  # Memory limit (format: <number><optional unit>, where unit = b, k, m or g)
  if ( !exists $opts->{"memory"} ) {
    $opts->{"memory"} = '512m';
  }
  else {
    $opts->{memory} = $opts->{memory};
  }

  # -c=0
  # CPU shares (relative weight)
  if ( !exists $opts->{"cpus"} ) {
    $opts->{"cpus"} = 0;
  }

  my $str = "--name $opts->{'name'} -m $opts->{'memory'} -c $opts->{'cpus'} ";

  # -e=[]
  # Set environment variables
  if ( exists $opts->{"env"} ) {
    $str .= '-e ' . join( '-e ', @{ $opts->{'env'} } ) . ' ';
  }

  # -h=""
  # Container host name
  if ( exists $opts->{"hostname"} ) {
    $str .= "-h $opts->{'hostname'} ";
  }

  # -privileged=false
  # Give extended privileges to this container
  if ( exists $opts->{"privileged"} ) {
    $str .= "--privileged $opts->{'privileged'} ";
  }

  # -p=[]
  # Map a network port to the container
  if ( exists $opts->{"forward_port"} ) {
    $str .= '-p ' . join( '-p ', @{ $opts->{'forward_port'} } ) . ' ';
  }

  # -expose=[]
  # Expose a port from the container without publishing it to your host
  if ( exists $opts->{"expose_port"} ) {
    $str .= "--expose $opts->{'expose_port'} ";
  }

  # -dns=[]
  # Set custom dns servers for the container
  if ( exists $opts->{"dns"} ) {
    $str .= '--dns ' . join( '-dns ', @{ $opts->{'dns'} } ) . ' ';
  }

  # -v=[]:
  # Create a bind mount with: [host-dir]:[container-dir]:[rw|ro].
  # If "container-dir" is missing, then docker creates a new volume.
  if ( exists $opts->{"share_folder"} ) {
    $str .= '-v ' . join( '-v ', @{ $opts->{'share_folder'} } ) . ' ';
  }

  # -volumes-from=""
  # Mount all volumes from the given container(s)
  if ( exists $opts->{"volumes-from"} ) {
    $str .= "--volumes-from \"$opts->{'volumes-from'}\" ";
  }

  # -lxc-conf=[]
  # Add custom lxc options -lxc-conf="lxc.cgroup.cpuset.cpus = 0,1"
  if ( exists $opts->{"lxc-conf"} ) {
    $str .= "--lxc-conf \"$opts->{'lxc-conf'}\" ";
  }

  # -link=""
  # Add link to another container (name:alias)
  if ( exists $opts->{"link"} ) {
    $str .= '--link ' . join( '-link ', @{ $opts->{'link'} } ) . ' ';
  }

  return $str;

}

1;
