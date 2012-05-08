require 'ant_hill'

task :add_colony do
  host = ENV['drb_host'] || 'localhost'
  AntHill::Queen.create_colony ARGV[1..-1], host
end

task :monitor do
  host = ENV['drb_host'] || 'localhost'
  queen = AntHill::Queen.drb_queen(host)
  while true
    sleep 2
    print "\e[2J\e[f"
    puts "Creep size: #{queen.creeps.size}"
    puts "Ants left: #{queen.size}"
    queen.creeps.each{|creep|
      puts creep.to_s
    }
  end
end

task :execute_each do
  threads = []
  host = ENV['drb_host'] || 'localhost'
  AntHill::Queen.creeps(host).each{|creep|
    threads << Thread.new do
       creep.exec!(ENV['command'])
    end
  }
  threads.each{ |t| t.join}
end

