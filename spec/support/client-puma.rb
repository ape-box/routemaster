before_fork do
  @at_exit_installed ||= begin
    pid = Process.pid
    at_exit do
       if Process.pid == pid
        $stderr.write "[#{pid}] - Puma master exiting\n"
      end
    end
    true
  end
end

