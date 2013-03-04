package tsheets::log;
use Log::Log4perl;

###################################################################################
### This is provided to enable basic logging for the tsheets module.  		###
### It's meant to be verbose, mildly obnoxious, and static.  If you 		###
### don't like it, feel free to override it by passing your own log4perl 	###
### object to the tsheets new method using the logger param.			###
###################################################################################

sub new { 
	my $logLevel = shift;
	if (!$logLevel) { $logLevel = 'DEBUG'; }

	my $log_conf = <<END;
		log4perl.category.TSheets          = $logLevel, Screen

		log4perl.appender.Screen                            = Log::Log4perl::Appender::Screen
		log4perl.appender.Screen.stderr                     = 0
		log4perl.appender.Screen.layout                     = Log::Log4perl::Layout::PatternLayout
		log4perl.appender.Screen.layout.ConversionPattern   = TS[%d %L:%p]: %m{chomp}%n

END

	Log::Log4perl::init( \$log_conf );
	$log = Log::Log4perl::get_logger("TSheets");
	return $log;
}

1;

package tsheets;

use strict;
use warnings;

use Moose;
use JSON::XS;
use LWP::UserAgent;
use Data::Dumper;
use XML::Simple;
use Time::HiRes qw(gettimeofday tv_interval);

use parent;

our $VERSION = '0.01';

has 'config' 				=> 	( 	
							'is' 		=> 	'rw', 	
							'isa' 		=> 	'Str', 	
							'required'	=> 	0 
						);
has 'client_url' 			=> 	( 	
							'is' 		=> 	'rw', 	
							'isa' 		=> 	'Str', 	
							'required'	=> 	0 
						);
has 'token' 				=> 	( 	
							'is' 		=> 	'ro', 	
							'isa' 		=> 	'Str', 	
							'required'	=> 	0 
						);
has 'api_key' 				=> 	( 	
							'is' 		=> 	'rw',     
							'isa' 		=> 	'Str', 	
							'required'	=> 	0 
						);
has 'username' 				=> 	( 	
							'is' 		=> 	'rw', 
							'isa' 		=> 	'Str', 	
							'required'	=> 	0 
						);
has 'password' 				=> 	( 	
							'is' 		=> 	'rw', 	
							'isa' 		=> 	'Str', 	
							'required'	=> 	0 
						);
has 'pants_on_the_ground' 	=> 		( 	
							'is' 		=> 'rw', 	
							'isa' 		=> 'Str', 	
							'required' 	=> 	0, 	
							'default' 	=> 	'false' 			
						);
has 'logger'				=> 	(	
							'is' 		=> 'rw',		
							'isa' 		=> 'Any',	
							'required'	=> 	0,	
						);

has 'log_level'				=>	(
                            'is'        => 'rw',
                            'isa'       => 'Str',
                            'required'  =>  0,
						);


################################# Structural Methods #################################

sub BUILD {
	my $self = shift;
	my @tsheets_config;
	my $config;

	unless (ref $self->{logger} eq "Log::Log4perl::Logger") { 
		if ($self->{log_level}) { 
			$self->{logger} = tsheets::log::new($self->{log_level});
		} else { 
			$self->{logger} = tsheets::log::new('DEBUG');
		}
	}

	$self->{logger}->debug("Building TSheets Object...");
	if ($self->config) { 
		if (-e $self->config) { 
			$self->{logger}->debug("Reading " . $self->config);
			open (READ_TSHEETS_CONFIG, $self->config);
			@tsheets_config = <READ_TSHEETS_CONFIG>;
			close(READ_TSHEETS_CONFIG);
			$self->{logger}->debug("Parsing " . $self->config);
			$config = decode_json(join(" ", @tsheets_config));
			$self->{logger}->debug("Finished parsing " . $self->config);
			if (defined($$config{username})) { 
				$self->{username} = $$config{username};
				if (defined($$config{password})) { 
					$self->{password} = $$config{password};
					if (defined($$config{api_key})) { 
						$self->{api_key} = $$config{api_key};
						if (defined($$config{client_url})) { 
							$self->{client_url} = $$config{client_url};
						} else { 
							return $self->_error("Unable to find the client_url key in " . $self->config);
						}
					} else { 
						return $self->_error("Unable to find the api_key key in " . $self->config);
					}
				} else { 
					return $self->_error("Unable to find the password key in " . $self->config);
				}
			} else { 
				return $self->_error("Unable to find the username key in " . $self->config);
			}
		} else { 
			return $self->_error("The path to your configration file (" . $self->config . ") is invalid.");
		}
	} else { 
		if ($self->client_url) { 
			if ($self->api_key) { 
				if ($self->username) { 
					unless ($self->password) { 
						return $self->_error("You must define a password or config file when calling 'new'");
					}
				} else { 
					return $self->_error("You must define a username or config file when calling 'new'");
				}
			} else { 
				return $self->_error("You must define an api_key or config file when calling 'new'");
			}
		} else { 
			return $self->_error("You must define a client URL or config file when calling 'new'");
		}
	} 

	# Now that we're sure that everything is kosher, let's get our token.
	
	$self->{logger}->debug("Getting Token");
	$self->{token} = $self->_getToken();
	if ($self->pants_on_the_ground eq "true") { 
		$self->{logger}->debug("Got Token: (" . $self->{token} . ")");
	}
	$self->{logger}->debug("Logging Into TSHeets");
	my $login = $self->_login();
	unless ($login eq "ok") { 
		$self->{logger}->fatal("Unable to log into TSheets!");
	} else { 
		$self->{logger}->debug("Successfully logged into TSheets");
	}
	$self->{logger}->debug("Finished Building tshets object...");
}

