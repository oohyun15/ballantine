# frozen_string_literal: true

require "spec_helper"

describe Ballantine::CLI do
  before(:each) do
    @cli = Ballantine::CLI.new
  end

  context "init" do
    let(:file_name) { Ballantine::Config::FILE_BALLANTINE_CONFIG }
    let(:file_path) { "./#{file_name}" }

    after(:each) { File.delete(file_path) }

    it "returns ballantine config file" do
      expect(@cli.init).to be_truthy
      expect(Dir[file_path]).to eq([file_path])
      expect(JSON.parse(File.read(file_path))).to eq({})
    end

    context "already init" do
      before(:each) { @cli.init }

      it "raises error" do
        expect { @cli.init }.to raise_error(Ballantine::NotAllowed) do |e|
          expect(e.message).to eq("#{file_name} already exists.")
        end
      end

      context "with force option" do
        before(:each) { @cli.options = { "force" => true }.freeze }

        it "returns ballantine config file" do
          expect(@cli.init).to be_truthy
          expect(Dir[file_path]).to eq([file_path])
          expect(JSON.parse(File.read(file_path))).to eq({})
        end
      end
    end
  end

  context "version" do
    let(:version) { Ballantine::VERSION }

    it "returns current ballantine version" do
      expect(@cli.version).to eq(version)
    end
  end

  context "config" do
    # not implemented
  end

  context "diff" do
    # not implemented
  end
end
