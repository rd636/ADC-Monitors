#!/usr/bin/perl -w
###############################################################################
## Author: R. Davis
## Date: 06/17/2015
## User Based Monitor for validating application servers with a SOAP request.
##
## Place the SOAP payload after the __DATA__ line at the end of this file.
##
## NetScaler Script Argument names:
## 	url 		: the folder path, / is default
## 	response	: an expected response string
## 	hosthdr 	: HTTP Host Header value, IP is default
## 	scheme 		: The protocol type [http|https], http is default
##
## 	Specifying arguments is optional. 
##  Arguments must be specified in name=value pairs; semicolon separated.
## 	=; are separator characters and cannot be used in argument names or values.
##
## Example argument list: 
##  url=/post;hosthdr=httpbin.org;comment=24.6.87.11;response=<faw:query>123456789</faw:query>
##
## Example CLI command:
##  add lb monitor test USER -scriptName perl_mod -scriptArgs "url=/post;hosthdr=httpbin.org;comment=24.6.87.11;response=<faw:query>123456789</faw:query>" 
##
## Example #2:
##  add lb monitor post USER -scriptName post -scriptArgs "url=/post;hosthdr=postman-echo.com;comment=24.6.87.11;response=OK" 
##  add service postman-echo.com 24.6.87.11 http 80
##  bind monitor port postman-echo.com
##  
##
## Example shell test:
##  root@ns# chmod +x soap_probe_ecv_rd2.pl
##  root@ns# cp /netscaler/monitors/nsumon-debug.pl nsumon-debug.pl
##  root@ns# nsumon-debug.pl soap_probe_ecv_rd2.pl 24.6.87.11 80 10 "url=/post"
##  root@ns# nsumon-debug.pl soap_probe_ecv_rd2.pl 24.6.87.11 443 5 "url=/post;scheme=https"
##  soap_probe_ecv_rd2.pl syntax OK
##  0,Probe successful, expected response received
##
## KAS Required Arguments:
##  1.  IP address to be probed
##  2.  Port to be used in probe
##  3.  Argument List
##  4.  Timeout
###############################################################################
use Cwd;
use POSIX qw(ceil floor);
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Request::Common ('POST');
use HTTP::Request;
use HTTP::Response;
use Netscaler::KAS;
use strict;

sub soap_probe 
{
    $ENV{'PERLLIB'}='/netscaler/monitors/perl_mod';
	$ENV{HTTPS_DEBUG} = 0;
    my $err_code = 0;
    my $err_str = '';
    my $host;
    my $url;
	my $scheme;
    my $expected_response;
	my $body = 	join '', <DATA>;	
    if (scalar(@_) < 3) { return (1, 'Insufficent number of arguments') }    
	my %arg_list = split /[=;]/, $_[2];
    if (defined $arg_list{hosthdr})  { $host = $arg_list{hosthdr} 	}
							    else { $host = $_[0]			  	}	
    if (defined $arg_list{response}) { $expected_response = $arg_list{response} }
								else { $expected_response = ''		}
    if (defined $arg_list{url}) 	 { $url = $arg_list{url} 		}
								else { $url = '/'					}
	if (defined $arg_list{scheme}) 	 { $scheme = $arg_list{scheme} 	}
								else { $scheme = 'http'				}
    my $len = length($body);
    my %REQUEST_HEADERS = (
        'Content-Type' => 'text/xml;charset=UTF-8',
        'Host' => $host,
        'Accept' => '""',
        'Connection' => 'Keep-Alive',
        'Cache-Control' => 'no-cache',
        'SoapAction' => '""',
        'Content-Length' => $len,
    );
    my $netloc = "$_[0]" . ":" . "$_[1]" . $url;
    my $user_agent = LWP::UserAgent->new(	keep_alive => 1, 
											ssl_opts => { 	SSL_verify_mode => 'SSL_VERIFY_NONE',
															verify_hostname => 0,   
															SSL_use_cert 	=> 0x00 }
										);
    $user_agent->timeout("$_[3]");    
    my $request = POST( $scheme . '://' . $netloc, Content=> $body);
    $request->header(%REQUEST_HEADERS);
    my $response = $user_agent->request($request); 
    my $cache = $user_agent->conn_cache();
    if ($response->is_success) {
        my $response_content = $response->content;
        if ($response_content =~ m/$expected_response/)
        {
            $err_code=0;
            $err_str= "Probe successful, expected reponse received";
            $cache->drop();
            goto ERROR;
        }
        else
        {
            $err_code = 1; 
            $err_str = "Expected response does not match actual response" . " " . $response->code . " " . $response->status_line . "$!\n";
            $cache->drop();
            goto ERROR;
        }
    }
    else 
    {
        $err_code = 1;
        $err_str = "Request Failed" . " " . $response->code . " " . $response->status_line . " $!\n";
        $cache->drop();
        goto ERROR;
    }
ERROR:
    return($err_code, $err_str);   
}
probe(\&soap_probe);
__DATA__
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
<soap:Header></soap:Header>
<soap:Body>
<faw:Search>
<faw:query>123456789</faw:query>
</faw:Search>
</soap:Body>
</soap:Envelope>