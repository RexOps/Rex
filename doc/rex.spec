%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define real_name Rex

Summary: Rex is a tool to ease the execution of commands on multiple remote servers.
Name: rex
Version: 0.28.99.0
Release: 1
License: Apache 2.0
Group: Utilities/System
Source: http://search.cpan.org/CPAN/authors/id/J/JF/JFRIED/Rex-0.28.99.0.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildRequires: perl-Net-SSH2
BuildRequires: perl >= 5.8.0
BuildRequires: perl(ExtUtils::MakeMaker)
Requires: perl-Net-SSH2
Requires: perl-Expect
Requires: perl-DBI
Requires: perl >= 5.8.0
Requires: rsync
Requires: perl-libwww-perl
Requires: perl-XML-Simple
Requires: perl-Digest-HMAC
Requires: perl-YAML

%description
Rex is a tool to ease the execution of commands on multiple remote 
servers. You can define small tasks, chain tasks to batches, link 
them with servers or server groups, and execute them easily in 
your terminal.

%prep
%setup -n %{real_name}-%{version}

%build
%{__perl} Makefile.PL INSTALLDIRS="vendor" PREFIX="%{buildroot}%{_prefix}"
%{__make} %{?_smp_mflags}

%install
%{__rm} -rf %{buildroot}
%{__make} pure_install

### Clean up buildroot
find %{buildroot} -name .packlist -exec %{__rm} {} \;


