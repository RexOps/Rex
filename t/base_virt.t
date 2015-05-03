use Test::More tests => 2;

use Rex::Virtualization;

my $vm_obj = Rex::Virtualization->create("VBox");
ok( ref($vm_obj) eq "Rex::Virtualization::VBox",
  "created vm object with param" );

Rex::Config->set( virtualization => "LibVirt" );
$vm_obj = Rex::Virtualization->create();
ok( ref($vm_obj) eq "Rex::Virtualization::LibVirt",
  "created vm object with config" );
