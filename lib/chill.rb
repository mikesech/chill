##
# Starts a subprocess that dies when its parent does.
# 
# The Chill class provides a way to fork or spawn a subprocess
# that will die when its parent does. It accomplishes this by
# also spawning a watchdog process. The watchdog and the parent
# are connected by an anonymous pipe; when the pipe is broken
# (because the parent dies), the watchdog will then send a signal
# to the child.
# 
# There are some limitations to this. Firstly, the parent must
# maintain the pipe. It cannot, for example, overlay itself
# with another process (through an exec call) that closes all
# open file descriptors. Secondly, there is a minor race
# condition. If the child terminates before the parent, the parent
# reaps the child, and a new process is started with the same PID,
# the watchdog will mistakenly kill this different process when
# the parent dies. This could be avoided by having the watchdog
# spawn the child, but that would complicate the relationship between
# the parent and child.
# 
# The easiest way to use this class is to call one of its class methods,
# ::fork or ::spawn. You can also construct an instance, which will give
# you control over the signal it issues to the child (by default +SIGTERM+).
# 
# This class was created to quickly solve a problem in a development
# environment. It isn't necessarily ideal for production use. For Linux
# environments, you might want to look into +PR_SET_PDEATHSIG+.
# 
class Chill
  VERSION = '1.0.1'

  ##
  # The PID of the spawned subprocess.
  #
  attr_reader :pid

  ##
  # Constructs a new Chill object.
  #
  # Also creates a new anonymous pipe to be used as the underlying
  # signaling mechanism.
  # 
  # +signal+::
  #   The name of the POSIX signal (e.g., "TERM") to issue
  #   the child when its parent dies.
  #
  def initialize(signal = "TERM")
    @reader, @writer = IO.pipe
    @signal = signal
  end

  ##
  # Forks a child process and executes a block in it.
  # 
  # Returns the PID of the child process.
  # 
  def fork(&block)
    raise RuntimeError, "already in use" unless @pid.nil?
    @pid = Process.fork do
      # The child doesn't need the pipe, and leaving it open
      # will keep the pipe alive even after the parent dies.
      @reader.close
      @writer.close
      block.call
    end
    spawn_watchdog_process
    
    # The parent of the watchdog process (the original parent)
    # doesn't need to use the pipe. Let's close the other end now.
    @reader.close

    @pid
  end
  ##
  # Spawns a new process.
  # See <tt>Kernel::exec</tt> for the arguments accepted.
  # 
  # *Note* that, unlike <tt>Kernel::spawn</tt>, this method will not
  # raise an exception if it fails to properly +exec+ the new
  # program. Instead, the child process will print an error
  # message and immediately quit.
  # 
  # Returns the PID of the child process.
  # 
  def spawn(*args)
    fork do
      begin
        Process.exec(*args)
      rescue Exception => e
        # If we failed to exec, this process needs to exit immediately
        # without triggering any normal cleanup. Otherwise, we'd end up
        # stepping on the parent process' toes.
        # We'll end up quitting before the runtime could handle the exception,
        # so we have to output the error message manually. This matches the
        # runtime's output format.
        # We write directly to stderr to bypass any buffers, which won't be
        # flushed when we call +exit!+.
        backtrace = e.backtrace.nil? || e.backtrace.empty? ? [""] : e.backtrace
        $stderr.write "#{backtrace[0]}: #{e} (#{e.class.name})\n" + backtrace[1..-1].inject(""){|m,x|"#{m}\tfrom #{x}\n"}
        Kernel.exit!
      end
    end
  end

  ##
  # Forks a child process and executes a block in it.
  # 
  # Returns the Chill instance created. The PID of the child process
  # can be accessed through its +pid+ method.
  # 
  def self.fork(&block); x = self.new; x.fork(&block); x; end
  ##
  # Spawns a new process.
  # See <tt>Kernel::exec</tt> for the arguments accepted.
  # 
  # *Note* that, unlike <tt>Kernel::spawn</tt>, this method will not
  # raise an exception if it fails to properly +exec+ the new
  # program. Instead, the child process will print an error
  # message and immediately quit.
  # 
  # Returns the Chill instance created. The PID of the child process
  # can be accessed through its +pid+ method.
  # 
  def self.spawn(*args); x = self.new; x.spawn(*args); x; end

  private

  ##
  # Spawns a subprocess to monitor the parent.
  # 
  # The watchdog process' parent is the original parent.
  # The watchdog works by waiting for a pipe also held by the parent to
  # break. When it does, it will issue a signal to the child process.
  # 
  def spawn_watchdog_process
    Process.fork do
      # If we don't close the write end, the read might never end since the OS doesn't
      # generate EOFs if there is a write end still open. We use EOF to signal a failure
      # or abrupt termination of the signaling process.
      @writer.close

      val = @reader.sysread(1) rescue nil
      @reader.close

      Process.kill(@signal, @pid) if val.nil?

      # Don't run any at_exit functions; the parent process will take care of all that.
      Kernel.exit!
    end
  end
end
