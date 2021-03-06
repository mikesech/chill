The Chill gem provides a way to fork or spawn a subprocess
that will die when its parent does. It accomplishes this by
also spawning a watchdog process. The watchdog and the parent
are connected by an anonymous pipe; when the pipe is broken
(because the parent dies), the watchdog will then send a signal
to the child.

There are some limitations to this. Firstly, the parent must
maintain the pipe. It cannot, for example, overlay itself
with another process (through an exec call) that closes all
open file descriptors. Secondly, there is a minor race
condition. If the child terminates before the parent, the parent
reaps the child, and a new process is started with the same PID,
the watchdog will mistakenly kill this different process when
the parent dies. This could be avoided by having the watchdog
spawn the child, but that would complicate the relationship between
the parent and child.

The easiest way to use the class is to call one of its class methods,
`::fork` or `::spawn`. You can also construct an instance, which will give
you control over the signal it issues to the child (by default `SIGTERM`).

This gem was created to quickly solve a problem in a development
environment. It isn't necessarily ideal for production use. For Linux
environments, you might want to look into `PR_SET_PDEATHSIG`.

More information is available in the doc directory, which is generated by
running rdoc against the whole project. An
[online copy](http://htmlpreview.github.io/?https://github.com/mikesech/chill/blob/master/doc/Chill.html)
is available.
