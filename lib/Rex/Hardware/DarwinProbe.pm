package Rex::Hardware::DarwinProbe;

use strict;
use warnings;

sub memory_mb {
  my (%args) = @_;
  my $bytes    = $args{memsize}  || 0;
  my $pagesize = $args{pagesize} || 0;
  my $vm_stat  = $args{vm_stat}  || '';
  my $free_pages = 0;
  my $spec_pages = 0;
  if ( $vm_stat =~ /Pages free:\s+(\d+)/ ) {
    $free_pages = $1;
  }
  if ( $vm_stat =~ /Pages speculative:\s+(\d+)/ ) {
    $spec_pages = $1;
  }
  my $total = int( $bytes / 1024 / 1024 );
  my $free  = int( ( $free_pages + $spec_pages ) * $pagesize / 1024 / 1024 );
  my $used  = $total - $free;
  $used = 0 if $used < 0;
  return {
    total   => $total,
    used    => $used,
    free    => $free,
    shared  => 0,
    buffers => 0,
    cached  => 0,
  };
}

sub swap_mb {
  my ($line) = @_;
  $line ||= '';
  my ( $total, $used, $free ) =
    ( $line =~ /total = ([\d.]+)M\s+used = ([\d.]+)M\s+free = ([\d.]+)M/ );
  return {
    total => int( $total || 0 ),
    used  => int( $used  || 0 ),
    free  => int( $free  || 0 ),
  };
}

1;
