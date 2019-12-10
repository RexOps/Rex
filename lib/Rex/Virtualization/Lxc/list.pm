#
# (c) Oleg Hardt <litwol@litwol.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Lxc::list;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Helper::Run;

# Not sure if global scope is good place to keep this.
# Also not sure "polluting" execute method wih this is also an option.
my %allowed_states;
$allowed_states{active}  = 1;
$allowed_states{running} = 1;
$allowed_states{frozen}  = 1;
$allowed_states{stopped} = 1;

sub execute {
  my ( $class, $state, %opt ) = @_;
  my @containers;

  my $opts = \%opt;

  Rex::Logger::debug("Getting Linux Containers list");

  $state = exists $allowed_states{$state} ? '--' . $state : '';
  my $format =
    exists $opts->{format}
    ? $opts->{format}
    : 'name,state,autostart,groups,ipv4,ipv6,pid';
  my $fancy  = exists $opts->{fancy}  ? '-f'                   : '';
  my $groups = exists $opts->{groups} ? '-g' . $opts->{groups} : '';

  # When using not fancy output, lxc-ls defaults to outputting only name.
  if ( $fancy ne '-f' ) {
    $format = 'name';
  }

  my $command_to_run = "lxc-ls -1 $state $groups $fancy -F\"$format\"";
  @containers = i_run $command_to_run, fail_ok => 1;
  if ( $? != 0 ) {
    die("Error running lxc-ls");
  }

  my @columns = split( ',', $format );
  my @ret     = ();
  for my $line (@containers) {
    next
      if $line =~ m/NAME|AUTOSTART|STATE|IPV4|IPV6|AUTOSTART|PID|RAM|SWAP\s/;
    my @values = split( /\s{1,}/, $line );

    # Convert provided format into hash values.
    my %row = ();
    foreach my $column ( 0 .. $#columns ) {
      $row{ $columns[$column] } = $values[$column];
    }

    push( @ret, \%row, );
  }

  return \@ret;
}

1;
