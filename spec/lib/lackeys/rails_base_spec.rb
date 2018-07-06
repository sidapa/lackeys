require 'spec_helper'
require 'lackeys'
require 'active_model'

describe Lackeys::RailsBase, type: :class do
  let(:test_class) do
    Class.new do
      extend ActiveModel::Callbacks
      include Lackeys::RailsBase
    end
  end
  let(:test_class_instance) { test_class.new }
  let(:registry) { double("Registry Double") }
  before(:each) do |example|
    unless RSpec.current_example.metadata[:skip_registry_stub]
      allow(Lackeys::Registry).to receive(:new).once.and_return registry
    end
  end

  describe "validations" do
    let(:test_class_instance) { TestRailsClass.new }
    subject { test_class_instance.valid? }
    class TestRailsClass
      extend ActiveModel::Callbacks
      include ActiveModel::Validations
      include Lackeys::RailsBase
    end
    class TestServiceClass < Lackeys::ServiceBase
      Lackeys::Registry.register(TestServiceClass, TestRailsClass) do |r|
        r.add_validation :validation_method
      end

      def validation_method; end
    end

    context "validation succeeds" do
      before(:each) do
        expect_any_instance_of(TestServiceClass).to receive(:validation_method).and_return true
      end

      it "should be called", skip_registry_stub: true do
        should be true
      end
    end

    context "service validation fails" do
      it "should fail validation", skip_registry_stub: true do
        TestServiceClass.class_eval do
          def validation_method
            parent.errors[:base] << "New error!"
          end
        end

        should be false
      end
    end

    context "model validation fails" do
      let(:test_class_instance) { TestChildClass.new }
      class TestSuper
        extend ActiveModel::Callbacks
        include ActiveModel::Validations
        def valid?(_context = nil); false; end
      end
      class TestChildClass < TestSuper
        include Lackeys::RailsBase
      end
      class TestChildServiceClass < Lackeys::ServiceBase
        Lackeys::Registry.register(TestChildServiceClass, TestChildClass) do |r|
          r.add_validation :validation_method
        end

        def validation_method; end
      end
      it "should fail validation", skip_registry_stub: true do
        should be false
      end
    end
  end

  describe "should automatically generate callbacks" do
    let(:test_class_instance) { TestRailsClass.new }
    let(:before_save_called) { false }
    let(:after_save_called) { false }
    let(:before_create_called) { false }
    let(:after_create_called) { false }
    class TestRailsClass
      extend ActiveModel::Callbacks
      include Lackeys::RailsBase
    end
    class TestServiceClass < Lackeys::ServiceBase
      Lackeys::Registry.register(TestServiceClass, TestRailsClass) do |r|
        r.add_method :called
        r.add_callback :before_save, "before_save"
        r.add_callback :after_save, "after_save"
        r.add_callback :before_create, "before_create"
        r.add_callback :after_create, "after_create"
      end

      def initialize_internals; @called = []; end
      def called; @called; end

      def before_save; @called << "before_save"; end
      def after_save; @called << "after_save"; end
      def before_create; @called << "before_create"; end
      def after_create; @called << "after_create"; end
    end
    subject { test_class_instance.called }

    context "save callbacks" do
      before(:each) { test_class_instance.run_callbacks(:save) }
      it "save callbacks", skip_registry_stub: true do
        should include "before_save"
        should include "after_save"
        should_not include "before_create"
        should_not include "after_create"
      end
    end

    context "create callbacks" do
      before(:each) { test_class_instance.run_callbacks(:create) }
      it "create callback", skip_registry_stub: true do
        should_not include "before_save"
        should_not include "after_save"
        should include "before_create"
        should include "after_create"
      end
    end
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

  describe "#who_has?" do
    let(:method_name) { :test_method }
    let(:test_class_instance) { TestClass.new }
    let(:service1) { double(source_location: ["path1","line_num1"]) }
    let(:service2) { double(source_location: ["path2","line_num2"]) }
    let(:service1_method_location) { service1.source_location.join(":") }
    let(:service2_method_location) { service2.source_location.join(":") }

    class TestClass
      extend ActiveModel::Callbacks
      include Lackeys::RailsBase

      def test_class_method; end
    end
    class TestService1 < Lackeys::ServiceBase; end
    class TestService2 < Lackeys::ServiceBase; end

    subject { test_class_instance.who_has? method_name }

    before(:each) do
      allow(registry).to receive(:method?).and_return registry_method_return
      allow(TestService1).to receive(:instance_method).with(method_name).and_return service1
      allow(TestService2).to receive(:instance_method).with(method_name).and_return service2
    end

    context "not defined in any service" do
      let(:registry_method_return) { nil }
      it { should be_nil }
    end

    context "method defined in 1 service" do
      let(:registry_method_return) { TestService1 }
      it { should be_a Hash }
      it { should include(:klass => TestService1) }
      it { should include(:location => service1_method_location) }
    end

    context "method defined in more than 1 service" do
      let(:registry_method_return) { [TestService1, TestService2] }
      it { should be_an Array }
      it { should include({ klass: TestService1, location: service1_method_location }) }
      it { should include({ klass: TestService2, location: service2_method_location }) }
    end

    context "method is an actual instance method (not a service method)" do
      let(:method_name) { :test_class_method }
      let(:registry_method_return) { nil }
      it { should be_a Hash }
      it { should include(:klass => TestClass) }
      it { should include(:location => TestClass.instance_method(method_name).source_location.join(":")) }
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
      class DummyClass < ParentDummyClass
        extend ActiveModel::Callbacks
        include Lackeys::RailsBase
      end;
      before(:each) do
        expect(registry).to receive(:method?).with(method_name).and_return false
      end

      it { expect(test_class_instance.send(method_name)).to eq alternate_return_value }
    end
  end
end