sub DEMOLISH { 
	my $self = shift;
	if (defined($self->{dbh})) { 
		$self->{dbh}->disconnect();
	}
}



################################# Private Methods #################################

sub _login { 
	my $self = shift;
	$self->{logger}->debug("Logging In...");
	if ($self->pants_on_the_ground eq "true") { 
		$self->{logger}->debug("Logging In With Token: " . $self->{token});
		$self->{logger}->debug("Logging In With Username: " . $self->{username});
		$self->{logger}->debug("Logging In With Password: " . $self->{password});
	}
	my $request = $self->_makeRequest({
		'action'=>'login',
		'token'=>$self->{token},
		'username'=>$self->{username},
		'password'=>$self->{password}
	});

	$self->{logger}->debug("Login request completed with status: " . $$request{status});

	return $$request{status};
}

sub _getURL { 
	my $self = shift;
	return $self->client_url . "/api.php";
}

sub _makeRequest { 
	my $self 	= shift;
	my $params 	= shift;
	my $paramsArray = ();
	my $format	= "XML";
	my $ua 		= LWP::UserAgent->new;
	my $method 	= "post";
	my $URL;
	my @queryStringParams;
	my $response;
	$self->{logger}->debug("Assembling Request Parameters");
	$ua->timeout(10);
	$ua->env_proxy;

	if (defined($$params{output_format}) && $$params{output_format} eq "json") { 
		$format = "JSON";
	} else { 
		$format = "XML";
	}

	if (defined($$params{method})) {
		if (lc($$params{method}) eq "post") { 
			$self->{logger}->debug("Setting method to POST");
			$method = "post";
		} elsif (lc($$params{method} eq "get")) { 
			$self->{logger}->debug("Setting method to GET");
			$method = "get";
		}
		delete($$params{method});
	} 

	$URL = $self->_getURL();

	if ($method eq "get") { 
		$URL .= "?";
		$self->{logger}->debug("BASE URL: $URL");

		foreach my $key (keys %{$params}) {
			$self->{logger}->debug("Adding Param: $key=$$params{$key}");
			push @{$paramsArray}, "$key=$$params{$key}";
		}

		$URL .= join('&',@{$paramsArray});
		$self->{logger}->debug("GET'ing: $URL");
		$response = $ua->get($URL);
		$self->{logger}->debug("GOT the afore mentioned URL");
	} else { 
		$self->{logger}->debug("POST'ing the following params to: $URL");
		foreach my $key (sort keys %{$params}) { 
			$self->{logger}->debug("KEY:($key) VALUE($$params{$key})");
		}
		$response = $ua->post($self->_getURL,$params);
		$self->{logger}->debug("POSTed to the afore mentioned URL: $URL");
	}
	if ($response->is_success) { 
		$self->{logger}->debug("The response from TSheets was successful! Decoding returned content");
		if ($format eq "XML") { 
			return XMLin($response->decoded_content);
		} else { 
			print Dumper(decode_json($response->decoded_content));
			return decode_json($response->decoded_content);
		}
		$self->{logger}->debug("FInished decoding content from TSheets");
	} else { 
		return $self->_error("The request to ($URL) resulted in this error: (" . $response->status_line . ")");
	}	
}

sub _getToken { 
	my $self = shift;
	my $request = $self->_makeRequest({'api_key'=>$self->{api_key},'action'=>'get_token'});
	if ($$request{status} eq "ok") { 
		return $$request{token};
	}
}

sub _genericRequest { 
	my $self = shift;
	my $action = shift;
	my $params = shift;
	$$params{action} = $action;
	$$params{token}  = $self->{token};
	return $self->_makeRequest($params);
}

sub _error {
	my $self    = shift;
	my $error   = shift;
	$self->{logger}->error($error);
	return {'status'=>'fail','last_error'=>$error};
}

sub _startTimer {
	my $self = shift;
	if ($self->{timer_running}) {
	    return $self->_error("The timer is already running.");
	} else {
	    $self->{timer_running} = 1;
	    $self->{timer_start}   = [gettimeofday];
	    return {'status'=>'ok'};
	}
}

