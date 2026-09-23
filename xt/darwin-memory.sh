#!/usr/bin/env bash
set -eo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)

set +e
free -m >/tmp/rex-free.out 2>/tmp/rex-free.err
red=$?
set -e
if [ "$red" -eq 0 ]; then
  echo "free unexpectedly succeeded" >&2
  exit 1
fi
grep -q "command not found" /tmp/rex-free.err

if ! grep -q 'os eq "Darwin"' "$root/lib/Rex/Hardware/Memory.pm"; then
  echo "Memory.pm has no Darwin branch" >&2
  exit 1
fi
if ! grep -q 'os eq "Darwin"' "$root/lib/Rex/Hardware/Swap.pm"; then
  echo "Swap.pm has no Darwin branch" >&2
  exit 1
fi

perl -I"$root/lib" -MRex::Hardware::DarwinProbe -e '
  my $bytes = `sysctl -n hw.memsize`;
  my $pages = `sysctl -n hw.pagesize`;
  my $vm = `vm_stat`;
  my $swap = `sysctl -n vm.swapusage`;
  chomp($bytes, $pages, $swap);
  my $mem = Rex::Hardware::DarwinProbe::memory_mb(memsize => $bytes, pagesize => $pages, vm_stat => $vm);
  my $sw = Rex::Hardware::DarwinProbe::swap_mb($swap);
  my $expect = int($bytes / 1024 / 1024);
  die "total $mem->{total} != $expect\n" unless $mem->{total} == $expect;
  die "free larger than total\n" unless $mem->{free} <= $mem->{total};
  die "swap total missing from [$swap]\n" unless $sw->{total} > 0;
  print "rex darwin ok total=$mem->{total} free=$mem->{free} swap=$sw->{total} used=$sw->{used} free_swap=$sw->{free}\n";
'
