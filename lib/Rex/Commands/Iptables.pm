#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Iptables - Iptable Management Commands

=head1 DESCRIPTION

With this Module you can manage basic Iptables rules.

Version <= 1.0: All these functions will not be reported.

Only I<open_port> and I<close_port> are idempotent.

=head1 SYNOPSIS

 use Rex::Commands::Iptables;
 
 task "firewall", sub {
   iptables_clear;
 
   open_port 22;
   open_port [22, 80] => {
     dev => "eth0",
   };
 
   close_port 22 => {
     dev => "eth0",
   };
   close_port "all";
 
   redirect_port 80 => 10080;
   redirect_port 80 => {
     dev => "eth0",
     to  => 10080,
   };
 
   default_state_rule;
   default_state_rule dev => "eth0";
 
   is_nat_gateway;
 
   iptables t => "nat",
         A => "POSTROUTING",
         o => "eth0",
         j => "MASQUERADE";

   # The 'iptables' function also accepts long options,
   # however, options with dashes need to be quoted
   iptables table => "nat",
         accept          => "POSTROUTING",
         "out-interface" => "eth0",
         jump            => "MASQUERADE";
 
 };

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Iptables;

use strict;
use warnings;

# VERSION

require Rex::Exporter;
use Data::Dumper;

use base qw(Rex::Exporter);

use vars qw(@EXPORT);

use Rex::Commands::Sysctl;
use Rex::Commands::Run;
use Rex::Commands::Gather;

use Rex::Logger;

@EXPORT = qw(iptables is_nat_gateway iptables_list iptables_clear
  open_port close_port redirect_port
  default_state_rule);

sub iptables;

=item open_port($port, $option)

Open a port for inbound connections.

 task "firewall", sub {
   open_port 22;
   open_port [22, 80];
   open_port [22, 80],
     dev => "eth1";
 };
 
 task "firewall", sub {
  open_port 22,
    dev    => "eth1",
    only_if => "test -f /etc/firewall.managed";
} ;


=cut

sub open_port {

  my ( $port, $option ) = @_;

  my %option_h;
  if ( ref $option ne "HASH" ) {
    ( $port, %option_h ) = @_;

    if ( exists $option_h{only_if} ) {
      run( $option_h{only_if} );
      if ( $? != 0 ) {
        return;
      }
    }

    delete $option_h{only_if};
    $option = {%option_h};
  }
  _open_or_close_port( "i", "I", "INPUT", "ACCEPT", $port, $option );

}

=item close_port($port, $option)

Close a port for inbound connections.

 task "firewall", sub {
   close_port 22;
   close_port [22, 80];
   close_port [22, 80],
     dev    => "eth0",
     only_if => "test -f /etc/firewall.managed";
 };

=cut

sub close_port {

  my ( $port, $option ) = @_;

  my %option_h;
  if ( ref $option ne "HASH" ) {
    ( $port, %option_h ) = @_;

    if ( exists $option_h{only_if} ) {
      run( $option_h{only_if} );
      if ( $? != 0 ) {
        return;
      }
    }

    delete $option_h{only_if};
    $option = {%option_h};
  }

  _open_or_close_port( "i", "A", "INPUT", "DROP", $port, $option );

}

=item redirect_port($in_port, $option)

Redirect $in_port to another local port.

 task "redirects", sub {
   redirect_port 80 => 10080;
   redirect_port 80 => {
     to  => 10080,
     dev => "eth0",
   };
 };

=cut

sub redirect_port {
  my ( $in_port, $option ) = @_;

  my @opts;

  push( @opts, "t", "nat" );

  if ( !ref($option) ) {
    my $net_info = network_interfaces();
    my @devs     = keys %{$net_info};

    for my $dev (@devs) {
      redirect_port(
        $in_port,
        {
          dev => $dev,
          to  => $option,
        }
      );
    }

    return;
  }

  unless ( exists $option->{"dev"} ) {
    my $net_info = network_interfaces();
    my @devs     = keys %{$net_info};

    for my $dev (@devs) {
      $option->{"dev"} = $dev;
      redirect_port( $in_port, $option );
    }

    return;
  }

  if ( $option->{"to"} =~ m/^\d+$/ ) {
    $option->{"proto"} ||= "tcp";

    push( @opts,
      "I", "PREROUTING",       "i", $option->{"dev"},
      "p", $option->{"proto"}, "m", $option->{"proto"} );
    push( @opts,
      "dport", $in_port, "j", "REDIRECT", "to-ports", $option->{"to"} );

  }
  else {
    Rex::Logger::info(
      "Redirect to other hosts isn't supported right now. Please do it by hand."
    );
  }

  iptables @opts;
}

