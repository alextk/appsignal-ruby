require 'spec_helper'
require 'appsignal/capistrano'
require 'capistrano/configuration'

describe Appsignal::Capistrano do
  before :all do
    @config = Capistrano::Configuration.new
    Appsignal::Capistrano.tasks(@config)
  end

  it "should have a deploy task" do
    @config.find_task('appsignal:deploy').should_not be_nil
  end

  describe "appsignal:deploy task" do
    before :all do
      @config.set(:rails_env, 'development')
      @config.set(:repository, 'master')
      @config.set(:deploy_to, '/home/username/app')
      @config.set(:current_release, '')
      @config.set(:current_revision, '503ce0923ed177a3ce000005')
      ENV['USER'] = 'batman'
    end

    context "send marker" do
      let(:marker_data) {
        {
          :revision => "503ce0923ed177a3ce000005",
          :repository => "master",
          :user => "batman"
        }
      }
      before :all do
        @io = StringIO.new
        @logger = Capistrano::Logger.new(:output => @io)
        @logger.level = Capistrano::Logger::MAX_LEVEL
        @config.logger = @logger
      end
      before do
        @marker = Appsignal::Marker.new(marker_data, Rails.root.to_s,
          'development', @logger)
        Appsignal::Marker.should_receive(:new).
          with(marker_data, Rails.root.to_s, 'development', anything()).
          and_return(@marker)
      end

      context "proper setup" do
        before do
          @transmitter = mock()
          Appsignal::Transmitter.should_receive(:new).and_return(@transmitter)
        end

        it "should transmit data" do
          @transmitter.should_receive(:transmit).and_return('200')
          @config.find_and_execute_task('appsignal:deploy')
          @io.string.should include('** Notifying Appsignal of deploy...')
          @io.string.should include('** Appsignal has been notified of this '\
            'deploy!')
        end
      end

      it "should not transmit data" do
        @config.find_and_execute_task('appsignal:deploy')
        @io.string.should include('** Notifying Appsignal of deploy...')
        @io.string.should include('** Something went wrong while trying to '\
          'notify Appsignal:')
      end

      context "dry run" do
        before(:all) { @config.dry_run = true }

        it "should not send deploy marker" do
          @marker.should_not_receive(:transmit)
          @config.find_and_execute_task('appsignal:deploy')
          @io.string.should include('** Dry run: Deploy marker not actually '\
            'sent.')
        end
      end
    end
  end
end