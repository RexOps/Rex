use Test::More tests => 19;

use_ok 'Rex::Commands::Inventory';

use_ok 'Rex::Inventory::Bios';
use_ok 'Rex::Inventory::DMIDecode::BaseBoard';
use_ok 'Rex::Inventory::DMIDecode::Bios';
use_ok 'Rex::Inventory::DMIDecode::CPU';
use_ok 'Rex::Inventory::DMIDecode::Memory';
use_ok 'Rex::Inventory::DMIDecode::MemoryArray';
use_ok 'Rex::Inventory::DMIDecode::Section';
use_ok 'Rex::Inventory::DMIDecode::SystemInformation';
use_ok 'Rex::Inventory::DMIDecode';
use_ok 'Rex::Inventory::Hal::Object::Net';
use_ok 'Rex::Inventory::Hal::Object::Storage';
use_ok 'Rex::Inventory::Hal::Object::Volume';
use_ok 'Rex::Inventory::Hal::Object';
use_ok 'Rex::Inventory::Hal';
use_ok 'Rex::Inventory::HP::ACU';
use_ok 'Rex::Inventory';
use_ok 'Rex::Inventory::Proc';
use_ok 'Rex::Inventory::Proc::Cpuinfo';
