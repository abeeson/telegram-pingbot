#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use LWP::UserAgent;
use JSON;

our $api = "YOUR BOT API KEY HERE";
our $botname = "YOUR BOT NAME HERE";

our $dblocation = "localhost";
our $dbname = "YOUR DB NAME HERE";
our $dbuser = "YOUR MYSQL DB USER HERE";
our $dbpass = "YOUR DB PASSWORD HERE";

my $output = "";
my $data = "";

my $cgi = CGI->new();                  
$data = $cgi->param('POSTDATA');

$output = check_updates($data);

print $cgi->header(-type => "text/html", -charset => "utf-8");
print "<html><body><p>$botname collected $data</p></body></html>"; 

sub send_ping {
	my $ping = shift;
	
	my %users = load_users();

	foreach my $user (keys %users) {
		next if $users{$user} == 0;
		send_message($users{$user},$ping);
	}
}

sub get_datasource {
	my $ds = "DBI:mysql:database=$dbname;host=$dblocation";                        
        return $ds;
}

sub load_users {
        use DBI;

        my $user;
        my $chat_id;

	my %users;

	
        my $ds = get_datasource();
        my $dbh = DBI->connect($ds, $dbuser, $dbpass) || die "DBI::errstr";

        my $query = $dbh->prepare("select * from pingbot_users") || die "DBI::errstr";
        $query->execute;
        $query->bind_columns(\$user,\$chat_id);

        while ($query->fetch) {
                $users{$user} = $chat_id;
        }
        return %users;
}

sub send_message {
	my $chat_id = shift;
	my $text = shift;

	my $ua = LWP::UserAgent->new();

	my $method = "sendMessage";
	my $url = "https://api.telegram.org/bot" . $api ."/". $method;

	my $response = $ua->post($url, { 'chat_id' => $chat_id, text => $text });
	
	my $content  = $response->decoded_content();
}

sub check_updates {
	my %users = load_users();
	my %rusers = reverse %users;

	my $update = shift;

	return unless defined $update;
	return if $update eq "";
	
	my $message = decode_json($update);

	if ($message->{"message"}->{"text"} =~ m/\/subscribe\s(.*)$/) {
		add_new_user($1,$message->{"message"}->{"chat"}->{"id"});
		return $message->{"message"}->{"chat"}->{"id"};
	}
		
	if ($message->{"message"}->{"text"} =~ m/\/ping\s(.*)/) {
		my $date = `date +"%Y-%M-%d %H:%M:%S %:z(%Z)" -u`;
		my $ping = $1. "\n-------------------\nping from ".$rusers{$message->{"message"}->{"chat"}->{"id"}} . "\nsent ". $date . "-------------------";
		send_ping($ping);
	}
}

sub add_new_user {
        use DBI;

        my $user = shift;
        my $chat_id = shift;

	my $db_user;
	my $db_chat_id;
	
	$user = "+".$user if $user =~ m/^\d+$/;

        my $ds = get_datasource();
        my $dbh = DBI->connect($ds, $dbuser, $dbpass) || die "DBI::errstr";

        my $query = $dbh->prepare("select * from pingbot_users where user = '$user'") || die "DBI::errstr";
        $query->execute();
        $query->bind_columns(\$db_user,\$db_chat_id);

        $query->fetch();
        
        if ($db_user eq $user) {
        	if ($db_chat_id == "0") {
        		send_message($chat_id,"Welcome to the HOSDOT ping bot. You are now subscribed to our ping service");
        		$query = $dbh->prepare("UPDATE pingbot_users SET chat_id = '$chat_id' where user = '$user'") || die "DBI::errstr";
        		$query->execute();
        		
        	} else {
        		send_message($chat_id,"That user is already subscribed to the HOSDOT ping service");
        	}
        } else {
        	send_message($chat_id,"No user found with that username, please try again");
        }
}
