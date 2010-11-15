## What is (R)ex?

(R)?ex is a small script to ease the execution of remote commands. You can write small tasks in a file named I<Rexfile>.

## Dependencies

* Net::SSH::Expect
* Scope::With

## Installation

    git clone git://github.com/krimdomu/-R--ex.git
    cd -- -R--ex
    perl Makefile.PL
    make
    make install

## Usage

A small example:

### Rexfile

    user "root";
    
    desc "Show Unix version";
    task "uname", "server1", "server2", sub {
        run "uname -a";
    };

### Commandline

* List all known Tasks

        bash# rex -T
        Tasks
            uname                     Show Unix version

* Run Task 

        bash# rex uname
        Running task: uname
        Connecting to server1 (root)
        Linux mango 2.6.27-openvz-briullov.1-r4 #1 SMP Tue Nov 24 23:25:52 CET 2009 x86_64 Intel(R) Pentium(R) D CPU 2.80GHz GenuineIntel GNU/Linux
        Running task: uname
        Connecting to server2 (root)
        Linux debian01 2.6.26-2-amd64 #1 SMP Tue Aug 31 09:11:22 UTC 2010 x86_64 GNU/Linux

