use strict;
use warnings;

use Test::More tests => 17;

use_ok 'Rex';
use_ok 'Rex::Commands';
use_ok 'Rex::Virtualization::LibVirt::blklist';
use_ok 'Rex::Virtualization::LibVirt::create';
use_ok 'Rex::Virtualization::LibVirt::delete';
use_ok 'Rex::Virtualization::LibVirt::destroy';
use_ok 'Rex::Virtualization::LibVirt::dumpxml';
use_ok 'Rex::Virtualization::LibVirt::guestinfo';
use_ok 'Rex::Virtualization::LibVirt::hypervisor';
use_ok 'Rex::Virtualization::LibVirt::iflist';
use_ok 'Rex::Virtualization::LibVirt::info';
use_ok 'Rex::Virtualization::LibVirt::list';
use_ok 'Rex::Virtualization::LibVirt::option';
use_ok 'Rex::Virtualization::LibVirt::reboot';
use_ok 'Rex::Virtualization::LibVirt::shutdown';
use_ok 'Rex::Virtualization::LibVirt::start';
use_ok 'Rex::Virtualization::LibVirt::vncdisplay';
