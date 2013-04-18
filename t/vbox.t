use strict;
use warnings;

use Test::More tests => 15;
use Data::Dumper;

use_ok 'Rex';
use_ok 'Rex::Commands';
use_ok 'Rex::Virtualization::VBox::create';
use_ok 'Rex::Virtualization::VBox::delete';
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

