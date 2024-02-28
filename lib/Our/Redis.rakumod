unit class Our::Redis:api<1>:auth<Mark Devine (mark@markdevine.com)>;

use Data::Dump::Tree;
use JSON::Fast;
#use Redis::Async

constant $local-server-default                      = '127.0.0.1';
constant $local-port-default                        = 6379;
constant $remote-server-default                     = '127.0.0.1';
constant $remote-port-default                       = 6379;

has IO::Path    $.redis-servers-file    is built    = $*HOME.add('.our-redis.json');
has Str         @!connect-prefix;
has Str         $.local-server          is built;
has Int         $.local-port            is built;
has Str         $.remote-server         is built;
has Int         $.remote-port           is built;

submethod TWEAK {
    my $write           = False;
    if $!redis-servers-file.IO ~~ :e {
        my $json        = from-json(slurp($!redis-servers-file));
        $!local-server  = $json<local-server>                   if $json<local-server>  && !$!local-server;
        $!local-port    = $json<local-port>                     if $json<local-port>    && !$!local-port;
        $!remote-server = $json<remote-server>                  if $json<remote-server> && !$!remote-server;
        $!remote-port   = $json<remote-port>                    if $json<remote-port>   && !$!remote-port;
        $write          = True  if      $json<local-server>     ne $!local-server 
                                    ||  $json<local-port>       ne $!local-port
                                    ||  $json<remote-server>    ne $!remote-server
                                    ||  $json<remote-port>      ne $!remote-port;
    }
    else {
        $write          = True;
    }
    $!local-server      = $local-server-default                 without $!local-server;
    $!local-port        = $local-port-default                   without $!local-port;
    $!remote-server     = $remote-server-default                without $!remote-server;
    $!remote-port       = $remote-port-default                  without $!remote-port;
    if $write {
        spurt($!redis-servers-file, to-json({
                                                :$!local-server,
                                                :$!local-port,
                                                :$!remote-server,
                                                :$!remote-port,
                                            })
        ) or die;
    }
}

method !build-connect-prefix {
    @!connect-prefix        = ();
    @!connect-prefix.push:      '/bin/ssh';
    if $!local-server eq $local-server-default {
        @!connect-prefix.push:  '-h', $!remote-server, '-p', $!remote-port;
    }
    else {
        @!connect-prefix.push:  '-L', $!local-server ~ ':' ~ $!local-port ~ ':' ~ $!remote-server ~ ':' ~ $!remote-port, $!remote-server;
    }
    @!connect-prefix.push:      '/usr/bin/redis-cli';
die @!connect-prefix;
}

method GET (Str:D :$key, Str:D :$value) {
    self!build-connect-prefix unless @!connect-prefix.elems;
    my $proc = run @!connect-prefix, 'GET', $key, :out;
    return $proc.out.eager;
}

multi method SET (Str:D :$key, Str:D :$value) {
    self!build-connect-prefix unless @!connect-prefix.elems;
    my $proc = run @!connect-prefix, 'SET', $key, '"' ~ $value ~ '"';
}

multi method SET (Str:D :$key, Str:D :$path where *.IO ~~ :s) {
    self!build-connect-prefix unless @!connect-prefix.elems;
    my $proc = run @!connect-prefix, '-x', 'SET', $key, :in, :out;
    $proc.in.print: slurp($path);
    $proc.in.close;
}

method EXPIREAT (Str:D :$key, Int:D :$epoch-seconds) {
    my $epoch   = $epoch-seconds;
    my $current-epoch-plus-one-year = DateTime.now.posix.Int + (366 * 24 * 60 * 60);
    if $epoch > $current-epoch-plus-one-year {
        note 'Truncating EXPIREAT to 1 year';
        $epoch  = $current-epoch-plus-one-year;
    }
    self!build-connect-prefix unless @!connect-prefix.elems;
    run @!connect-prefix, 'EXPIREAT', $key, $epoch, 'NX';
}

=finish

my $proc = run 'ssh', '-L', '127.0.0.1:6379:jgstmgtgate1lpv.wmata.local:6379', 'jgstmgtgate1lpv.wmata.local', '/usr/bin/redis-cli', '-x', 'SET', $key, :in, :out;
$proc.in.print: slurp('r.dat');
$proc.in.close;

