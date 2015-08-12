#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use LWP::UserAgent;
use JSON;

# Configuration options to be changed for your install

# Bot specific options
our $api = "YOUR BOT API KEY HERE";
our $botname = "YOUR BOT NAME HERE";

# DB specific options
our $dblocation = "localhost";
our $dbname = "YOUR DB NAME HERE";
our $dbuser = "YOUR MYSQL DB USER HERE";
our $dbpass = "YOUR DB PASSWORD HERE";

# Initialise variables to be used
my $output = "";
my $data = "";

# Create the CGI object and pull teh raw postdata as sent by telegram's webhooks
my $cgi = CGI->new();                  
$data = $cgi->param('POSTDATA');

# Check the webhook update data for what to do
$output = check_updates($data);

# Return the raw data collected in the response (unnessary but good for debug etc and non harmful)
print $cgi->header(-type => "text/html", -charset => "utf-8");
print "<html><body><p>$botname collected $data</p></body></html>"; 

sub send_ping {
	# Pull the ping from the sub input
	my $ping = shift;
	
	# Load the user list from the DB
	my %users = load_users();

	# Loop through the user list pulling chat ID's and pushing them to the send_message sub to be sent
	foreach my $user (keys %users) {
		# Skip if the user has no chat_id (not subscribed yet)
		next if $users{$user} == 0;
		send_message($users{$user},$ping);
	}
}

sub get_datasource {
	# Create the DBI data source for the mysql DB, then return it
	my $ds = "DBI:mysql:database=$dbname;host=$dblocation";                        
        return $ds;
}

sub load_users {
        use DBI;

	#Initialise used variables
        my $user = "";
        my $chat_id = "";

	my %users;
	
	# Grab the datasource for use
        my $ds = get_datasource();
	
	# Connect to the DB
        my $dbh = DBI->connect($ds, $dbuser, $dbpass) || die "DBI::errstr";

	# Pull a list of users
        my $query = $dbh->prepare("select * from pingbot_users") || die "DBI::errstr";
        $query->execute;
        $query->bind_columns(\$user,\$chat_id);

	# Loop through the rows assigning them into a hash of users
        while ($query->fetch) {
                $users{$user} = $chat_id;
        }
	
	# Return the hash for use
        return %users;
}

sub send_message {
	# Pull the chat ID and text from the sub input
	my $chat_id = shift;
	my $text = shift;

	# Initialise a web useragent object for use
	my $ua = LWP::UserAgent->new();

	# Set the method to be used, then create the URL for the web call
	my $method = "sendMessage";
	my $url = "https://api.telegram.org/bot" . $api ."/". $method;

	# Post the ping to the given URL via the web useragent
	my $response = $ua->post($url, { 'chat_id' => $chat_id, text => $text });
	
	# Pull the response - Not currently used
	my $content  = $response->decoded_content();
}

sub check_updates {
	
	# Load the user list from the DB
	my %users = load_users();

	# Create a reversed hash as well for user lookups using chat_id
	my %rusers = reverse %users;

	# Pull the webhook update message in from the sub input
	my $update = shift;

	# Exit the sub if nothing is sent or the update is blank
	return unless defined $update;
	return if $update eq "";
	
	# Decode the update from JSON to a perl object for use
	my $message = decode_json($update);

	# Check if the message starts with /subscribe
	if ($message->{"message"}->{"text"} =~ m/\/subscribe\s(.*)$/) {
		# If yes, run through the add new user sub
		add_new_user($1,$message->{"message"}->{"chat"}->{"id"});
		
		# Return the new ID - Not used at this stage
		return $message->{"message"}->{"chat"}->{"id"};
	}
		
	# Check if the message starts with /ping
	if ($message->{"message"}->{"text"} =~ m/\/ping\s(.*)/) {
		# Pull the current time and date from unix date in UTC
		my $date = `date +"%Y-%M-%d %H:%M:%S %:z(%Z)" -u`;
		
		# Chomp date to remove the newline
		chomp $date;

		# Create the ping string from the requested ping, plus the date and user + some formatting
		# This uses the reverse user list to translate chat_id -> username
		my $ping = $1;
		$ping .= "\n-------------------\nping from ".$rusers{$message->{"message"}->{"chat"}->{"id"}};
		$ping .= "\nsent ". $date . "\n-------------------";

		# Pass the ping to send_ping to be sent to everybody
		send_ping($ping);
	}
}

sub add_new_user {
        use DBI;

	# Pull the user and chat_id from the sub input
        my $user = shift;
        my $chat_id = shift;

	# Initialise used variables
	my $db_user;
	my $db_chat_id;
	
	# Get the datasource
        my $ds = get_datasource();

	# Connect to the DB
        my $dbh = DBI->connect($ds, $dbuser, $dbpass) || die "DBI::errstr";

	# Set up a select to pull the record with that username
        my $query = $dbh->prepare("select * from pingbot_users where user = '$user'") || die "DBI::errstr";
        $query->execute();
        $query->bind_columns(\$db_user,\$db_chat_id);

	# Fetch the row data (only done once as there should only be a single user with this name)
        $query->fetch();
        
	# Check that a record has been found and that they match exactly
        if ($db_user eq $user) {
		# Now check if the chat_id is 0 (AKA Not yet set up)
        	if ($db_chat_id == "0") {
			# If so, send a welcome message to that user
        		send_message($chat_id,"Welcome to the $botname ping bot. You are now subscribed to our ping service");

			# And update their chat_ID to their sent one
        		$query = $dbh->prepare("UPDATE pingbot_users SET chat_id = '$chat_id' where user = '$user'") || die "DBI::errstr";
        		$query->execute();
        	} else {
			# If not 0, send back a user is already registered message
        		send_message($chat_id,"That user is already subscribed to the $botname ping service");
        	}
        } else {
		# User didn't match the return (almost impossible) or no data was found at all showing no user in DB
		# Send back a message saying user not found
        	send_message($chat_id,"No user found with that username, please try again");
        }
}
