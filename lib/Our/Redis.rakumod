unit class Our::Redis:api<1>:auth<Mark Devine (mark@markdevine.com)>;

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

submethod TWEAK {
    my $redis-servers-file-name = cache-file-name(:meta<redis-servers>);
    my $write           = False;
    if $redis-servers-file-name.IO ~~ :e {
        my $json        = from-json(cache(:cache-file-name($redis-servers-file-name)));
        $!local-server  = $json<local-server>                   if $json<local-server>  && !$!local-server;
        $!local-port    = $json<local-port>                     if $json<local-port>    && !$!local-port;
        $!redis-server  = $json<redis-server>                   if $json<redis-server>  && !$!redis-server;
        $!redis-port    = $json<redis-port>                     if $json<redis-port>    && !$!redis-port;
        without $!tunnel {
            if $json<tunnel> {
                $!tunnel = $json<tunnel>;
            }
            else {
                $!tunnel = False;
            }
        }
        $write          = True  if      $json<local-server>     ne $!local-server 
                                    ||  $json<local-port>       ne $!local-port
                                    ||  $json<redis-server>     ne $!redis-server
                                    ||  $json<redis-port>       ne $!redis-port;
    }
    else {
        $write          = True;
    }
    $!local-server      = $local-server-default                 without $!local-server;
    $!local-port        = $local-port-default                   without $!local-port;
    $!redis-server      = $redis-server-default                 without $!redis-server;
    $!redis-port        = $redis-port-default                   without $!redis-port;
    $!tunnel            = False                                 without $!tunnel;
    cache(:cache-file-name($redis-servers-file-name), :data(to-json({:$!local-server, :$!local-port, :$!redis-server, :$!redis-port, :$!tunnel}))) if $write;
}

method !build-connect-prefix {
    @!connect-prefix        = ();
    if self.tunnel {
        @!connect-prefix.push:  '/bin/ssh',
                                '-L',
                                $!local-server ~ ':' ~ $!local-port.Str ~ ':' ~ $!redis-server ~ ':' ~ $!redis-port.Str,
                                $!redis-server,
                                '/usr/bin/redis-cli';
    }
    else {
        @!connect-prefix.push:  '/usr/bin/redis-cli', '--raw', '-h', $!redis-server, '-p', $!redis-port.Str;
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

multi method SET (Str:D :$key, Str:D :$value) {
    self!build-connect-prefix unless @!connect-prefix.elems;
#   my $proc = run @!connect-prefix, 'SET', $key, '"' ~ $value ~ '"', :out;
    run @!connect-prefix, 'SET', $key, $value;
}

multi method SET (Str:D :$key, Str:D :$path) {
    self!build-connect-prefix unless @!connect-prefix.elems;
    my $proc = run @!connect-prefix, '-x', 'SET', $key, :in, :out;
    $proc.in.slurp($path, :close);
    $proc.in.close;
}

method EXPIRE (Str:D :$key, Int:D :$seconds) {
    self!build-connect-prefix unless @!connect-prefix.elems;
    run @!connect-prefix, 'EXPIRE', $key, $seconds, :out;
}

=finish
