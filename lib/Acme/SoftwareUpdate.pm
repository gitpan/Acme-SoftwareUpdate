# $Rev: 33 $
# $Id: SoftwareUpdate.pm 33 2003-07-20 18:45:06Z afoxson $

# Acme::SoftwareUpdate - check for newer version of caller module
# Copyright (c) 2003 Adam J. Foxson. All rights reserved.

# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Acme::SoftwareUpdate;

use strict;
use vars qw($VERSION $BASEPKG);

local $^W;

($VERSION) = sprintf "%.02f", (('$Rev: 33 $' =~ /\s+(\d+)\s+/)[0] / 100);

# Yes, this is naughty behavior for a module. We're going to pollute the
# upstream namespace with a subroutine named after our package name
sub Acme::SoftwareUpdate {
	&Acme::SoftwareUpdate::check_for_new_version(caller, (caller(1))[1]);
}

sub check_for_new_version {
	my ($module, $filename) = @_;

	# don't do anything if the user requested us not to
	return if $ENV{SOFTWARE_UPDATE_DISABLE};
	# don't do anything if there is no controlling TTY
	return unless -t STDIN;
	# don't do anything if we don't have a network connection
	return if (!eval{require Socket; Socket::inet_aton('search.cpan.org')});
	# don't do anything if we're not checking deps and this isn't the basepkg
	return if &not_basepkg_during_nodeps_check($module);

	my ($inst_vers, $installed) = &get_inst_info($filename, $module);
	my ($cpan_vers, $url, $released) = &get_cpan_info($module);

	# bail out if we did not acquire all of the info we want
	return if not $inst_vers or not $installed or not $cpan_vers or not $url
		or not $released;

	return if &upgrade_not_needed($inst_vers, $cpan_vers);

	print
		"\n" .
		"  There's a new version of $module available!\n" .
		"  [$url]\n\n" .
		"    Current version: $inst_vers, installed on $installed\n" .
		"    New version: $cpan_vers, released on $released\n\n";

	if (eval{require ExtUtils::AutoInstall}) {
		print "  Would you like to upgrade? (y/n): ";
		my $response = <STDIN>;
		chomp $response;

		if ($response =~ /^y$|^yes$/i) {
			ExtUtils::AutoInstall->install([], $module, $cpan_vers);
		}
		else {
			print "\n  ==> Upgrade of $module aborted. <==\n\n";
		}
	}
}

sub not_basepkg_during_nodeps_check {
	return 0 if $ENV{SOFTWARE_UPDATE_DEPS};

	my $module = shift;
	my $stack = 0;

	if (not defined $BASEPKG) {
		while (my $pkg = caller($stack++)) {
			if ($pkg eq 'main') {
				last;
			}
			else {
				$BASEPKG = $pkg;
			}
		}
	}

	return 1 unless $module eq $BASEPKG;
	return 0;
}

# Adapted from ExtUtils::AutoInstall
sub upgrade_not_needed {
	my ($inst_vers, $cpan_vers) = @_;

	# check for version numbers that are not in decimal format
	if ($inst_vers =~ /v|\..*\./ or $cpan_vers =~ /v|\..*\./) {
		if (eval{require version}) {
			return (version->new($inst_vers) >= version->new($cpan_vers));
		}
		elsif (eval{require Sort::Versions}) {
			return (Sort::Versions::versioncmp($inst_vers, $cpan_vers) != -1);
		}

		return 1;
	}

    my $upgrade_not_needed =
        eval{local $SIG{'__WARN__'} = {}; $inst_vers >= $cpan_vers};

	return 1 if $@;
	return $upgrade_not_needed;
}

# Adapted from ExtUtils::MakeMaker::MM_Unix.pm, or Module::InstalledVersion,
# or CPANPLUS::Internals::Install
sub get_inst_info {
	my ($file, $module) = @_;
	my $version;

	my $installed = localtime((stat($file))[9]);

	# Ok, let's try to get the caller's version the easy way...
	{
		no strict 'refs';
		$version = ${*{$module . '::' . 'VERSION'}{SCALAR}};
	}

	return ($version, $installed) if defined $version;

	# Damn, no joy, oh well, let's go for the hard way...
	open IN, $file or return;
	while (<IN>) {
		if (/([\$*])(([\w\:\']*)\bVERSION)\b.*\=/) {
			local $^W = 0;
			local $VERSION;
			no strict;
			my $res = eval $_;
			$version = $VERSION || $res;
			last;
		}
	}
	close IN or return;

	return unless $version and $installed;
	return ($version, $installed);
}

sub get_cpan_info {
	my $module = shift;
	my $payload = &trivial_http_get($module) || return;
	my ($link, $released, $version) = $payload =~
		m!\s{2}<link>(.+)</link>\n\s{2}<name>$module</name>\n\s{2}<released>(.+)</released>\n\s{2}<version>(.+)</version>!; 

	return unless $link and $released and $version;

	# if the version doesn't contain at least one digit, there's no sane way
	# to compare it, so we won't even bother trying
	return unless $version =~ /\d/;

	# search.cpan.org adds an initial space to the release date of
	# distributions that are released on single-digit days of the month
	$released =~ s/^\s//;

	my ($baselink) = $link =~
		m!(http://search.cpan.org/author/[^/]+/[^/]+/)!;

	return unless $baselink;
	return ($version, $baselink, $released);
}

# Adapted from LWP::Simple
sub trivial_http_get
{
	my $module = shift;
	my $mod = $module;

	# urlencode common package special characters
	$module =~ s/::/%3A%3A/g;
	$module =~ s/'/%27/g;

	my $url = "/search?query=$module&mode=module&format=xml";

	require IO::Socket;
	local $^W = 0;

	my $sock = IO::Socket::INET->new(
		PeerAddr => 'search.cpan.org',
		PeerPort => 80,
		Proto    => 'tcp',
		Timeout  => 5) || return;

	$sock->autoflush;

	print $sock join("\015\012" =>
		"GET $url HTTP/1.0",
		"Host: search.cpan.org",
		"User-Agent: Acme::SoftwareUpdate/$VERSION",
		"", "");

	my $buf = "";
	my $n;

	# we want to tansfer as little data as possible..
	while ($n = sysread($sock, $buf, 256, length($buf))) {
		last if $buf =~ m!\s{2}<link>.+</link>\n\s{2}<name>$mod</name>\n\s{2}<released>.+</released>\n\s{2}<version>.+</version>!;
	}
	return unless defined($n);

	if ($buf =~ m,^HTTP/\d+\.\d+\s+(\d+)[^\012]*\012,) {
		my $code = $1;
		return unless $code == 200;
		$buf =~ s/.+?\015?\012\015?\012//s; # zap headers
	}
	else {
		return;
	}

	return $buf;
}

1;
