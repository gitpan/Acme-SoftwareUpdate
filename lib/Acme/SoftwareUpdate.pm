# $Rev: 22 $
# $Id: SoftwareUpdate.pm 22 2003-07-13 16:02:24Z afoxson $

# Acme::SoftwareUpdate - check for newer version of caller module
# Copyright (c) 2003 Adam J. Foxson. All rights reserved.

# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Acme::SoftwareUpdate;

use strict;
use vars qw($VERSION);

local $^W;

# Yes, this is naughty behavior for a module. We're going to pollute the
# upstream namespace with a subroutine named after the RHS of our package name
sub Acme::SoftwareUpdate {
	&Acme::SoftwareUpdate::check_for_new_version(caller, (caller(1))[1]);
}

($VERSION) = sprintf "%.02f", (('$Rev: 22 $' =~ /\s+(\d+)\s+/)[0] / 100);

sub check_for_new_version {
	return if $ENV{NOSOFTWAREUPDATE};

	my ($module, $filename) = @_;
	my $inst_vers = &check_inst_vers($filename, $module);
	my ($cpan_vers, $dlurl) = &get_cpan_vers_and_dlurl($module);

	return if not $inst_vers or not $cpan_vers or not $dlurl;
	return if $inst_vers >= $cpan_vers;

	if (eval{require ExtUtils::AutoInstall}) {
		print "\n$module is installed as v$inst_vers, could be upgraded to " .
			"v$cpan_vers from CPAN.\nWould you like to upgrade? (y/n): ";
		my $response = <STDIN>;
		chomp $response;

		if ($response =~ /^y$|^yes$/i) {
			ExtUtils::AutoInstall->install([], $module, $cpan_vers);
		}
		else {
			print "\nUpgrade aborted.\n\n";
		}
	}
	else
	{
		print "\n$module is installed as v$inst_vers, could be upgraded to " .
			"v$cpan_vers from CPAN at:\n$dlurl\n\n";
	}
}

# Adapted from ExtUtils::MakeMaker::MM_Unix.pm, or Module::InstalledVersion,
# or CPANPLUS::Internals::Install
sub check_inst_vers {
	my ($file, $module) = @_;
	my $version;

	# Ok, let's try to get the caller's version the easy way...
    {
        no strict 'refs';
        $version = ${*{$module . '::' . 'VERSION'}{SCALAR}};
    }

	return $version if defined $version;

	# Damn, no joy, oh well, let's go for the hard way...
	open IN, $file or return;
	while (<IN>) {
		if (/([\$*])(([\w\:\']*)\bVERSION)\b.*\=/) {
			local $VERSION;
			my $res = eval $_;
			$version = $VERSION || $res || return;
			last;
		}
	}
	close IN or return;

	return $version;
}

sub get_cpan_vers_and_dlurl {
	my $module = shift;

	$module =~ s/::/-/g;
	$module =~ s/'/-/g;

	my $payload = &trivial_http_get($module) || return;
	my ($version) = $payload =~ m!<td\sclass=cell>$module-(.+)</td>!;
	my ($dlurl) = $payload =~ m!/CPAN/authors/id/(.+)">Download</a>]!;

	$dlurl = 'http://search.cpan.org/CPAN/authors/id/' . $dlurl if $dlurl;

	return unless $version and $dlurl;
	return ($version, $dlurl);
}

# Adapted from LWP::Simple
sub trivial_http_get
{
	my $module = shift;

	require IO::Socket;
	local $^W = 0;

	my $sock = IO::Socket::INET->new(
		PeerAddr => 'search.cpan.org',
		PeerPort => 80,
		Proto    => 'tcp',
		Timeout  => 60) || return;

	$sock->autoflush;
	$sock->timeout(5);

	print $sock join("\015\012" =>
		"GET /dist/$module/ HTTP/1.0",
		"Host: search.cpan.org",
		"User-Agent: Acme::SoftwareUpdate/$VERSION",
		"", "");

	my $buf = "";
	my $n;
	1 while $n = sysread($sock, $buf, 8*1024, length($buf));
	return unless defined($n);

	if ($buf =~ m,^HTTP/\d+\.\d+\s+(\d+)[^\012]*\012,) {
		my $code = $1;
		return unless $code =~ /^2/;
		$buf =~ s/.+?\015?\012\015?\012//s;  # zap header
	}

	return $buf;
}

1;