sub _stopTimer {
	my $self        = shift;
	my $end         = undef;
	my $interval    = undef;
	if ($self->{timer_running}) {
	    $end = [gettimeofday];
	    $interval = tv_interval $self->{timer_start}, $end;
	    $self->{timer_start} = undef;
	    $self->{timer_running} = undef;
	    return {'status'=>'ok','interval'=>$interval};
	} else {
	    return $self->_error("The timer wasn't running.  Sorry!");
	}
}

################################# Public Methods #################################

sub delJob { 
	my $self = shift;
	my $params = shift;
	if (!$$params{job_code_id}) { 
		return $self->_error("You muse specify a job_code_id for the delJob call");
	}
	return $self->_genericRequest('jobcode_delete',$params);
}

sub addJob { 
	my $self = shift;
	return $self->_genericRequest('jobcode_add',shift);
}

sub editJob { 
	my $self = shift;
	return $self->_genericRequest('jobcode_edit',shift);
}

sub listJobs { 
	my $self 			= shift;
	my $params 			= shift;
	my %tmp				= ();
	my @tJobs 			= ();
	my @jobs			= ();
	my $counter 		= 0;
	my $processMore 	= 1;
	my $response 		= undef;
	my $countedJobs		= 0;
	my $interval		= undef;


	# Make sure that this is hard-coded to the XML
	# format.  Until I can compensate for the 
	# dramatic differences between the JSON and 
	# XML responses,  we'll have to force XML for 
	# certain calls.

	$$params{output_format} = "xml";

	$$params{action} = 'get_jobcodes';
	$$params{token}  = $self->{token};
	if (!$$params{page}) { 
		$$params{page} = 1;
	}

	unless (defined($$params{per_page})) { 
		$$params{per_page} = '500';
	}

	if (defined($$params{'parent_ids'})) { 
		if (ref $$params{'parent_ids'} eq 'ARRAY') { 
			$$params{'parent_ids'} = join(',',@{$$params{'parent_ids'}});
		}
	}

	while ($processMore != 0) { 
		$self->_startTimer();
		$processMore = 0;
		#$currentPage = 0;
		$response = $self->_makeRequest($params);
		if ($$response{status} eq "ok") {
			# Let the API tell us if we need to process more...
			$processMore = $$response{jobcodes}{more};	
			foreach my $attr (keys %{$$response{jobcodes}{results}}) {
				$counter = 0;
				if (ref $$response{jobcodes}{results}{$attr} eq "ARRAY") {
					foreach my $val (@{$$response{jobcodes}{results}{$attr}}) {
						if (ref $val eq "HASH") { $val = '0'; }
						$tJobs[$counter]{$attr} = $val;
						$counter++;
					}
				} elsif (ref $$response{jobcodes}{results}{$attr} eq "") {
					$jobs[$counter]{$attr} = $$response{jobcodes}{results}{$attr};
				}
			}

			# Now that we've processed the current page, we need to copy the 
			# current page off to another array that can be returned.

			foreach my $jobCodeRef (@tJobs) { 
				push @jobs, $jobCodeRef;	
			}
		} else { 
			$processMore = 0;
		}

		$countedJobs = @jobs;
		$interval = $self->_stopTimer();
		$self->{logger}->info("Processed Page $$response{jobcodes}{page} with a max $$response{jobcodes}{per_page} results in $$interval{interval} seconds. There are $countedJobs total");

		# And we reset everything for the next iteration
		# I'm anal about this.  
		@tJobs = ();
		$counter = 0;
		$response = undef;
		$$params{page}++;
	}

	$self->{logger}->debug("Done processing!  Returning!");
	return \@jobs;
}

sub editUser { 
	my $self = shift;
	my $params = shift;
	if (!$$params{username}) { 
		return $self->_error("You must define a username for the editUser call");
	}
	$$params{action} = "user_edit";
	$$params{token}  = $self->{token};
	my $response = $self->_makeRequest($params);
	return $response;
}

sub whoIsWorking { 
	my $self = shift;
	my $params = shift;
	my $response;
	$$params{action} = "get";
	$$params{token}  = $self->{token};
	$$params{property} = 'clocked_in|clocked_in_for|day_total|fname|lname|username';
	$response = $self->_makeRequest($params);
	return $response;
}

sub assignJobCode { 
	my $self = shift;
	my $params = shift;
	my $response;

	if (!$$params{job_code_id}) { 
		return $self->_error("You must provide a job_code_id for the assignJobCode call");
	}

	if (!$$params{username}) { 
		return $self->_error("You must provide a username for the assignJobCode call");
	}
		
	$$params{action} = "jobcode_assign";
	$$params{token}  = $self->{token};

	return $self->_makeRequest($params);
}

