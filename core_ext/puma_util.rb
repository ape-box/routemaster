# Patches Puma::Util so that pipe IO can be closed without errors.
# See: https://github.com/puma/puma/issues/1293

$stderr.puts "patching Puma"

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
      nil
    end
  end
end
