require 'spec_helper'
require_relative '../lib/marionetta'
require_relative '../lib/marionetta/manipulators/deployer'

def deployer()
  Marionetta::Manipulators::Deployer.new(server)
end

def cmd()
  Marionetta::CommandRunner.new(server)
end

describe Marionetta::Manipulators::Deployer do
  it 'should deploy' do
    cmd.ssh('rm -rf ~/app')
    deployer.deploy
    cmd.ssh("[ -d ~/app/current ]").should == true
    cmd.ssh("[ -d ~/app/releases ]").should == true
    cmd.ssh("[ -f ~/app/current/app.rb ]").should == true
    cmd.ssh("[ -f ~/app/current/app-copy.rb ]").should == true
    cmd.ssh("[ -f ~/app/current/exclude.txt ]").should_not == true
    cmd.ssh("[ -f ~/app/current/exclude/another.txt ]").should_not == true
    cmd.ssh("[ -f ~/app/current/after ]").should_not == true
  end

  it 'should list releases' do
    deployer.releases.length.should > 0
  end

  it 'should rollback' do
    deployer.rollback
  end
end