=item iptables(@params)

Write standard iptable comands.

Note that there is a short form for the IPTables C<--flush> option; when you
pass the option of C<-F|"flush"> as the only argument, the command
C<iptables -F> is run on the connected host.  With the two argument form of
C<flush> shown in the examples below, the second argument is table you want to
flush.

 task "firewall", sub {
   iptables t => "nat", A => "POSTROUTING", o => "eth0", j => "MASQUERADE";
   iptables t => "filter", i => "eth0", m => "state", state => "RELATED,ESTABLISHED", j => "ACCEPT";
 
   # automatically flushes all tables; equivalent to 'iptables -F'
   iptables "flush";
   iptables -F;

   # flush only the "filter" table
   iptables flush => "filter";
   iptables -F => "filter";
 };

 # Note: options with dashes "-" need to be quoted to escape them from Perl
 task "long_form_firewall", sub {
   iptables table => "nat",
        append          => "POSTROUTING",
        "out-interface" => "eth0",
        jump            => "MASQUERADE";
   iptables table => "filter",
        "in-interface" => "eth0",
        match          => "state",
        state          => "RELATED,ESTABLISHED",
        jump           => "ACCEPT";
 };

=cut

sub iptables {
  my (@params) = @_;

  if ( $params[0] eq "flush" || $params[0] eq "-flush" || $params[0] eq "-F" ) {
    if ( $params[1] ) {
      run "iptables -F -t $params[1]";
    }
    else {
      run "iptables -F";
    }

    return;
  }

  my $cmd = "";
  my $n   = -1;
  while ( $params[ ++$n ] ) {
    my ( $key, $val ) = reverse @params[ $n, $n++ ];

    if ( ref($key) eq "ARRAY" ) {
      $cmd .= join( " ", @{$key} );
      last;
    }

    if ( length($key) == 1 ) {
      $cmd .= "-$key $val ";
    }
    else {
      $cmd .= "--$key '$val' ";
    }
  }

  if ( can_run("iptables") ) {
    my $output = run "iptables $cmd";

    if ( $? != 0 ) {
      Rex::Logger::info( "Error setting iptable rule: $cmd", "warn" );
      die("Error setting iptable rule: $cmd; command output: $output");
    }
  }
  else {
    Rex::Logger::info("IPTables not found.");
    die("IPTables not found.");
  }
}

=item is_nat_gateway

This function creates a NAT gateway for the device the default route points to.

 task "make-gateway", sub {
   is_nat_gateway;
 };

=cut

sub is_nat_gateway {

  Rex::Logger::debug("Changing this system to a nat gateway.");

  if ( can_run("ip") ) {

    my @iptables_option = ();

    my ($default_line) = run "/sbin/ip r |grep ^default";
    my ($dev)          = ( $default_line =~ m/dev ([a-z0-9]+)/i );
    Rex::Logger::debug("Default GW Device is $dev");

    sysctl "net.ipv4.ip_forward" => 1;
    iptables t => "nat", A => "POSTROUTING", o => $dev, j => "MASQUERADE";

  }
  else {

    Rex::Logger::info("No /sbin/ip found.");

  }

}

=item default_state_rule(%option)

Set the default state rules for the given device.

 task "firewall", sub {
   default_state_rule(dev => "eth0");
 };

=cut

sub default_state_rule {
  my (%option) = @_;

  unless ( exists $option{"dev"} ) {
    my $net_info = network_interfaces();
    my @devs     = keys %{$net_info};

    for my $dev (@devs) {
      default_state_rule( dev => $dev );
    }

    return;
  }

  iptables
    t     => "filter",
    A     => "INPUT",
    i     => $option{"dev"},
    m     => "state",
    state => "RELATED,ESTABLISHED",
    j     => "ACCEPT";
}