sub unassignJob { 
	my $self    = shift;
	my $params  = shift;

	if (!$$params{job_code_id}) {
		return $self->_error("You must provide a job_code_id for the unassignJob call");
	}

	$$params{token}  = $self->{token};
	$$params{action} = 'jobcode_unassign';
	return $self->_makeRequest($params);
}

sub addUser { 
	my $self = shift;
	my $params = shift;

	$$params{group_id} = '0';
	
	# Enforce Requred Params
	my @requiredParams = qw(fname lname username passwd group_id);
	foreach my $param (@requiredParams) { 
		unless(defined($$params{$param})) { 
			return $self->_error("$param is required for the addUser call");
		}
	}

	$$params{action} = "user_add";
	$$params{token}  = $self->{token};
	return $self->_makeRequest($params);
}

sub clockIn {
	my $self = shift;
	return $self->_genericRequest('clock_in',shift);
}

sub clockOut {
	my $self = shift;
	return $self->_genericRequest('clock_out',shift);
}

sub switchJobs {
	my $self = shift;
	return $self->_genericRequest('job_code_switch',shift);
}

sub addTimesheetNotes { 
	my $self    = shift;
	my $params  = shift;

	$$params{token}  = $self->{token};
	$$params{action} = 'replace_notes';
	$$params{append} = 0;
	if (defined($$params{notes})) {
		if (length($$params{notes}) > 2000) {
			$$params{notes} = substr($$params{notes},0,1999);
		}
	}
	return $self->_makeRequest($params);
}

sub appendTimesheetNotes { 
	my $self    = shift;
	my $params  = shift;

	$$params{token}  = $self->{token};
	$$params{action} = 'replace_notes';
	$$params{append} = 1;
	if (defined($$params{notes})) {
		if (length($$params{notes}) > 2000) {
			$$params{notes} = substr($$params{notes},0,1999);
		}
	}

	return $self->_makeRequest($params);
}

sub addManualTime { 
	my $self    = shift;
	my $params  = shift;

	if (defined($$params{date})) { 
		if (defined($$params{hours})) { 
			if (defined($$params{job_code_id})) { 
				# We're good to go!  
				
				# Some additional testing... 
				if (defined($$params{notes})) { 
					if (length($$params{notes}) > 2000) { 
						$$params{notes} = substr($$params{notes},0,1999);
					}
				}
				$$params{token}  = $self->{token};
				$$params{action} = 'manual_time';
				return $self->_makeRequest($params);
			} else { 
				# Job Code Undefined
				return $self->_error("You must define a job code for the addManualTime call");
			}
		} else { 
			# Hours undefined
			return $self->_error("You must define hours for the addManualTime call");
		}
	} else { 
		# date undefined
		return $self->_error("You must define a date for the addManualTime call");
	}
}

sub logGPSLoc { 
	my $self    = shift;
	my $params  = shift;

	if (defined($$params{latitude})) { 
		if (defined($$params{longitude})) { 
			    $$params{token}  = $self->{token};
			    $$params{action} = "gps_log";
			    return $self->_makeRequest($params);
		} else { 
			return $self->_error("You must define longitude for the logGPSLoc call");
		}
	} else { 
		return $self->_error("You must define latitude for the logGPSLoc call");
	}
	return undef;
}

sub isUserLoggedIn { 
	my $self    = shift;
	my $params  = shift;

	$$params{token}  = $self->{token};
	$$params{action} = "get";
	$$params{property} = 'logged_in';
	return $self->_makeRequest($params);
}

sub isUserClockedIn { 
	my $self    = shift;
	my $params  = shift;

	$$params{token}  = $self->{token};
	$$params{action} = "get";
	$$params{property} = 'clocked_in';
	return $self->_makeRequest($params);
}

sub getUserData { 
	my $self 	= shift;
	my $params 	= shift;

	$$params{token}  = $self->{token};
	$$params{action} = "get";
	$$params{property} = 'fname|lname|settings';
	return $self->_makeRequest($params);
}

sub getTotalHours { 
	my $self 		= shift;
	my $params 		= shift;
	my $property	= "day_total";

	if ($$params{period}) { 
		if ($$params{period} eq "week") { 
			$property = "week_total";
		} else { 
			$property = "day_total";
		}
		delete($$params{period});
	} else { 
		$property = "day_total";
	}

	$$params{token}  = $self->{token};
	$$params{action} = "get";
	$$params{property} = $property;
	return $self->_makeRequest($params);
}

################################################
### TODO: This is undocumented and untested. ###
### TODO: Document and test!                 ###
################################################
#
#sub getProjectHours { 
#    my $self    = shift;
#    my $params  = shift;
#
#    $$params{token}  = $self->{token};
#    $$params{action} = "get_project_hours";
#    $$params{output_format} = "json";
#
#    return $self->_makeRequest($params);
#}
#############################################

