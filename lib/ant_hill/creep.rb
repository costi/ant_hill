module AntHill
  class Creep
    attr_reader :host, :user, :password, :status, :connection_pool, :logger, :current_params, :processed, :passed
    attr_accessor :active
    def initialize(queen=Queen.queen, config=Configuration.config)
      @config = config
      @queen = queen
      @current_params = {}
      @status = :wait
      @current_ant = nil
      @processed = 0
      @passed = 0
      @start_time = Time.now
    end
    
    def require_ant
      while Queen.locked?
        sleep rand
      end
      ant = @queen.find_ant(@current_params)
    end

    def setup_and_process_ant(ant)
      @current_ant = ant
      begin
        modifier = ant.ant_colony.creep_modifier_class.new(self)
        ok = setup(modifier, ant)
        if ok
          @current_params = ant.params
          run(modifier, ant)
        else
          @current_params = {}
          change_status(:error)
        end
      rescue Exception => e
        change_status(:error)
        logger.error e
      ensure
        @processed+=1
        @passed +=1 if @current_ant.execution_status.to_sym == :passed
        @current_ant = nil
      end
    end

    def setup(modifier, ant)
      timeout = modifier.get_setup_time(ant, @current_params)
      change_status(:setup)
      ok = timeout_execution(timeout, "setup #{ant.params.inspect}") do
        modifier.setup(ant, @current_params)
      end
      ok &&= modifier.check(ant)
      ok
    end

    def run(modifier, ant)
      timeout = modifier.get_run_time(ant)
      change_status(:run)
      timeout_execution(timeout, "run #{ant.to_s}") do
        modifier.run(ant)
      end
    end

    def logger
      Log.logger_for host
    end

    def configure(hill_configuration)
      @hill_cfg = hill_configuration
      @host = @hill_cfg['host']
      @user = @hill_cfg['user']
      @password = @hill_cfg['password']
      @connection_pool = @config.get_connection_class.new(self)
    end

    def exec!(command, timeout=nil)
      logger.info("Executing: #{command}")
      stderr, stdout = timeout_execution(timeout, "exec!(#{command})") do
        connection_pool.execute(command)
      end
      logger.error("STDERR: #{stderr}") unless stderr.empty?
      logger.info("STDOUT: #{stdout}")
      stdout
    end

    def timeout_execution(timeout=nil, process = nil)
      result = nil
      begin
        if timeout
          Timeout::timeout( timeout ) do
            result = yield 
          end
        else
          result = yield 
        end
      rescue Timeout::Error => e
        change_status(:error)
        logger.error "#{self.host}: timeout error for #{process.to_s}"
      rescue Exception => e
        logger.error e
      end
      result
    end

    def to_s
      took_time = Time.at(Time.now - @start_time).gmtime.strftime('%R:%S')
      "%s (%i): %s (%s): %s " % [@hill_cfg['host'], @processed, status, took_time,  @current_ant]
    end

    def active?; @active; end

    def service
      while true
        ant = self.require_ant
        if ant && active?
          setup_and_process_ant(ant)
        else
          change_status(:wait) 
          sleep @config.sleep_interval
        end
      end
      connection_pool.destroy
    end

    def change_status(status)
      return if @status == status
      @status = status
      @start_time = Time.now
    end
  end
end

