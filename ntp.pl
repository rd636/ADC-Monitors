#!/usr/bin/perl -w
###############################################################################
## Author: R. Davis
## Date: 01/22/2019
## Citrix ADC User Based Monitor for validating Network Time Protocol (NTP) 
## Server communication.   
##
## NetScaler Script Argument names:
## 	none.
##
## Example CLI command:
##  add lb monitor NTP1 USER -scriptName ntp.pl -scriptArgs "" 
##
## Example shell test:
##  root@ns# cd /nsconfig/monitors/
##  root@ns# chmod +x ntp.pl
##  root@ns# cp /netscaler/monitors/nsumon-debug.pl nsumon-debug.pl
##  root@ns# nsumon-debug.pl ntp.pl tick.usno.navy.mil 123 10 0 0
##  ntp.pl syntax OK
##  0Success - NTP Server Response.
##
## KAS Supplied Arguments:
##  1.  IP address to be probed
##  2.  Port to be used in probe
##  3.  Argument List (not used by this script)
##  4.  Timeout
###############################################################################
## Setting the log value to none, so nothing is dumped to stdin.
$ENV{'MAX_LOG_LEVEL'} = 'none';

use strict;
use IO::Socket;
use Netscaler::KAS;

sub GetNTPTime_rd{
    my $host = shift;
	my $port = shift;
	my $arglst = shift;
    my $timeout = shift;
    my $sock = IO::Socket::INET->new(
        Proto    => 'udp',
        PeerPort => $port,
        PeerAddr => $host,
        Timeout  => $timeout
    ) 
		or do {return (1, "Can't contact $host:$port")};
    my $ntp_msg = pack("B8 C3 N11", '00100011', (0)x14);
    $sock->send($ntp_msg) 
		or do {return (1, "Can't send NTP msg.")};
    my $rin='';
    vec($rin, fileno($sock), 1) = 1;
    select(my $rout=$rin, undef, my $eout=$rin, $timeout) 
		or do {return (1, "No answer from $host:$port")};
    $sock->recv($ntp_msg, length($ntp_msg))
        or do {return (1, "Receive error from $host:$port ($!)")};
    my ($LIVNMode, $Stratum, $Poll, $Precision,
		$RootDelay, $RootDispersion, $RefIdentifier,
		$Reference, $ReferenceF, $Original, $OriginalF,
		$Receive, $ReceiveF, $Transmit, $TransmitF
        ) = unpack('a C2 c1 N8 N N B32', $ntp_msg);
	my $Mode = unpack("C", $LIVNMode & "\x07");
    $sock->close;
	if ($Mode eq 4) {
		return (0, "Success - NTP Server Response.")
    } else {
        return (1, "Error - Bad NTP Server Response")
    }
}
probe(\&GetNTPTime_rd);

__DATA__
Here are some of the internal KAS results you may see in a packet capture.

POST /ntp.pl HTTP/1.1
Nsmonitor-responsetimeout: 2
Content-Length: 39
Host: 127.0.0.1
Connection: Close

nsumon_ip=128.105.39.11&nsumon_port=123

HTTP/1.1 200 OK
More-Info:  This is a KAS result
Server: Netscaler Internal Monitor Dispatcher
Content-Length: 0
Connection: Close

HTTP/1.1 404 Not found
Failure-Reason: exec returned permission denied
Server: Netscaler Internal Monitor Dispatcher
Content-Length: 0
Connection: Close

HTTP/1.1 503 Service Unavailable
Failure-reason:  script exited with code 255
Server: Netscaler Internal Monitor Dispatcher
Content-Length: 0
Connection: Close

HTTP/1.1 502 Bad Gateway
Failure-Reason: No newline after status in the IPC data from script
Server: Netscaler Internal Monitor Dispatcher
Content-Length: 0
Connection: Close
