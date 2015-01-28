use Test::More;
use FindBin qw($Bin);

my %have_mods = ( 'XML::LibXML' => 1, );

for my $m ( keys %have_mods ) {
  my $have_mod = 1;
  eval "use $m;";
  if ($@) {
    $have_mods{$m} = 0;
  }
}

unless ( $have_mods{'XML::LibXML'} ) {
  plan skip_all =>
    'XML::LibXML module not available. XML group support won\'t be available.';
}
else {
  plan tests => 12;
}

use_ok 'Rex::Group::Lookup::XML';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::TaskList';
use_ok 'Rex::Commands';
use_ok 'Rex::Transaction';

no warnings 'once';

$::QUIET = 1;

Rex::Commands->import;

Rex::Group::Lookup::XML->import;

groups_xml("$Bin/test.xml");
my %groups = Rex::Group->get_groups;

# stringification needed for is_deeply string comparison
my @application_server = map{ "$_" }@{ $groups{application} };

is( scalar( @{ $groups{application} } ), 2, "2 application servers" );
is_deeply( [ sort @application_server ], [qw/machine01 machine02/],
  "got machine02,machine01" );
is( scalar( @{ $groups{profiler} } ), 2, "2 profiler servers 2" );

my ($server1) = grep { m/\bmachine07\b/ } @{ $groups{profiler} };
my ($server2) = grep { m/\bmachine01\b/ } @{ $groups{application} };

Rex::TaskList->create()->set_in_transaction(1);
no_ssh(
  task(
    "xml_task1",
    $server1,
    sub {
      is( connection()->server->option("services"), "nginx,docker",
        "got services inside task" );
    }
  )
);
Rex::Commands::do_task("xml_task1");

no_ssh(
  task(
    "xml_task2",
    $server2,
    sub {
      is( connection()->server->get_user(), 'root',
        "$server2 user is 'root'" );
      is( connection()->server->get_password(), 'foob4r',
        "$server2 password is 'foob4r'" );
    }
  )
);
Rex::Commands::do_task("xml_task2");
Rex::TaskList->create()->set_in_transaction(0);

