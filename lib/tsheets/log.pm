package tsheets::log;
use Log::Log4perl;

###################################################################################
### This is provided to enable basic logging for the tsheets module.        ###
### It's meant to be verbose, mildly obnoxious, and static.  If you         ###
### don't like it, feel free to override it by passing your own log4perl    ###
### object to the tsheets new method using the logger param.            ###
###################################################################################

sub new {
    my $logLevel = shift;
    if (!$logLevel) { $logLevel = 'DEBUG'; }

    my $log_conf = <<END;
        log4perl.category.TSheets          = $logLevel, Screen

        log4perl.appender.Screen                            = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.stderr                     = 1
        log4perl.appender.Screen.layout                     = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern   = TS[%d %L:%p]: %m{chomp}%n

END

    Log::Log4perl::init( \$log_conf );
    $log = Log::Log4perl::get_logger("TSheets");
    return $log;
}

1;
