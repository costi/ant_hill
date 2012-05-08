require 'spec_helper'

module AntHill
  describe Creep do
    let(:creep){ Creep.new }
    let(:logger) {double("logger")}
    before :each do
      q = double("queen")
      Queen.stub(:queen){ q }
      c = double("configuration")
      Configuration.stub(:config){ c }
      creep.stub(:logger){ logger }
    end

    context "#initialize" do
      it "should set current_params to {}" do
        creep.current_params.should == {}
      end
      it "should set status to :wait" do
        creep.status.should == :wait
      end
    end

    context "#require_ant" do
      before :each do 
        Queen.queen.stub(:find_ant){ |params| params }
      end
      it "should return ant for current_params" do
        Queen.stub(:locked?){false}
        params = {:a => 1, :b => 2}
        creep.instance_variable_set(:@current_params, params)
        creep.require_ant.should == params
      end
      it "should sleep if queen is locked" do
        var = -1
        Queen.stub(:locked?){ var+=1; var < 2 ? true : false }
        params = {:a => 1, :b => 2}
        creep.instance_variable_set(:@current_params, params)
        creep.stub(:sleep)
        creep.should_receive(:sleep).twice
        creep.require_ant
      end
    end
    context "#setup_and_process_ant" do
      let(:ant) { double("ant") }
      let(:creep_modifier) { double('creep_modifier') }
      let(:params){{:aaa => 1, :bbb => 2}}
      
      before :each do

        cmc = double('creep_modifier_class')
        cmc.stub(:new){|creep| creep_modifier }

        ac = double("ant_colony")
        ac.stub(:creep_modifier_class) { cmc }

        ant.stub(:ant_colony){ac}
        ant.stub(:params) { params }
        ant.stub(:execution_status){ 'passed' }
        creep.stub(:setup){true}
        creep.stub(:run){true}
      end

      it "should increase processed count by 1" do
        lambda{
          creep.setup_and_process_ant(ant)
        }.should change(creep, :processed).by(1)
      end
      it "should increase passed count by 1 if ant status passed" do
        lambda{
          creep.setup_and_process_ant(ant)
        }.should change(creep, :passed).by(1)
        ant.stub(:execution_status){'failed'}
        lambda{
          creep.setup_and_process_ant(ant)
        }.should_not change(creep, :passed).by(1)
      end
      it "should call setup method" do
        creep.should_receive(:setup).with(creep_modifier, ant).and_return(true)
        creep.setup_and_process_ant(ant)
      end
      context "setup ok" do
        it "should call run method" do
          creep.should_receive(:run).with(creep_modifier, ant)
          creep.setup_and_process_ant(ant)
        end
        it "should change current_params to ant params " do
          creep.setup_and_process_ant(ant)
          creep.current_params.should eql(params)
        end
      end
      context "setup failed" do
        before :each do
          creep.stub(:setup){false}
        end
        it "should not call run method" do
          creep.should_not_receive(:run).with(creep_modifier, ant)
          creep.setup_and_process_ant(ant)
        end
        it "should clean up current params" do
          creep.instance_variable_set(:@current_params, {:c => 3})
          creep.setup_and_process_ant(ant)
          creep.current_params.should eql({})
        end
        it "should change status to error" do
          creep.stub(:change_status)
          creep.should_receive(:change_status).with(:error)
          creep.setup_and_process_ant(ant)
        end
      end
      it "should log error and change status to :error if exception happen during setup" do
        creep.stub(:setup){raise}
        creep.should_receive(:change_status).with(:error)
        logger.should_receive(:error)
        creep.setup_and_process_ant(ant)
      end
      it "should log error and change status to :error if exception happen during run" do
        creep.stub(:run){raise}
        creep.should_receive(:change_status).with(:error)
        logger.should_receive(:error)
        creep.setup_and_process_ant(ant)
      end
    end
    
    context "#setup" do
    end
  end
end
