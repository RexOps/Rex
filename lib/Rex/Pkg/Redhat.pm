#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg::Redhat;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Pkg::Base;
use base qw(Rex::Pkg::Base);


sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub is_installed {
   my ($self, $pkg) = @_;

   Rex::Logger::debug("Checking if $pkg is installed");

   run("rpm -ql $pkg");

   unless($? == 0) {
      Rex::Logger::debug("$pkg is NOT installed.");
      return 0;
   }
   
   Rex::Logger::debug("$pkg is installed.");
   return 1;
}

sub install {
   my ($self, $pkg, $option) = @_;

   if($self->is_installed($pkg) && ! $option->{"version"}) {
      Rex::Logger::info("$pkg is already installed");
      return 1;
   }

   $self->update($pkg, $option);

   return 1;
}

sub update {
   my ($self, $pkg, $option) = @_;

   my $version = $option->{"version"} || "";

   Rex::Logger::debug("Installing $pkg / $version");
   my $f = run(_yum("-y install $pkg" . ($version?"-$version":"")));

   unless($? == 0) {
      Rex::Logger::info("Error installing $pkg.", "warn");
      Rex::Logger::debug($f);
      die("Error installing $pkg");
   }

   Rex::Logger::debug("$pkg successfully installed.");


   return 1;
}

sub remove {
   my ($self, $pkg) = @_;

   Rex::Logger::debug("Removing $pkg");
   my $f = run(_yum("-y erase $pkg"));

   unless($? == 0) {
      Rex::Logger::info("Error removing $pkg.", "warn");
      Rex::Logger::debug($f);
      die("Error removing $pkg");
   }

   Rex::Logger::debug("$pkg successfully removed.");

   return 1;
}

sub get_installed {
   my ($self) = @_;

   my @lines = run 'rpm -qa --nosignature --nodigest --qf "%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n"';

   my @pkg;

   for my $line (@lines) {
      if($line =~ m/^([^\s]+)\s([^\s]+)\s([^\s]+)\s([^\s]+)\s(.*)$/) {
         push(@pkg, {
            name    => $1,
            epoch   => $2,
            version => $3,
            release => $4,
            arch    => $5,
         });
      }
   }

   return @pkg;
}

sub update_system {
   my ($self) = @_;
   run(_yum("-y upgrade"));
}

sub update_pkg_db {
   my ($self) = @_;

   run(_yum("clean all"));
   run(_yum("makecache"));
   if($? != 0) {
      die("Error updating package repository");
   }
}

sub add_repository {
   my ($self, %data) = @_;

   my $name = $data{"name"};
   my $desc = $data{"description"} || $data{"name"};

   my $fh = file_write "/etc/yum.repos.d/$name.repo";

   $fh->write("# This file is managed by Rex\n");
   $fh->write("[$name]\n");
   $fh->write("name=$desc\n");
   $fh->write("baseurl=" . $data{"url"} . "\n");
   $fh->write("enabled=1\n");
   $fh->write("gpgcheck=" . $data{"gpgcheck"} ."\n") if defined $data{"gpgcheck"};

   $fh->close;
}

sub rm_repository {
   my ($self, $name) = @_;
   unlink "/etc/yum.repos.d/$name.repo";
}


sub _yum {
   my (@cmd) = @_;

   my $str = "yum ";

   if($Rex::Logger::debug) {
      $str .= join(" ", @cmd);
   }
   else {
      $str .= join(" -q ", @cmd);
   }

   return $str;
}

1;
