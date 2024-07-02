unit class Our::Redis:api<1>:auth<Mark Devine (mark@markdevine.com)>;

#   Can't use Redis::Async in all corporate environments due to
#   networking/security constraints.  SSH tunneling is required
#   to solve this, but SSH::LibSSH::Tunnel is NYI.  As a fall
#   back, run /usr/bin/redis-cli through SSH for remotes:
#
#       `/bin/ssh -L lp:rs:rp rs /usr/bin/redis-cli`
#
#   The next problem is that SETting any $value > ~200KB in
#   memory bombs.  This Class will spurt it down to a temp file,
#   then:
#
#       $proc.in.slurp($path) # | /usr/bin/redis-cli -x SET $key
#
#   All Proc's of /usr/bin/redis-cli are running error-free now.

use JSON::Fast;
use Our::Cache;

constant        $local-server-default               = '127.0.0.1';
constant        $local-port-default                 = 6379;
constant        $redis-server-default               = '127.0.0.1';
constant        $redis-port-default                 = 6379;

has Str         @!connect-prefix;
has Str         $.local-server          is built;
has Int         $.local-port            is built;
has Str         $.redis-server          is built;
has Int         $.redis-port            is built;
has Bool        $.tunnel                is built;

has Our::Cache  $!cache-manager;

submethod TWEAK {
    my $redis-servers-cache     = Our::Cache.new(:subdir('redis-servers',));
    my $write                   = False;
    $redis-servers-cache.set-identifier(:identifier<inventory>);
    if $redis-servers-cache.cache-hit {
        my $json                = from-json($redis-servers-cache.fetch(:identifier<inventory>));
        $!local-server          = $json<local-server>                   if $json<local-server>  && !$!local-server;
        $!local-port            = $json<local-port>                     if $json<local-port>    && !$!local-port;
        $!redis-server          = $json<redis-server>                   if $json<redis-server>  && !$!redis-server;
        $!redis-port            = $json<redis-port>                     if $json<redis-port>    && !$!redis-port;
        without $!tunnel {
            if $json<tunnel> {
                $!tunnel        = $json<tunnel>;
            }
            else {
                $!tunnel        = False;
            }
        }
        $write                  = True  if      $json<local-server>     ne $!local-server 
                                            ||  $json<local-port>       ne $!local-port
                                            ||  $json<redis-server>     ne $!redis-server
                                            ||  $json<redis-port>       ne $!redis-port;
    }
    else {
        $write                  = True;
    }
    $!local-server              = $local-server-default                 without $!local-server;
    $!local-port                = $local-port-default                   without $!local-port;
    $!redis-server              = $redis-server-default                 without $!redis-server;
    $!redis-port                = $redis-port-default                   without $!redis-port;
    $!tunnel                    = False                                 without $!tunnel;
    $redis-servers-cache.store(:identifier<inventory>, :data(to-json({:$!local-server, :$!local-port, :$!redis-server, :$!redis-port, :$!tunnel}))) if $write;
    $!cache-manager            .= new;
}

method !build-connect-prefix {
    @!connect-prefix        = ();
    if self.tunnel {
        @!connect-prefix.push:  '/bin/ssh',
#                               '-L',
#                               $!local-server ~ ':' ~ $!local-port.Str ~ ':' ~ $!redis-server ~ ':' ~ $!redis-port.Str,
                                $!redis-server,
                                '/usr/bin/redis-cli',
                                '-h',
                                '127.0.0.1',
                                '-p',
                                $!redis-port.Str;
    }
    else {
        @!connect-prefix.push:  '/usr/bin/redis-cli', '-h', $!redis-server, '-p', $!redis-port.Str;
    }
}

method GET (Str:D :$key) {
    self!build-connect-prefix unless @!connect-prefix.elems;
    my $proc    = run @!connect-prefix, '--raw', 'GET', $key, :out;
    my $value   = $proc.out.slurp(:close);
    $value     ~~ s/ ^ '"' //;
    $value     ~~ s/ '"' $ //;
    return $value;
}

method SET (Str:D :$key, Str:D :$value) {
    self!build-connect-prefix unless @!connect-prefix.elems;
    my @command     = @!connect-prefix;
    my $identifier  = $key ~ '_' ~ sprintf("%09d", $*PID) ~ '_' ~ DateTime.now.posix(:real);
    $!cache-manager.store(:$identifier, :data($value));
    @command.push: '-x', 'SET', $key;
    my $proc    = run @command, :in, :out;
    $proc.in.spurt($!cache-manager.fetch(:$identifier));
    $proc.in.close;
    $!cache-manager.expire-now(:$identifier);
    return $proc.exitcode;
}

method EXPIRE (Str:D :$key, Int:D :$seconds) {
    self!build-connect-prefix unless @!connect-prefix.elems;
    run @!connect-prefix, 'EXPIRE', $key, $seconds, :out;
}

=finish
