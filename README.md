# Rex [![Build Status](https://secure.travis-ci.org/eduardoj/Rex.png)](http://travis-ci.org/eduardoj/Rex)

With (R)?ex you can manage all your boxes from a central point through the complete process of configuration management and software deployment.

## Usage

A small example:

### Rexfile

```
set user => "root";
set password => "root";
set -passauth;

group frontend => "frontend[01..09]", "varnish[01..04]";

desc "Show Unix version";
task "uname", group => "frontend", sub {
    say run "uname -a";
};

desc "Install needed packages and configurations";
task "prepare", group => "frontend", sub {
   install "apache2";
   install "mysql-server";

   file "/path/on/the/remote/machine",
      content => "Hello World!",
      mode    => 600,
      owner   => "root",
      group   => "root";
};
```

### Commandline

* Run commands directly from command line

```
bash# rex -e 'say run "uptime";' -H "frontend[01..10] middleware[01..05]" -u root -p password
```

* List all known Tasks

```
bash# rex -T
Tasks
  uname                     Show Unix version
```

* Run Task **uname**

```
bash# rex uname
Running task: uname
Connecting to server1 (root)
Linux mango 2.6.27-openvz-briullov.1-r4 #1 SMP Tue Nov 24 23:25:52 CET 2009 x86_64 Intel(R) Pentium(R) D CPU 2.80GHz GenuineIntel GNU/Linux
Running task: uname
Connecting to server2 (root)
Linux debian01 2.6.26-2-amd64 #1 SMP Tue Aug 31 09:11:22 UTC 2010 x86_64 GNU/Linux
```