%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root, 0755)
%doc META.yml 
%doc %{_mandir}/*
%{_bindir}/*
%{perl_vendorlib}/*

%changelog

* Fri May 25 2012 Jan Gehring <jan.gehring at, gmail.com> 0.28.99.0-1
- Fixed wrong error message in LibVirt/create.pm - Sven Dowideit
- Added dumpxml command (LibVirt) - Sven Dowideit
- Updated docs - Sven Dowideit
- Default listening on all ip's for vnc (LibVirt) - Sven Dowideit
- Added more colorized output options - Samuele Tognini
- Fixed a logging bug - Samuele Tognini
- -Tv command line option output information about requested task - Samuele Tognini
- -Tv command line option output information about batches and environments - Samuele Tognini
- Updated some error messages output - Samuele Tognini
- Added iflist command (LibVirt) - Jean Charles Passard
- Added blklist command (LibVirt) - Jean Charles Passard
- Added vncdisplay command (LibVirt) - Sven Dowideit
- Fixed a bug with hooks and packages #41 - Jan Gehring
- Refactored Task Module. Task is now an object - Jan Gehring
- Added module to parse cli parameters - Jan Gehring
- Added driver_type for kvm disks
- fixed a md5 check bug for 'install file =>'

* Thu May 08 2012 Jan Gehring <jan.gehring at, gmail.com> 0.28.0-1
- fixed a bug with relative source file names inside external modules
- new parameter -Tv to display more information about tasks
- allow additional parameters for rsync
- more code refactoring
- fixed a bug in the libvirt module (thanks to SvenDowideit for reporting and testing)

* Fri May 04 2012 Jan Gehring <jan.gehring at, gmail.com> 0.27.0-1
- added callback parameter to run command
- added logformat function to define custom logging
- reworked the output classes for better jenkins integration
- code refactoring
- added coloriszed output if Term::ANSIColor is available
- fixed a bug with older lvm versions
- added on_change option to sed command, thanks to Samuele Tognini

* Thu Apr 26 2012 Jan Gehring <jan.gehring at, gmail.com> 0.26.3-1
- fixed a notification bug in the on_change event of the file function.
- fixed a cli parameter bug

* Wed Mar 28 2012 Jan Gehring <jan.gehring at, gmail.com> 0.26.2-1
- fixed a cli parameter bug (-G)

* Thu Mar 13 2012 Jan Gehring <jan.gehring at, gmail.com> 0.26.1-1
- fixed a bug in the libvirt module

* Sun Feb 19 2012 Jan Gehring <jan.gehring at, gmail.com> 0.26.0-1
- added sudo compatibility
- added support for custom init commands
- added rex-agent compatibility
- added overmind compatibility
- added lvm support to libvirt module
- allow package installation with "install $pkg"
- added sed function
- added chdir parameter to extract function
- added include function to include Rex recipes without registering the tasks
- Specify the sudo password prompt to avoid different prompts in different locales. thanks to Hiroaki Nakamura
- Sync exclude option now takes a string or an array of strings. thanks to Hiroaki Nakamura

* Thu Feb 16 2012 Jan Gehring <jan.gehring at, gmail.com> 0.25.3-1
- fixed a display bug in rexify --search command
- fixed a bug in the libvirt module if it gets executed local
- fixed a bug in the service module for ubuntu

* Wed Feb 15 2012 Jan Gehring <jan.gehring at, gmail.com> 0.25.2-1
- display the correct module name in rexify --search command

* Wed Feb 15 2012 Jan Gehring <jan.gehring at, gmail.com> 0.25.1-1
- don't use github for recipes query

* Tue Feb 14 2012 Jan Gehring <jan.gehring at, gmail.com> 0.25.0-1
- added public repository commands to rexify
- added patch from JEEN Lee for gpgcheck on yum repositories

* Mon Feb 13 2012 Jan Gehring <jan.gehring at, gmail.com> 0.24.1-1
- fixed a dependency bug

* Fri Feb 10 2012 Jan Gehring <jan.gehring at, gmail.com> 0.24.0-1
- Added patches from Alexandr Ciornii for Makefile.PL and home-directory detection
- it is now possible to use Rex as a library
- fixed/simplified SCM module
- added iptables flush command
- added a simple tcp alive test
- allow inline templates
- cloud_instance returns vm info after create
- added cli parameters to before/around hooks
- fixed before/around/after hooks for lokal tasks
- added lvm create functions

* Sat Jan 14 2012 Jan Gehring <jan.gehring at, gmail.com> 0.23.0-1
- Redhat Enterprise Linux Support (5/6)
- read ssh_config file
- rsync now automatically accept keys

* Sat Jan 07 2012 Jan Gehring <jan.gehring at, gmail.com> 0.22.0-1
- systemd service provider (for redhat and suse)
- before, around and after hooks for tasks
- curl: Allow connections to SSL sites without certs
- don't override db config if no import options given
- fixed suse detection bug
- user: set crypted passwords
- added OpenSuSE 12.1 compatibility
- fixed redhat versiond detection
- automatically use systemd service class if opensuse >= 12.1
- added fusioninventory-agent output to the inventory module (if available)

* Sun Oct 30 2011 Jan Gehring <jan.gehring at, gmail.com> 0.21.1-1
- fix for #8 - HOME environment variable on Windows
- fix for #5 - hostname evaluation with ips

* Mon Oct 10 2011 Jan Gehring <jan.gehring at, gmail.com> 0.21.0-1
- allow multiple groups for a task
- every task can have its own auth information
- user module: add ssh key
- ssh port isn't fix anymore (patch from Jose Luis Martinez)
- use generic auth method from Net::SSH2 (patch from Jose Luis Martinez)
- add SCM module (Subversion and Git)
- file and upload now scans for environment specifiy files first
- added a file lookup function to build groups from
- fixed windows syslog bug #6, thanks to aero
- added -nolog parameter to logging function to disable logging at all
- added posibility to evaluate perl code within the -H cli parameter

* Mon Sep 26 2011 Jan Gehring <jan.gehring at, gmail.com> 0.20.0-1
- added virtualization module (from Sascha Guenther)
- added extract function
- flattend hardware gather template variables
- fixed set_path and get_path
- fixed get_random to return not 1 char too much
- added set and get commands to set config values

* Wed Sep 14 2011 Jan Gehring <jan.gehring at, gmail.com> 0.19.0-1
- added JUnit output module
- added environment support
- load Rex::Commands::Process as default

* Fri Sep 09 2011 Jan Gehring <jan.gehring at, gmail.com> 0.18.1-1
- fixed a bug registering tasks as functions

* Mon Sep 05 2011 Jan Gehring <jan.gehring at, gmail.com> 0.18.0-1
- added network support for Solaris, NetBSD, FreeBSD and OpenBSD
- added is_solaris, is_bsd and is_linux function

* Sat Sep 03 2011 Jan Gehring <jan.gehring at, gmail.com> 0.17.0-1
- added solaris 11 support
- added solaris 10 support
- added a caching module
- added a clear task function (for rex-swarm)
- added a function to get os release
- fixed local copy error handling

* Sun Aug 28 2011 Jan Gehring <jan.gehring at, gmail.com> 0.16.0-1
- added NetBSD support
- added OpenBSD support
- fixed a bug in the gentoo pkg management module

* Fri Aug 26 2011 Jan Gehring <jan.gehring at, gmail.com> 0.15.0-1
- new function to detect a redhat system (or clone like CentOS, Scientific Linux)
- increased timeouts for jiffybox
- fixed template bug with $ signs
- added support for scientific linux
- added support for gentoo

* Sun Aug 21 2011 Jan Gehring <jan.gehring at, gmail.com> 0.14.0-1
- Extended API to allow passing of arguments to Rex::Task->run
- FreeBSD support
- Ubuntu support

* Sun Aug 14 2011 Jan Gehring <jan.gehring at, gmail.com> 0.13.0-1
- added function to update package database
- license changed to GPL3
- added an alias for unlink (rm)
- added functions to manage repositories
- revised error handling
- added jiffybox support, a german cloudservice from domainfactory
- fixed template parsing bug (port from 0.12.1)
- fixed bug with too long content in file function (port from 0.12.2)

* Thu Aug 04 2011 Jan Gehring <jan.gehring at, gmail.com> 0.12.0-1
- allow array refs for Pkg::remove
- register every task as a sub if not in main package
- use lsb_release if available as default to detect operating system/version
- added sudo command
- allow to manage multiple services at once
- added possibility to add and remove services from runlevels
- added iptables module for basic iptables commands
- added cloud layer and support for amazon ec2 instances

* Thu Jul 26 2011 Jan Gehring <jan.gehring at, gmail.com> 0.11.1-1
- fixed output of netstat (reported by Thomas Biege)
- fixed inclusion of some modules in Run.pm that causes errors under some circumstances (reported by Thomas Biege)

* Fri Jul 22 2011 Jan Gehring <jan.gehring at, gmail.com> 0.11.0-1
- added lvm module
- added lvm to inventory
- fixed <OUT OF SPEC> inventory string
- fixed multiplicator for GB and TB
- added order key to selects
- added support for hpacucli

* Fri Jul 15 2011 Jan Gehring <jan.gehring at, gmail.com> 0.10.0-1
- added network module for route, default gateway and netstat
- added mount and umount function
- added cron module
- added more information (basic system information) to the inventor function
- added installed_packages function to get all the installed packages

* Sun Jul 10 2011 Jan Gehring <jan.gehring at, gmail.com> 0.9.0-1
- fixed running of multiple tasks by do_task
- register tasks as function if possible
- add "lib" to INC if exists
- added function get_operating_system
- added transactions
- deprecated "package file =>"
- added hal module to access hardware information detected by hal
- added dmidecode module to access bios information
- added inventory function "inventor"
- added ubuntu support (tested with lts 10.04)
- added can_run function, to test if a command is present

* Wed Jul 06 2011 Jan Gehring <jan.gehring at, gmail.com> 0.8.1-1
- fixed mageia detection
- fixed bug if dnsdomainname returns no domainname
- fixed mkdir bug on setting permissions, caused by a wrong merge

* Fri Jul 01 2011 Jan Gehring <jan.gehring at, gmail.com> 0.8.0-1
- added mageia support for services and packages
- added chown, chgrp and chmod functions
- mkdir, added possibility to specify the permission, the user and the group
- added function delete_lines_matching
- added function append_if_no_such_line
- added reload action for services
- extended db module to support insert, delete, update

* Sat Jun 25 2011 Jan Gehring <jan.gehring at, gmail.com> 0.7.1-1
- restored the backward compatibility with perl 5.8.x
- suppress warning if no parameter is given
- fixed a mkdir bug with 2 trailings slashs and relative directories

* Wed Jun 23 2011 Jan Gehring <jan.gehring at, gmail.com> 0.7.0-1
- preload a lot more default modules
- added new functions (df, du, cp)
- added some aliases (ln, cp, cd, ls)
- added process management functions (kill, killall, nice, ps)
- splitted out rex-agent and rex-master.

* Sun Jun 19 2011 Jan Gehring <jan.gehring at, gmail.com> 0.6.1-1
- fixed documentation bugs (thanks to djill)
- fixed #68827, rewrote is_readable/is_writable
- handle auth failure correctly
- mkdir now created directories recursive

* Sat Jun 11 2011 Jan Gehring <jan.gehring at, gmail.com> 0.6.0-1
- extended download function to work with urls (http, ftp)
- fixed bug in syntax check
- add console parameters to needs calls as default
- do_task now accepts an arrayRef to call multiple tasks at once
- check if package is installed, before the installation
- added tail function
- added cat function
- added -q cli parameter. for no debugging output at all.
- added rex-master and rex-agent

* Sat Jun 04 2011 Jan Gehring <jan.gehring at, gmail.com> 0.5.1-1
- fixed chdir command
- fixed typo in documentation
- documentation updates

* Thu Mar 31 2011 Jan Gehring <jan.gehring at, gmail.com> 0.3.1-1
- initial rpm


