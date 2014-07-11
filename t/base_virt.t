use Test::More tests => 35;

use_ok 'Rex::Config';
use_ok 'Rex::Virtualization';
use_ok 'Rex::Commands::Virtualization';
use_ok 'Rex::Virtualization::LibVirt::blklist';
use_ok 'Rex::Virtualization::LibVirt::create';
use_ok 'Rex::Virtualization::LibVirt::delete';
use_ok 'Rex::Virtualization::LibVirt::destroy';
use_ok 'Rex::Virtualization::LibVirt::dumpxml';
use_ok 'Rex::Virtualization::LibVirt::hypervisor';
use_ok 'Rex::Virtualization::LibVirt::iflist';
use_ok 'Rex::Virtualization::LibVirt::info';
use_ok 'Rex::Virtualization::LibVirt::list';
use_ok 'Rex::Virtualization::LibVirt::option';
use_ok 'Rex::Virtualization::LibVirt::reboot';
use_ok 'Rex::Virtualization::LibVirt::shutdown';
use_ok 'Rex::Virtualization::LibVirt::start';
use_ok 'Rex::Virtualization::LibVirt::vncdisplay';
use_ok 'Rex::Virtualization::LibVirt';
use_ok 'Rex::Virtualization::VBox::create';
use_ok 'Rex::Virtualization::VBox::delete';
use_ok 'Rex::Virtualization::VBox::destroy';
use_ok 'Rex::Virtualization::VBox::forward_port';
use_ok 'Rex::Virtualization::VBox::guestinfo';
use_ok 'Rex::Virtualization::VBox::import';
use_ok 'Rex::Virtualization::VBox::info';
use_ok 'Rex::Virtualization::VBox::list';
use_ok 'Rex::Virtualization::VBox::option';
use_ok 'Rex::Virtualization::VBox::reboot';
use_ok 'Rex::Virtualization::VBox::share_folder';
use_ok 'Rex::Virtualization::VBox::shutdown';
use_ok 'Rex::Virtualization::VBox::start';
use_ok 'Rex::Virtualization::VBox::bridge';
use_ok 'Rex::Virtualization::VBox';

my $vm_obj = Rex::Virtualization->create("VBox");
ok( ref($vm_obj) eq "Rex::Virtualization::VBox",
  "created vm object with param" );

Rex::Config->set( virtualization => "LibVirt" );
$vm_obj = Rex::Virtualization->create();
ok( ref($vm_obj) eq "Rex::Virtualization::LibVirt",
  "created vm object with config" );
