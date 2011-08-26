%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define real_name Rex

Summary: Rex is a tool to ease the execution of commands on multiple remote servers.
Name: rex
Version: 0.15.0
Release: 1
License: Artistic
Group: Utilities/System
Source: http://search.cpan.org/CPAN/authors/id/J/JF/JFRIED/Rex-0.15.0.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildRequires: perl-Net-SSH2
BuildRequires: perl >= 5.8.0
BuildRequires: perl(ExtUtils::MakeMaker)
Requires: perl-Net-SSH2
Requires: perl-Expect
Requires: perl-DBI
Requires: perl >= 5.8.0
Requires: rsync
Requires: perl-Digest-SHA1
Requires: perl-libwww-perl
Requires: perl-XML-Simple
Requires: perl-Digest-HMAC
Requires: perl-Crypt-SSLeay

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


