#!/usr/bin/perl -w
#
# check_senturion.pl - Icinga / Nagios Sensatronics Senturion plugin
#
# Copyright (c) 2008,2014 NETWAYS GmbH, <http://www.netways.de>
#
# Author: Bernd Loehlein <bernd.loehlein@netways.de>
#         Markus Frosch <markus.frosch@netways.de>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307
#
# Changelog:
# 2014-04-30  0.2  * Adoption by Markus Frosch
#                  * Added perfdata output
#                  * Added support for all probeids
#

# Main Stuff...
use strict;
use Net::SNMP;
use vars qw (
    $VERSION
    $COMMUNITY
    $host_address
    $opt_help
    $opt_version
    $warn_level
    $crit_level
    $value
    $type
    $probeid
    $PROGNAME
    $OUT
);


sub print_usage();
sub print_version();
use File::Basename;
use Getopt::Long;

# Main configuration
$VERSION      = "0.2";
$PROGNAME = basename($0);

my $session;
my $error;
my $snmp_version = 1;
$COMMUNITY    = "public";

# Nagios Status Values
my %STATUS_CODE = (
    'OK'       => '0',
    'WARNING'  => '1',
    'CRITICAL' => '2',
    'UNKNOWN'  => '3'
);

my @snmpoids;

# SNMP OIDs for Sensatronics Senturion
my $snmpBase        = '.1.3.6.1.4.1.16174';
my $snmpProbeNames  = $snmpBase.'.1.1.5.2.1';
my $snmpProbeValues = $snmpBase.'.1.1.5.2.2';

my %type_to_probeid = (
    'temperature' => 1,
    'humidity'    => 2,
    'light'       => 3,
    'airflow'     => 4
);

my $response;

# Help/Usage sub...
sub print_usage()
{
 print "Usage: $PROGNAME -H host [ -C community ] [ -t type | -p probeid ] -w warn -c crit \n\n";
 print "Options:\n";
 print " -H, --host STRING or IPADDRESS\n";
 print " -C, --community STRING\n";
 print " -t, --type STRING (temperature,humidity,light,airflow)\n";
 print " -p, --probe INTEGER (1,2,3,...)\n";
 print " -w, --warning INTEGER\n";
 print " -c, --critical INTEGER\n";
 print " -V, --version\n";
 print " -h, --help\n";
 print "    Display this screen.\n\n";
 exit($STATUS_CODE{"UNKNOWN"});
}

sub print_version()
{
    print "Version: ".$VERSION."\n";
    exit($STATUS_CODE{"UNKNOWN"});
}

# - Initial arguments parsing
Getopt::Long::Configure('bundling');
GetOptions (
                "H=s"           =>  \$host_address,
                "host=s"          =>  \$host_address,

                "C=s"           =>  \$COMMUNITY,
                "community=s"   =>  \$COMMUNITY,

                "w=s"           =>  \$warn_level,
                "warning=s"     =>  \$warn_level,

                "t=s"           =>  \$type,
                "type=s"        =>  \$type,

                "p=i"           =>  \$probeid,
                "probe=i"       =>  \$probeid,

                "c=s"           =>  \$crit_level,
                "critical=s"    =>  \$crit_level,

                "h"             =>  \$opt_help,
                "help"          =>  \$opt_help,

                "V"             =>  \$opt_version,
                "version"       =>  \$opt_version,
) or die "Too few arguments. Try '$PROGNAME --help' for more information\n";

# HelpArgument
if ($opt_help) {
    print_usage();
}

if ($opt_version) {
    print_version();
}

# Checking the Arguments
if((!$host_address) or (!$crit_level>0) or (!$warn_level>0) or (!$type and !$probeid) )
{
    print "Too few arguments. Try '$PROGNAME --help' for more information\n";
    exit($STATUS_CODE{"UNKNOWN"});
}

if ( $snmp_version =~ /[12]/ ) {
    ( $session, $error ) = Net::SNMP->session(
        -hostname  => $host_address,
        -community => $COMMUNITY,
        -port      => 161,
        -version   => $snmp_version
    );

    if ( !defined($session) ) {
        print("UNKNOWN: $error");
        exit $STATUS_CODE{'UNKNOWN'};
    }
}
elsif ( $snmp_version =~ /3/ ) {
    my $state = 'UNKNOWN';
    print("$state: No support for SNMP v3 yet\n");
    exit $STATUS_CODE{$state};
}
else {
    my $state = 'UNKNOWN';
    print("$state: No support for SNMP v$snmp_version yet\n");
    exit $STATUS_CODE{$state};
}

# map type to a probeid
if ($type and !$probeid) {
    if (defined $type_to_probeid{$type}) {
        $probeid = $type_to_probeid{$type};
    } else {
        print("WARNING: unknown type: $type requested\n");
        exit $STATUS_CODE{'UNKNOWN'};
    }
}

my $oidname = $snmpProbeNames.'.'.$probeid.'.0';
my $oidvalue = $snmpProbeValues.'.'.$probeid.'.0';
push( @snmpoids, $oidname);
push( @snmpoids, $oidvalue);

if ( !defined( $response = $session->get_request(@snmpoids) ) ) {
    my $answer = $session->error;
    $session->close;

    print("UNKNOWN: SNMP error: $answer\n");
    exit $STATUS_CODE{'UNKNOWN'};
}

my $name = $response->{$oidname};
my $value = $response->{$oidvalue} / 10;

# Making the Pluginoutput
# TODO: support current range syntax
if ($value >= $crit_level) {
    $OUT = "CRITICAL";
} elsif ($value >= $warn_level) {
    $OUT = "WARNING";
} else {
    $OUT = "OK";
}

my $displayname = $name;
$displayname = $type if $type;

my $perfname = $name;
if ($type) {
    $perfname = $type;
} else {
    $perfname =~ s/\s+/_/g;
    $perfname =~ s/\.$//g;
    $perfname = lc $perfname;
}

print $OUT . " $displayname: $value | '$perfname'=$value \n";

exit ($STATUS_CODE{$OUT});
