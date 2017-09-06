require 'puma/util'

# Patches Puma::Util so that pipe IO can be closed without errors.
# The underlying bug exists in MRI 2.2.7, 2.3.4, 2.4.1, and is _partly_
# addressed by the stopgap_13632 gem and Puma 3.10.0
# See:
# - https://github.com/puma/puma/issues/1293
# - https://github.com/puma/puma/pull/1206
# - https://github.com/puma/puma/pull/1345
module Puma
  module Util
    module_function

    def pipe
      IO.pipe.tap do |a,b|
        a.extend(SafeClosingPipe)
        b.extend(SafeClosingPipe)
      end
    end
  end

  # According to the MRI docs, IO#close should return nil on an already-closed
  # IO, but sometimes doesn't for pipes.
  module SafeClosingPipe
    def close
      super
    rescue IOError
      Thread.current.purge_interrupt_queue if Thread.current.respond_to? :purge_interrupt_queue
      nil
    end
  end
end
