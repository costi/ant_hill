require 'drb'

module AntHill
  class Queen
    def initialize(config = Configuration.config)
      @config = config
      @ants = []
    end

    def service(cfg={})
      create_colony(cfg)
      spawn_creeps(@config[:creeps])
    end

    def create_colony(params={})
      type = params.delete(:type)
      colony = AntColony.new(params, type)
      @ants += colony.get_ants
    end

    def spawn_creeps(creeps)
      @threads = []
      for creep in creeps
        @threads << Thread.new{
          c = Creep.new
          c.configure(creep)
          Thread.current["name"]=c.to_s
          c.service
        }
      end
      @threads << Thread.new{
        DRb.start_service "druby://localhost:6666", self
      }
      @threads.each{|t| t.join}
    end

    def find_ant(params)
      @lock = true
      ants = prioritized_ants(params)
      winner = ants.pop
      puts ants.size
      @lock = false
      winner
    end

    def prioritized_ants(params)
      @ants.sort! do |a,b|
        a.priority(params) <=> b.priority(params)
      end
    end

    def locked?
      @lock
    end

    class << self
      def locked?
        @@queen.locked?
      end

      def queen
        @@queen ||= self.new
      end

      def drb_queen
        DRb.start_service
        queen = DRbObject.new nil, "druby://localhost:6666"
      end
    end
  end
end