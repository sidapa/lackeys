require 'spec_helper'
require 'lackeys'

describe Lackeys::RailsBase, type: :class do
  let(:test_class) { Class.new { include Lackeys::RailsBase } }
  let(:test_class_instance) { test_class.new }
  let(:registry) { double("Registry Double") }
  before(:each) do
    allow(Lackeys::Registry).to receive(:new).once.and_return registry
  end

  describe "#registry" do
    it "should return the same registry instance every time" do
      expect(test_class_instance.registry).to be registry
      expect(test_class_instance.registry).to be registry
    end
  end

  describe "#respond_to?" do
    let(:method_name) { :test_method }

    context "registry knows the method" do
      before(:each) do
        expect(registry).to receive(:method?).with(method_name).and_return true
      end

      it { expect(test_class_instance.respond_to?(method_name, double())).to eq true }
    end

    context "registry does not know the method but instance knows the method" do
      before(:each) do
        expect(registry).to receive(:method?).with(method_name).and_return false
        def test_class_instance.test_method; end;
      end

      it { expect(test_class_instance.respond_to?(method_name, double())).to be true }
    end

    context "both instance and registry do not know the method" do
      before(:each) do
        expect(registry).to receive(:method?).with(method_name).and_return false
      end

      it { expect(test_class_instance.respond_to?(method_name, double())).to be false }
    end
  end

  describe "method_missing" do
    let(:method_name) { :test_method }

    context "registry knows the method" do
      let(:return_value) { "100" }
      before(:each) do
        expect(registry).to receive(:method?).with(method_name).and_return true
        expect(registry).to receive(:call).with(method_name).and_return return_value
      end

      it { expect(test_class_instance.send(method_name)).to eq return_value }
    end

    context "registry does not know the method" do
      let(:alternate_return_value) { "200" }
      let(:test_class_instance) { DummyClass.new }
      class ParentDummyClass
        def method_missing(method_name, *args, &block); "200"; end
      end
      class DummyClass < ParentDummyClass; include Lackeys::RailsBase; end;
      before(:each) do
        expect(registry).to receive(:method?).with(method_name).and_return false
      end

      it { expect(test_class_instance.send(method_name)).to eq alternate_return_value }
    end
  end
end