Our::Redis
==========
Module that provides local interface to Redis client

SYNOPSIS
========

~~~
    use Our::Redis;

    my Our::Redis $redis-cli .= new(
                                    :redis-servers-file = $*HOME.add('.our-redis.json'),
                                    :local-server = '127.0.0.1',
                                    :local-port = 6379,
                                    :remote-server!,
                                    :remote-port = 6379,
                                   );

    #   ssh -L {$local-server}:{$local-port}:{$remote-server}:{$remote-port} {$remote-server} /usr/bin/redis-cli
~~~

AUTHOR
======
Mark Devine <mark@markdevine.com>
