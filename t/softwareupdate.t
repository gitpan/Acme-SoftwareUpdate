use strict;
use Test;
use Acme::SoftwareUpdate;

BEGIN {plan tests => 10}

my ($inst_vers_of_test_pm, $inst_of_test_pm) =
	Acme::SoftwareUpdate::get_inst_info($INC{'Test.pm'}, 'Test');
my ($inst_vers_of_strict_pm, $inst_of_strict_pm) =
	Acme::SoftwareUpdate::get_inst_info($INC{'strict.pm'}, 'strict');

ok($inst_vers_of_test_pm =~ /\d\.\d{2}/);
ok($inst_vers_of_strict_pm =~ /\d\.\d{2}/);
ok($inst_of_test_pm =~ /\w{3}\s\w{3}\s+\d+\s\d{2}:\d{2}:\d{2}\s\d{4}/);
ok($inst_of_strict_pm =~ /\w{3}\s\w{3}\s+\d+\s\d{2}:\d{2}:\d{2}\s\d{4}/);

if (!eval { require Socket; Socket::inet_aton('search.cpan.org') }) {
	for (1..6) {
		print "ok $_ # skip - Cannot connect to search.cpan.org\n";
	}
}
else {

	my ($cpan_vers_of_test_pm, $url_of_test_pm, $rel_of_test_pm) =
		Acme::SoftwareUpdate::get_cpan_info('Test');
	my ($cpan_vers_of_strict_pm, $url_of_strict_pm, $rel_of_strict_pm) =
		Acme::SoftwareUpdate::get_cpan_info('strict');

	ok($cpan_vers_of_test_pm =~ /\d\.\d{2}/);
	ok($url_of_test_pm =~ /search\.cpan\.org\/author\//);
	ok($rel_of_test_pm =~ /\d+\w{2}\s\w+\s\d{4}/);
	ok($cpan_vers_of_strict_pm =~ /\d\.\d{2}/);
	ok($url_of_strict_pm =~ /search\.cpan\.org\/author\//);
	ok($rel_of_strict_pm =~ /\d+\w{2}\s\w+\s\d{4}/);
}
