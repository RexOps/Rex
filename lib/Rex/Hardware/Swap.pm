#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Hardware::Swap;

use strict;
use warnings;

# VERSION

use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Hardware::Host;

require Rex::Hardware;

sub get {

  my $cache          = Rex::get_cache();
  my $cache_key_name = $cache->gen_key_name("hardware.swap");

  if ( $cache->valid($cache_key_name) ) {
    return $cache->get($cache_key_name);
  }

  my $os = Rex::Hardware::Host::get_operating_system();

  my $convert = sub {

    if ( !defined $_[0] ) {
      return 0;
    }

    if ( $_[1] eq "G" ) {
      $_[0] = $_[0] * 1024 * 1024 * 1024;
    }
    elsif ( $_[1] eq "M" ) {
      $_[0] = $_[0] * 1024 * 1024;
    }
    elsif ( $_[1] eq "K" ) {
      $_[0] = $_[0] * 1024;
    }

  };

  my $data = {};

  if ( $os eq "Windows" ) {
    my $conn = Rex::get_current_connection()->{conn};
    $data = {
      used  => $conn->post("/os/swap/used")->{used},
      total => $conn->post("/os/swap/max")->{max},
      free  => $conn->post("/os/swap/free")->{free},
    };
  }
  elsif ( $os eq "SunOS" ) {
    my ($swap_str) = i_run( "swap -s", fail_ok => 1 );

    my ( $used, $u_ent, $avail, $a_ent ) =
      ( $swap_str =~ m/(\d+)([a-z]) used, (\d+)([a-z]) avail/ );

    &$convert( $used,  uc($u_ent) );
    &$convert( $avail, uc($a_ent) );

    $data = {
      total => $used + $avail,
      used  => $used,
      free  => $avail,
    };
  }
  elsif ( $os eq "OpenBSD" ) {
    my $swap_str = i_run "top -d1 | grep Swap:", fail_ok => 1;

    my ( $used, $u_ent, $total, $t_ent ) =
      ( $swap_str =~ m/Swap: (\d+)([a-z])\/(\d+)([a-z])/i );

    &$convert( $used,  $u_ent );
    &$convert( $total, $t_ent );

    $data = {
      total => $total,
      used  => $used,
      free  => $total - $used,
    };
  }
  elsif ( $os eq "NetBSD" ) {
    my $swap_str = i_run "top -d1 | grep Swap:", fail_ok => 1;

    my ( $total, $t_ent, $free, $f_ent ) =
      ( $swap_str =~ m/(\d+)([a-z])[^\d]+(\d+)([a-z])/i );

    &$convert( $total, $t_ent );
    &$convert( $free,  $f_ent );

    $data = {
      total => $total,
      used  => $total - $free,
      free  => $free,
    };

  }
  elsif ( $os =~ /FreeBSD/ ) {
    my $swap_str = i_run "top -d1 | grep Swap:", fail_ok => 1;

    my ( $total, $t_ent, $used, $u_ent, $free, $f_ent ) =
      ( $swap_str =~ m/(\d+)([a-z])[^\d]+(\d+)([a-z])[^\d]+(\d+)([a-z])/i );

    if ( !$total ) {
      ( $total, $t_ent, $free, $f_ent ) =
        ( $swap_str =~ m/(\d+)([a-z])[^\d]+(\d+)([a-z])/i );
    }

    &$convert( $total, $t_ent ) if ($total);
    &$convert( $used,  $u_ent ) if ($used);
    &$convert( $free,  $f_ent ) if ($free);

    if ( !$used && $total && $free ) {
      $used = $total - $free;
    }

    $data = {
      total => $total || 0,
      used  => $used  || 0,
      free  => $free  || 0,
    };
  }
  else {
    # linux as default
    if ( !can_run("free") ) {
      $data = {
        total   => 0,
        used    => 0,
        free    => 0,
        shared  => 0,
        buffers => 0,
        cached  => 0,
      };
    }

    my $free_str = [ grep { /^Swap:/ } i_run( "free -m", fail_ok => 1 ) ]->[0];
    if ( !$free_str ) {
      $data = {
        total => 0,
        used  => 0,
        free  => 0,
      };
    }

    else {

      $free_str =~ s/\r//g;
      $free_str =~ s/^\s+|\s+$//g;

      my ( $total, $used, $free ) =
        ( $free_str =~ m/^Swap:\s+(\d+)\s+(\d+)\s+(\d+)$/ );

      $data = {
        total => $total,
        used  => $used,
        free  => $free,
      };

    }

  }

  $cache->set( $cache_key_name, $data );

  return $data;
}

1;
