#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Hardware::Memory;

use v5.14.4;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use English qw(-no_match_vars);
use Rex::Hardware::Host;
use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Commands::Sysctl;

require Rex::Hardware;

sub get {

  my $cache          = Rex::get_cache();
  my $cache_key_name = $cache->gen_key_name("hardware.memory");

  if ( $cache->valid($cache_key_name) ) {
    return $cache->get($cache_key_name);
  }

  my $os = Rex::Hardware::Host::get_operating_system();

  my $convert = sub {

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
      used  => $conn->post("/os/memory/used")->{used},
      total => $conn->post("/os/memory/max")->{max},
      free  => $conn->post("/os/memory/free")->{free},
    };
  }
  elsif ( $os eq "SunOS" ) {
    my @data = i_run "echo ::memstat | mdb -k", fail_ok => 1;

    if ( $CHILD_ERROR == 0 ) {
      my ($free_cache) =
        map { /\D+\d+\s+(\d+)/ } grep { /^Free \(cache/ } @data;
      my ($free_list) =
        map { /\D+\d+\s+(\d+)/ } grep { /^Free (\s+|\(freel)/ } @data;
      my ($page_cache) = map { /\s+\d+\s+(\d+)/ } grep { /^Page cache/ } @data;

      my $free = $free_cache + $free_list;

#my ($total, $total_e) = grep { $_=$1 if /^Memory Size: (\d+) ([a-z])/i } i_run "prtconf";
      my ($total) = map { /\s+\d+\s+(\d+)/ } grep { /^Total/ } @data;

      &$convert( $free,  "M" );
      &$convert( $total, "M" );
      my $used = $total - $free;

      $data = {
        used  => $used,
        total => $total,
        free  => $free,
      };
    }
    else {
      $data = {
        used  => 0,
        total => 0,
        free  => 0,
      };
    }
  }
  elsif ( $os eq "OpenBSD" ) {
    my $mem_str   = i_run "top -d1 | grep Memory:", fail_ok => 1;
    my $total_mem = sysctl("hw.physmem");

    my ( $phys_mem, $p_m_ent, $virt_mem, $v_m_ent, $free, $f_ent ) =
      ( $mem_str =~ m/(\d+)([a-z])\/(\d+)([a-z])[^\d]+(\d+)([a-z])/i );

    &$convert( $phys_mem, $p_m_ent );
    &$convert( $virt_mem, $v_m_ent );
    &$convert( $free,     $f_ent );

    $data = {
      used  => $phys_mem + $virt_mem,
      total => $total_mem,
      free  => $free,
    };

  }
  elsif ( $os eq "NetBSD" ) {
    my $mem_str   = i_run "top -d1 | grep Memory:", fail_ok => 1;
    my $total_mem = sysctl("hw.physmem");

    my (
      $active, $a_ent, $wired, $w_ent, $exec,
      $e_ent,  $file,  $f_ent, $free,  $fr_ent
      )
      = ( $mem_str =~
        m/(\d+)([a-z])[^\d]+(\d+)([a-z])[^\d]+(\d+)([a-z])[^\d]+(\d+)([a-z])[^\d]+(\d+)([a-z])/i
      );

    &$convert( $active, $a_ent );
    &$convert( $wired,  $w_ent );
    &$convert( $exec,   $e_ent );
    &$convert( $file,   $f_ent );
    &$convert( $free,   $fr_ent );

    $data = {
      total => $total_mem,
      used  => $active + $exec + $file + $wired,
      free  => $free,
      file  => $file,
      exec  => $exec,
      wired => $wired,
    };

  }
  elsif ( $os =~ /FreeBSD/ ) {
    my $mem_str   = i_run "top -d1 | grep Mem:", fail_ok => 1;
    my $total_mem = sysctl("hw.physmem");

    my $memory_details = __parse_top_output($mem_str);

    for my $stat (qw(active inactive wired laundry cache buf free)) {

      if ( exists $memory_details->{$stat} ) {

        my ( $value, $unit ) = $memory_details->{$stat} =~ qr{(\d+)([KMG])}msx;

        $memory_details->{$stat} = $value;

        &$convert( $memory_details->{$stat}, $unit );
      }
      else {
        $memory_details->{$stat} = 0;
      }
    }

    $data = {
      total => $total_mem,
      used  => $memory_details->{active} +
        $memory_details->{inactive} +
        $memory_details->{wired} +
        $memory_details->{laundry},
      free    => $memory_details->{free},
      cached  => $memory_details->{cache},
      buffers => $memory_details->{buf},
    };
  }
  elsif ( $os eq "OpenWrt" ) {
    my @data = i_run "cat /proc/meminfo", fail_ok => 1;

    my ($total)   = map { /(\d+)/ } grep { /^MemTotal:/ } @data;
    my ($free)    = map { /(\d+)/ } grep { /^MemFree:/ } @data;
    my ($shared)  = map { /(\d+)/ } grep { /^Shmem:/ } @data;
    my ($buffers) = map { /(\d+)/ } grep { /^Buffers:/ } @data;
    my ($cached)  = map { /(\d+)/ } grep { /^Cached:/ } @data;

    $data = {
      total   => $total,
      used    => $total - $free,
      free    => $free,
      shared  => $shared,
      buffers => $buffers,
      cached  => $cached
    };
  }
  else {
    # default for linux
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

    my $free_str = [ grep { /^Mem:/ } i_run( "free -m", fail_ok => 1 ) ]->[0];

    if ( !$free_str ) {
      $data = {
        total   => 0,
        used    => 0,
        free    => 0,
        shared  => 0,
        buffers => 0,
        cached  => 0,
      };
    }

    else {

      my ( $total, $used, $free, $shared, $buffers, $cached ) = ( $free_str =~
          m/^Mem:\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/ );

      $data = {
        total   => $total,
        used    => $used,
        free    => $free,
        shared  => $shared,
        buffers => $buffers,
        cached  => $cached
      };
    }

  }

  $cache->set( $cache_key_name, $data );

  return $data;
}

sub __parse_top_output {
  my $top_output = shift;

  my @matches = $top_output =~ m{
        \d+   # one or more digits
        [KMG] # unit
        [ ]   # space
        \w+   # memory use type
    }gmsx;

  @matches = map { split qr{[ ]}msx } @matches;

  if ( $matches[0] =~ qr{\d}msx ) {
    @matches = reverse @matches;
  }

  my %top_memory_data = @matches;

  %top_memory_data =
    map { lc $_ => $top_memory_data{$_} } keys %top_memory_data;

  return \%top_memory_data;
}

1;