sub getTimesheets { 
	my $self    = shift;
	my $params  = shift;

	if (defined($$params{start_date})) { 
		if (defined($$params{end_date})) { 
			if ($$params{start_date} =~ /^\d{4}-\d{2}-\d{2}$/) { 
				if ($$params{end_date} =~ /^\d{4}-\d{2}-\d{2}$/) {
					$$params{token}  = $self->{token};
					$$params{action} = "get_timesheets";
					return $self->_makeRequest($params);
				} else { 
					# Invalid end date
					$self->_error("The end_date defined ($$params{end_date} is invalid.  FORMAT: YYYY-MM-DD");
				}
			} else { 
				# invalid Start Date
				$self->_error("The start_date defined ($$params{start_date}) is invalid.  FORMAT: YYYY-MM-DD");
			}
		} else { 
			# Undefined End Date
			$self->_error("You must define an end_date");
		}
	} else { 
		# Undefined Start Date
		$self->_error("You must define a start_date");
	}
	return undef;
}

sub logFailedRequest { 
	my $self = shift;
        return $self->_genericRequest("log_failed_request",shift);
}

sub logout { 
	my $self = shift;
	$self->{logger}->debug("Logging out");
	my $request = $self->_makeRequest({'action'=>'logout','token'=>$self->{token}});
	$self->{logger}->debug("Log out request completed with status: (" . $$request{status} . ")");
	return $$request{status};
}

no Moose;
1;
__END__

=head1 NAME

	tsheets - OO Perl interface to the TSheets RESTful API


=head1 DESCRIPTION

	Perl Library that provides a full, true OO interface to the TSheets Time Tracking system

=head1 DISCLAIMER

	This library is provided by a third-party and is not endorsed 
	or supported by TSheets (www.tsheets.com).  TSheets does not 
	provide support for this module. Please use at your own risk!

=head1 EXPORT

	None by default.

=head1 SYNOPSYS

	use strict;     # You use strict, right?
	use tsheets;    # Use the tsheets module
	
	my $ts = tsheets->new(
		'config' => '/path/to/config.json', 
		'username' => 'YourUsername',
		'password' => 'YourPassword',
		'api_key'   => 'YourAPIKey',
		'client_url' => 'YourClientURL',
		'pants_on_the_ground' => 'false', 
	);

	...

	$ts->logout();

=head1 METHODS

=head2 Operational Methods 

=head4 new

	Sample: my $ts = tsheets->new(
                	'config' => '/path/to/config.json',
                	'username' => 'YourUsername',
                	'password' => 'YourPassword',
                	'api_key'   => 'YourAPIKey',
                	'client_url' => 'YourClientURL',
                	'pants_on_the_ground' => 'false',
        	);
	Params:
		config
			Required: No
			Description: Defines the path to a configuration file that 
				     containes the values for all of the following 
				     directives.  If config is defined, all of the 
				     following directives are optional.
		username
			Required: Yes, unless config contains a path to a file that defines this param
			Description: Defines your username

		password
			Required: Yes, unless config contains a path to a file that defines this param
			Description: Defines your password

		api_key
			Required: Yes, unless config contains a path to a file that defines this param
			Description: Defines your API key
	
		client_url
			Required: Yes, unless config contains a path to a file that defines this param
			Description: Defines the URL that this API uses to talk to TSheets.  It's strongly
				     reccomended that you use HTTPS.  

		pants_on_the_ground
			Required: No.  
			Description: This is a very optional param that you should never set to "true" 
				     in a production environment!  If set to true, it will log sensitive
				     data and leave you lookin' like a fool with your pants on the ground.
				     Don't get caught with your pants on the ground!  Don't enable this in 
				     a production environment!  You've been warned!

	Purpose: Creates a new TSheets object.

=head4 logout

	Sample: $ts->logout();

	Params: None

	Purpose: Ends your TSheets API session

=head2 User Related Methods

=head4 addUser

	Sample: $ts->addUser({
					'fname'=>'Elmer',
					'lname'=>'Fudd',
					'username'=>'efudd',
					'passwd'=>'waskiwyWabbit',
					'email'=>'efudd@efudd.com'
			});

	Params: 

		fname:
			Required: Yes
			Description: First name for user.

		lname:
			Required: Yes
			Description: Last name for user.

		username:
			Required: Yes
			Description: Username for user.

		passwd:
			Required: Password for user.
			Description: Yes

		group_id:
			Required: Yes
			Description: Id of the group you want the user assigned to. 
						 This must be a numeric id obtained from the list_groups action 
						 
						 NOTE: list_groups action not available yet, notify support if you
						 require this. In the meantime, you may assign a group_id of 0 to 
						 ensure that you can still create users

		email:
			Required: No
			Description: Email address for the user. 

		employee_id:
			Required: No
			Description: Custom employee id associated with the user. This is usually used 
						 to store an external payroll id or something similar.

		payrate:
			Required: No
			Description: Float - represents dollar amount user earns over period stored in timeframe. 

		timeframe:
			Required: No
			Description: One of hour, week, or year. Used in conjunction with payrate 

		permission:
			Required: No
			Description: Name of the permission you want to assign or unassign to/from a user. 
						 List of available permissions can be obtained by calling 'get' action 
						 with property 'perms'. 

		perm_value:
			Required: No
			Description: Must be used in conjunction with parameter 'permission'. 1 or 0. 
						 1 turns on the permission, or assigns it. 
						 0 turns off the permission, or unassigns it. 

	Purpose: Adds a user to the TSheets system

