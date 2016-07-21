use Test::More tests => 6;
use FindBin qw($Bin);
use Rex::Require;

SKIP: {

  eval { XML::LibXML->require };
  skip 'Missing XML::LibXML for XML file support.', 6 if $@;

  require Rex::Group::Lookup::XML;
  Rex::Group::Lookup::XML->import;

  use Rex::Group;
  use Rex::Commands;

  no warnings 'once';

  $::QUIET = 1;

  groups_xml("$Bin/test.xml");
  my %groups = Rex::Group->get_groups;

  # stringification needed for is_deeply string comparison
  my @application_server = map { "$_" } @{ $groups{application} };

  is( scalar( @{ $groups{application} } ), 2, "2 application servers" );
  is_deeply(
    [ sort @application_server ],
    [qw/machine01 machine02/],
    "got machine02,machine01"
  );
  is( scalar( @{ $groups{profiler} } ), 2, "2 profiler servers 2" );

  my ($server1) = grep { m/\bmachine07\b/ } @{ $groups{profiler} };
  my ($server2) = grep { m/\bmachine01\b/ } @{ $groups{application} };

  Rex::TaskList->create()->set_in_transaction(1);
  no_ssh(
    task(
      "xml_task1",
      $server1,
      sub {
        is( connection()->server->option("services"),
          "nginx,docker", "got services inside task" );
      }
    )
  );
  Rex::Commands::do_task("xml_task1");

  no_ssh(
    task(
      "xml_task2",
      $server2,
      sub {
        is( connection()->server->get_user(),
          'root', "$server2 user is 'root'" );
        is( connection()->server->get_password(),
          'foob4r', "$server2 password is 'foob4r'" );
      }
    )
  );
  Rex::Commands::do_task("xml_task2");
  Rex::TaskList->create()->set_in_transaction(0);
}
