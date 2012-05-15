require 'date'
require 'timeout'
require 'elasticbeanstalk/hostmanager/daemon'
require 'elasticbeanstalk/hostmanager/log'

module ElasticBeanstalk
  module HostManager

    class LogMonitor
      include Log
      include Daemon
      
      # Read 64k bytes at a time
      CHUNKSIZE = 65536
      
      attr_accessor :log_file_path
          
      module FileWatcher
        def initialize(monitor)
          @monitor = monitor
        end
        
        def file_modified
          @monitor.notify :modified
        end
        
        def file_moved
          @monitor.notify :moved
        end
        
        def file_deleted
          @monitor.notify :deleted
        end
        
        def unbind
        end
      end
      
      def initialize(log_file_path)
        raise "A logfile is required" if (log_file_path.nil? || log_file_path.empty?)
        raise "#{log_file_path} is not a valid logfile" if !::File.exists?(log_file_path)

        @log_file_path = log_file_path
        
        # Initializes @log_file
        open
        
        # Get the file's stats
        @log_file_fstat = ::File.stat(@log_file_path)
        
        # Set file offset
        @log_file.sysseek(0, IO::SEEK_END)
      end
      
      def cleanup
        logger.info("Stopping monitoring of logfile '#{@log_file_path}'")
        @log_file.close if @log_file
      end
      
      def notify(status)
        case status
        when :modified
          read
        when :moved
        when :deleted
        end
      end
      
      def monitor_file(file_path=@log_file_path)
        logger.info("Beginning monitoring of logfile '#{file_path}'")
        EM.watch_file(file_path, FileWatcher, self)
      end

      def process_log_messages(messages)
      end
      
      def read
        begin
          data = @log_file.sysread(CHUNKSIZE)
          @pos += data.length
          process_data(data)
          next_read
        rescue EOFError
          eof
        end
      end

      private
      
      def open
        @log_file.close if @log_file
        @log_file = ::File.open(@log_file_path, 'r')
        @pos = 0
        next_read
      end
      
      def next_read
        EM.next_tick { self.read }
      end
      
      def eof
        process_fstat(::File.stat(@log_file_path))
      end
      
      def process_fstat(fstat)
        raise "No fstat for file #{@log_file_path}" if fstat.nil?
        
        # Inode changed, reopen
        if (fstat.ino != @log_file_fstat.ino)
          open
        # File truncated, move to beginning
        elsif (fstat.size < @log_file_fstat.size)
          @log_file.sysseek(0, IO::SEEK_SET)
          next_read
        end
        
        @log_file_fstat = fstat
      end

      def process_data(data)
        process_log_messages((@buffer ||= BufferedTokenizer.new).extract(data))
        @buffer.flush
      end
    end ## LogMonitor Class
    
  end ## HostManager module
end ## ElasticBeanstalk module