=head4 editUser

	Sample: $ts->editUser({'username'=>'efudd','passwd'=>'killD4Wabb1t!'});

	Params:

		username
			Required: Yes
			Description: Username for user you want to edit. If blank the currently logged on user is edited.

		fname
			Required: No
			Description: First name for user. 

		lname
			Required: No
			Description: Last name for user.

		new_username
			Required: No
			Description: New username you want to assign to the user.

		passwd
			Required: No
			Description: Password for user.

		group_id
			Required: No
			Description: Id of the group you want the user assigned to. 
						 This must be a numeric id obtained from the list_groups action
						 NOTE: list_groups action not available yet, notify support 
						 if you require this

		email
			Required: No
			Description: Email address for the user

		employee_id
			Required: No
			Description: Custom employee id associated with the user. 
						 This is usually used to store an external 
						 payroll id or something similar

		payrate
			Required: No
			Description: Float - represents dollar amount user earns over period stored in timeframe.

		timeframe
			Required: No
			Description: One of hour, week, or year. Used in conjunction with payrate

		permission
			Required: No
			Description:  Name of the permission you want to assign or unassign to/from a user. 
						  List of available permissions can be obtained by calling 'get' action 
						  with property 'perms'.

		perm_value
			Required: No
			Description: Must be used in conjunction with parameter 'permission'. 1 or 0. 
						 1 turns on the permission, or assigns it. 
						 0 turns off the permission, or unassigns it.

	Purpose: Edits a user in the TSheets system.

=head4 delUser

	Sample: $ts->({'username'=>'efudd'});

	Params:

		username:
			Required: Yes 
			Description: Username for user you want to delete.

	Purpose: Deletes a user in the TSheets system


=head4 isUserLoggedIn

	Sample: $ts->isUserLoggedIn({'username'=>'efudd'});
	Params:
		username
			Required: No
	Purpose: Tells you if a user is logged into TSheets