=item iptables_list

List all iptables rules.

 task "list-iptables", sub {
   print Dumper iptables_list;
 };

=cut

sub iptables_list {
  my @lines = run "/sbin/iptables-save";
  _iptables_list(@lines);
}

sub _iptables_list {
  my ( %tables, $ret );
  my (@lines) = @_;

  my ($current_table);
  for my $line (@lines) {
    chomp $line;

    next if ( $line eq "COMMIT" );
    next if ( $line =~ m/^#/ );
    next if ( $line =~ m/^:/ );

    if ( $line =~ m/^\*([a-z]+)$/ ) {
      $current_table = $1;
      $tables{$current_table} = [];
      next;
    }

#my @parts = grep { ! /^\s+$/ && ! /^$/ } split (/(\-\-?[^\s]+\s[^\s]+)/i, $line);
    my @parts = grep { !/^\s+$/ && !/^$/ } split( /^\-\-?|\s+\-\-?/i, $line );

    my @option = ();
    for my $part (@parts) {
      my ( $key, $value ) = split( /\s/, $part, 2 );

      #$key =~ s/^\-+//;
      push( @option, $key => $value );
    }

    push( @{ $ret->{$current_table} }, \@option );

  }

  return $ret;
}

=item iptables_clear

Remove all iptables rules.

 task "no-firewall", sub {
   iptables_clear;
 };

=cut

sub iptables_clear {

  for my $table (qw/nat mangle filter/) {
    iptables t => $table, F => '';
    iptables t => $table, X => '';
  }

  for my $p (qw/INPUT FORWARD OUTPUT/) {
    iptables P => $p, ["ACCEPT"];
  }

}

sub _open_or_close_port {
  my ( $dev_type, $push_type, $chain, $jump, $port, $option ) = @_;

  my @opts;

  push( @opts, "t", "filter", "$push_type", "$chain" );

  unless ( exists $option->{"dev"} ) {
    my $net_info = network_interfaces();
    my @dev      = keys %{$net_info};
    $option->{"dev"} = \@dev;
  }

  if ( exists $option->{"dev"} && !ref( $option->{"dev"} ) ) {
    push( @opts, "$dev_type", $option->{"dev"} );
  }
  elsif ( ref( $option->{"dev"} ) eq "ARRAY" ) {
    for my $dev ( @{ $option->{"dev"} } ) {
      my $new_option = $option;
      $new_option->{"dev"} = $dev;

      _open_or_close_port( $dev_type, $push_type, $chain, $jump, $port,
        $new_option );
    }

    return;
  }

  if ( exists $option->{"proto"} ) {
    push( @opts, "p", $option->{"proto"} );
    push( @opts, "m", $option->{"proto"} );
  }
  else {
    push( @opts, "p", "tcp" );
    push( @opts, "m", "tcp" );
  }

  if ( $port eq "all" ) {
    push( @opts, "j", "$jump" );
  }
  else {
    if ( ref($port) eq "ARRAY" ) {
      for my $port_num ( @{$port} ) {
        _open_or_close_port( $dev_type, $push_type, $chain, $jump, $port_num,
          $option );
      }
      return;
    }

    push( @opts, "dport", $port );
    push( @opts, "j",     $jump );
  }

  if ( _rule_exists(@opts) ) {
    Rex::Logger::debug("IPTables rule already exists. skipping...");
    return;
  }

  iptables @opts;

}

sub _rule_exists {
  my (@check_rule) = @_;

  shift @check_rule;
  shift @check_rule;
  shift @check_rule;

  my $str_check_rule = join( " ", "A", @check_rule );

  my $current_tables = iptables_list();
  if ( exists $current_tables->{filter} ) {
    for my $rule ( @{ $current_tables->{filter} } ) {
      my $str_rule = join( " ", @{$rule} );
      $str_rule =~ s/\s$//;

      Rex::Logger::debug("comparing: '$str_rule' == '$str_check_rule'");
      if ( $str_rule eq $str_check_rule ) {
        return 1;
      }
    }
  }

  return 0;
}

=back

=cut

1;
