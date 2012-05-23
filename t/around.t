use strict;
use warnings;

use Test::More tests => 17;

use_ok 'Rex';
use_ok 'Rex::Config';
use_ok 'Rex::Group';
use_ok 'Rex::Task';
use_ok 'Rex::Commands';
use_ok 'Rex::Commands::Run';
use_ok 'Rex::Commands::Upload';

Rex::Commands->import();

#I also can't work out how to test the custom command line values, as those don't get passed to  the before()

desc("Test");
task("test", sub {
	my $params = shift;
	
	ok('bana', $params->{name});
	needs('Needed');
	
	#print STDERR "::: test: $params->{name}\n";
	return $params->{name};
});

desc("Needed");
task("Needed", sub {
	my $params = shift;
	#print STDERR "::: needed: ".$params->{name}."\n";
	ok('bana', $params->{name});
	$params->{other} = 'Needed';
});

ok(1 == Rex::Task->is_task("test"), "is_task");
ok("Test" eq Rex::Task->get_desc("test"), "get test task description");
ok("bana" eq Rex::Task->run("test", undef, {name=>'bana'}), "run test task");

around('test', sub {
	my ($server, $server_ref, $params) = @_;
	#print STDERR "::: before $params->{name}\n";
	ok('bana', $params->{name});
	return $params->{name};
});

ok("bana" eq Rex::Task->run("test", undef, {name=>'bana'}), "run test task");


1;