=head4 isUserClockedIn

	Sample: $ts->isUserClockedIn({'username'=>'efudd'});
	Params:
		username
			Required: No
			Description: You may specify the username of the user that you 
						 want to check on.  If no username is supplied, 
						 the current user [that you're connecting to the API with]
						 is assumed.
	Purpose: Tells you if a user is clocked into a job

=head4 getUserData

	Sample: $ts->getUserData({'username'=>'efudd'});
	Params:
		username
			Required: No
			Description: Specifies the user to get data for.
						 If no user is specified the current user [that you're
						 connecting to the API with] is assumed.

	Purpose: Retrieves basic data for the user specified.

=head4 getTotalHours

	Sample: $ts->getTotalHours({});
	Params:
		period
			Required: No
			Description: Specifies the duration of the report. "day" returns a single 
				     day and "week" returns a single week.  Defaults to "day" if 
				     undefined.
		username
			Required: No
			Description: Specified the user that you want to report on. 
				     If undefined, the current user is assumed.  

	Purpose: Returns the number of hours an employee has logged in the last day or week.

=head2 Job Related Methods


=head4 addJob

	Sample: $ts->addJob({});
	Params:

		job_code_name
			Required: Yes
			Description: The name of the job code you'd like to add.

		job_code_type
			Required: Yes
			Description: Specify 'regular' or 'pto'. Defaults to regular if this 
						 parameter is not specified.

		parent_id
			Required: No
			Description: If 0, the new job code will be a top-level job code. 
						 Otherwise, specify the id of the job code you want as 
						 the parent. If no parent_id is specified, 0 is assumed.
		global
			Required: no
			Description: Specify '1' to cause this new job code to be assigned 
						 to all employees (current and future).
 
		assign_all
			Required: No
			Description: Specify '1' to cause this new job code to be added to 
						 all existing employees (new employees won't have it assigned).

		billable
			Required: No
			Description: Specify '1' to cause this new job code to have the billable flag set.

		alias
			Required: No
			Description: The SMS alias (short code) to be used for this job code when using text messages to clock in/out

	Purpose: Adds a job

=head4 editJob

	Sample: $ts->editJob({});
	Params:
		job_code_id
			Required: Yes
			Description: The id associated with the job code you want to change

		job_code_name
			Required: Yes
			Description: The new name you want to give to the job code. 
			Either this parameter, the new_job_code_type parameter, or both, 
			must be specified.

		new_job_code_type
			Required: No
			Description: Specify 'regular' or 'pto'. Defaults to regular 
						 if this parameter is not specified.

		parent_id
			Required: No
			Description: If 0, the new job code will be a top-level job code. 
					 	 Otherwise, specify the id of the job code you want as 
						 the parent.

		global
			Required: No
			Description: Specify '1' to cause this new job code to be 
					     assigned to all employees (current and future).

		billable
			Required: No
			Description: Specify '1' to cause this new job code to have the 
						 billable flag set.

		alias
			Required: No
			Description: The SMS alias (short code) to be used for this 
						 job code when using text messages to clock in/out

	Purpose: Edit/Change a job code

=head4 delJob

	Sample: $ts->delJob({});
	Params:
		job_code_id
			Required: Yes
			Description: The ID for the job code that you want to delete.

	Purpose: Deletes a job

=head4 listJobs

	Sample: $ts->listJobs({});
	Params:
		assigned_to
			Required: No
			Description: A username or user_id. Causes the returned list to only 
						 contain jobcodes assigned to this person. Must be an admin 
						 or have permissions to manage this user.

		ids
			Required: No
			Description: The API will only return jobcodes with these id's. When you pass a 
						 value in this parameter, 'parent_ids' is ignored and all matching 
						 records are returned, even if they have different parent_id's. 
						 If empty, all jobcodes for the given parent_ids will be returned.

		parent_ids
			Required: No
			Description: Comma separated string of parent_id's. Default is 0. Will only 
						 return jobcodes with these parent_id's.

		active
			Required: No
			Description: yes, no, or both. Default is yes. When yes, only returns active jobcodes. 
						 When no, only returns inactive jobcodes. When both, active and inactive 
						 jobcodes are returned.

		type
			Required: No
			Description: regular, pto, or all. Default is all. When regular, only returns regular 
						 jobcodes. When pto, only returns pto jobcodes. When all, all jobcodes are 
						 returned.

		per_page
			Required: No
			Description: Integer. Default is 50. Max allowed is 1000. Used to specify how many 
						 results per page you want returned.

		page
			Required: No
			Description: Integer. Default is 1. Used to specify which page of results you want returned.


	Purpose: Lists jobs

=head4 assignJobCode

	Sample: $ts->assignJobCode({});
	Params:
		job_code_id
			Required: Yes
			Description: The id associated with the job code you want to assign. 

		username
			Required: No
			Description: The username you want to assign the job code to. 
						 If omitted, the currently logged in user is used.

	Purpose: Assigns a job to a user

=head4 unassignJob

	Sample: $ts->unassignJob({});
	Params:
		job_code_id
			Required: Yes
			Description: The id associated with the job code you want to assign. 

		username
			Required: No
			Description: The username you want to assign the job code to. 
						 If omitted, the currently logged in user is used.

	Purpose: Removed a user->job assignment

=head2 Timesheet Related Methods

=head4 clockIn

	Sample: $ts->clockIn({});
	Params:

		job_code_id
			Required: Maybe
			Description: The job-code ID that you would like to clock in with. 
						 This parameter is optional if the user has 0 or 1 
						 job-codes assigned. Otherwise it is required.

		notes
			Required: No
			Description: A text note to place on the timesheet. Max 2000 characters.

		seconds
			Required: No
			Description: An integer >= 0. Treat this action as though it happened 
						 X number of seconds in the past.

		username
			Required: No
			Description: Assumes the role of the user specified before taking action. 
					     Requires the admin or manage_timesheets permission.
	Purpose: Clocks a user in

=head4 clockOut

	Sample: $ts->clockOut({});
	Params:
		notes
			Required: No
			Description: A text note to place on the timesheet. Max 2000 characters.

		seconds
			Required: No
			Description: An integer >= 0. Treat this action as though it happened 
						 X number of seconds in the past.

		username
			Required: No
			Description: Assumes the role of the user specified before taking action. 
						 Requires the admin or manage_timesheets permission.


	Purpose: Clocks a user out of the job they're logged into

=head4 switchJobs

	Sample: $ts->switchJobs({});

	Params:

		job_code_id
			Required: Yes
			Description: The job-code ID that you would like to switch to.

		notes
			Required: No
			Description: A text note to place on the timesheet. Max 2000 characters.

		seconds
			Required: No
			Description: An integer >= 0. Treat this action as though it happened 
						 X number of seconds in the past.

		username
			Required: No
			Description: Assumes the role of the user specified before taking action. 
					     Requires the admin or manage_timesheets permission.
		
	Purpose: Close (clock-out of) the user's current timesheet, and clock them in 
			 again under a new job-code.

=head4 addTimesheetNotes

	Sample: $ts->addTimesheetNotes({});
	Params:
		notes
			Required: Yes
			Description: A text note to place on the timesheet. 
						 Max 2000 characters. Replaces existing 
						 notes.

		username
			Required: No
			Description: Assumes the role of the user specified before taking action. 
						 Requires the admin or manage_timesheets permission.

	Purpose: Adds or replaced notes for the user's current timesheet

=head4 appendTimesheetNotes

	Sample: $ts->appendTimesheetNotes({});
	Params:
		notes
			Reqired: Yes
			Description: A text note to place on the timesheet
						 Max 2000 characters. Replaces existing
						notes.

		username
			Required: No
			Description: Assumes the role of the user specified before taking action.
						 Requires the admin or manage_timesheets permission.

	Purpose: Appends information to the user's current timesheet note

=head4 addManualTime

	Sample: $ts->addManualTime({});
	Params:
		date
			Required: Yes
			Description: A date in the format YYYY-MM-DD when you would 
						 like the time to be recorded.

		hours
			Required: Yes
			Description: A decimal >= 0.0. This value is converted to 
						 whole seconds before being stored.

		job_code_id
			Required: Yes
			Description: The job-code ID that you would like to record time against. 
						 If the user has 0 job-codes assigned, use job_code_id 0.

		notes
			Required: No
			Description: A text note to place on the timesheet. Max 2000 characters.

		username
			Required: No
			Description: Add hours for this user. Requires the admin or manage_timesheets 
						 permission. If blank, the currently logged in user is assumed.

	Purpose:

=head4 logGPSLoc

	Sample: $ts->logGPSLoc({});
	Params:
		latitude
			Required: Yes
			Description: An angular measurement in degrees ranging from 0 deg. at the equator 
						 (low latitude) to 90 deg. at the North pole or -90 deg. at the South 
						 pole. May include up to 6 decimal places. 

		longitude
			Required: Yes
			Description: An angular measurement ranging from 0 deg. at the prime meridian to +180 
						 deg. eastward and -180 deg. westward. May include up to 6 decimal places.

		accuracy
			Required: No
			Description: A radius (in meters). Defaults to 3000.

		altitude
			Required: No
			Description:  A measurement (in meters) of vertical distance from sea-level. Defaults to zero.

		activity
			Required: No
			Description: A keyword indicating what activity was requested in conjunction with this GPS point. 
						 Possible actions are: ci (clock-in), co (clock-out), notes (adding notes), 
						 switch (switch jobcode), none (no action - default).

		seconds
			Required: No
			Description: An integer >= 0. Treat this action as though it happened X number of seconds in the past.

		username
			Required: No
			Description:  Assumes the role of the user specified before taking action. 
						  Requires the admin or manage_timesheets permission.

	Purpose: Record a user's current (or past) location.

=head4 getTimesheets

	Sample: $ts->getTimesheets({});
	Params: 
		start_date
			Required: Yes
			Description: Report start date in YYYY-MM-DD format.

		end_date
			Required: Yes
			Description: Report end date in YYYY-MM-DD format. 
						 Maximum date range is 375 days.

		job_code_id
			Required: No
			Description: Returns timesheets with a matching job_code_id only.

		users
			Required: No
			Description: Returns only timesheets for the specified user ID(s). 
						 Separate multiple IDs with a comma.

	Purpose: Get a raw list of timesheets.

=head4 whoIsWorking

	Sample: $ts->whoIsWorking();

	Params: None

	Purpose: Returns a list of all users that are currently working

=head4 logFailedRequest

	Sample: $ts->logFailedRequest({'data'=>'action%3Dclock_in%26job_code_id%3D123'});

	Params:

		data
			Required: Yes
			Description: The API action (and accompanying parameters) that failed. 
						 This string must be url-encoded to ensure any special characters 
						 in the string are successfully passed to the API.

	Purpose: The "log_failed_request" API action is useful if you're trying to synch 
			 actions that were completed while offline, and you encounter conflicts or 
			 errors. If you cannot complete an action, you can at least log it so that 
			 it can be reviewed later by the TSheets team to determine the cause of the 
			 failure/conflict. 


=head1 SEE ALSO

	The TSheets wiki: http://wiki.tsheets.com/
	The orginal TSheets API: http://wiki.tsheets.com/wiki/API


=head1 AUTHOR

	Scott Cudney <lt>tsheets-module-dev@cudneys.net<gt>


=head1 COPYRIGHT AND LICENSE

	Copyright (C) 2012 by Scott Cudney

	This library is free software; you can redistribute it and/or modify
	it under the same terms as Perl itself, either Perl version 5.14.2 or,
	at your option, any later version of Perl 5 you may have available.

=cut
