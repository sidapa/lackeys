# frozen_string_literal: true

require 'spec_helper'
require 'lackeys'

describe Lackeys::Registry, type: :class do
  subject(:registry) { Lackeys::Registry.new(calling_obj) }
  let(:calling_obj) { double(class: Fixnum) }

  it 'sets @caller' do
    calling_class_name = registry.instance_variable_get(:@caller)
    expect(calling_class_name)
      .to eql(calling_obj)
  end

  describe '::register' do
    subject(:method) { Lackeys::Registry.register(*params) { |_x| } }
    let(:params) { [Integer, String] }
    let(:registration_params) { [Integer, :String] }

    context 'no block given' do
      subject(:method) { Lackeys::Registry.register(*params) }
      let(:error_msg) { 'Registry#register requires a block' }

      it { expect { method }.to raise_error error_msg }
    end

    it { should be_nil }

    it 'yields an instance of Lackeys::Registration' do
      reg_double = double

      expect(Lackeys::Registration)
        .to receive(:new)
        .with(*registration_params)
        .and_return(reg_double)
      expect(reg_double).to receive(:register_method).with(:test)
      expect(Lackeys::Registry).to receive(:add).with(reg_double)

      Lackeys::Registry.register(*params) { |r| r.register_method :test }
    end
  end

  describe '#call' do
    class Service1; def initialize(*args); end; def foo!(a,b); 1; end; def foo_commit; end; end
    class Service2; def initialize(*args); end; def foo!(a,b); 2; end; def foo_commit; end; end
    class BaseClass; end

    let(:s_instance) { Service1.new }
    let(:s2_instance) { Service2.new }
    let(:source) { Service1 }
    let(:source2) { Service2 }
    let(:obs) { [source] }
    let(:method_name) { :foo! }
    let(:commit_method_name) { :foo_commit }
    let(:calling_obj) { BaseClass.new }
    let(:multi) { false }
    let(:returner) { nil }
    let(:contents) do
      {
        BaseClass.name.to_sym => {
          registered_methods: { foo!: { multi: multi, observers: obs, returner: returner } }
        }
      }
    end
    let(:parameter_list) { [1, 2] }

    subject(:method) do
      Lackeys::Registry.new(calling_obj).call method_name, *parameter_list
    end

    before(:each) do
      @registry = Lackeys::Registry.instance_variable_get(:@registry)
      Lackeys::Registry.instance_variable_set(:@registry, contents)
      allow(Service1).to receive(:new).and_return s_instance
      allow(Service2).to receive(:new).and_return s2_instance
    end

    after(:each) do
      Lackeys::Registry.instance_variable_set(:@registry, @registry)
    end

    it 'should call method from source passing calling_obj and args' do
      expect(s_instance).to receive(method_name).with(*parameter_list).and_return nil
      method
    end

    context 'only 1 source' do
      it 'should return an array or returned values' do
        allow(s_instance)
          .to receive(method_name)
          .with(*parameter_list)
          .and_return(method_name.to_s)
        expect(method).to eql(method_name.to_s)
      end
    end

    context 'method_name passed is a string' do
      it 'should call method from source passing calling_obj and args' do
        expect(s_instance).to receive(method_name).with(*parameter_list)
        method
      end
    end

    context 'method does not exist' do
      let(:method_name) { :bar }
      let(:error_msg) { 'bar has not been registered' }

      it { expect { method }.to raise_error error_msg }
    end

    context 'call commit on all observers for a multi call' do
      let(:multi) { true }
      let(:obs) { [source, source2] }

      before(:each) do
        expect(s_instance).to receive(method_name).with(*parameter_list).and_return true
        expect(s2_instance).to receive(method_name).with(*parameter_list).and_return true
        expect(s_instance).to receive(commit_method_name).and_return true
        expect(s2_instance).to receive(commit_method_name).and_return true
      end

      it { method }
    end

    context 'multi call' do
      let(:multi) { true }
      let(:obs) { [source, source2] }
      let(:s_return_value) { true }
      let(:s2_return_value) { false }

      before(:each) do
        expect(s_instance).to receive(method_name).with(*parameter_list).and_return true
        expect(s2_instance).to receive(method_name).with(*parameter_list).and_return true
        expect(s_instance).to receive(commit_method_name).and_return s_return_value
        expect(s2_instance).to receive(commit_method_name).and_return s2_return_value
      end

      context 'with no returner' do
        it { should be_kind_of(Hash) }
        it { should include(Service1 => s_return_value) }
        it { should include(Service2 => s2_return_value) }
      end

      context 'with a returner' do
        context 'source is a returner' do
          let(:returner) do
            Proc.new do |result_hash|
              result_hash[Service1]
            end
          end

          it { should eq s_return_value }
        end

        context 'source2 is a returner' do
          let(:returner) do
            Proc.new do |result_hash|
              result_hash[Service2]
            end
          end

          it { should eq s2_return_value }
        end

        context 'combined values' do
          let(:s_return_value) { 3 }
          let(:s2_return_value) { 5 }
          let(:combined_value) { s_return_value + s2_return_value }
          let(:returner) do
            Proc.new do |result_hash|
              result_hash[Service1] + result_hash[Service2]
            end
          end

          it { should eq combined_value }
        end
      end
    end

    
  end

  describe '::value_by_caller' do
    let(:contents) { { 'String' => value } }
    let(:value) { :foo }
    subject(:method) { Lackeys::Registry.value_by_caller('String') }

    before(:each) do
      @registry = Lackeys::Registry.instance_variable_get(:@registry)
      Lackeys::Registry.instance_variable_set(:@registry, contents)
    end

    after(:each) do
      Lackeys::Registry.instance_variable_set(:@registry, @registry)
    end

    it { should eql(value) }

    context 'caller key does not exist' do
      let(:contents) { { 'NotString' => value } }

      it { is_expected.to eql({}) }
    end
  end

  describe '#method?' do
    let(:param) { Lackeys::Registration.new(source, dest) }
    let(:source) { Integer }
    let(:dest) { String }
    let(:dest_object) { 'I am a String' }
    let(:method_name) { :foo }
    let(:contents) do
      {
        String.name.to_sym => {
          registered_methods: { foo: { multi: false, observers: [String] } }
        }
      }
    end

    subject(:method) { Lackeys::Registry.new(dest_object).method? method_name }

    before(:each) do
      @registry = Lackeys::Registry.instance_variable_get(:@registry)
      Lackeys::Registry.instance_variable_set(:@registry, contents)
      param.add_method method_name
    end

    after(:each) do
      Lackeys::Registry.instance_variable_set(:@registry, @registry)
    end

    it { should eql(true) }

    context 'method has not been registered' do
      let(:method_name) { :bar }

      it { should eql(false) }
    end

    context 'method name is a string' do
      let(:method_name) { 'foo' }

      it { should eql(true) }
    end
  end

  describe '#get_observers' do
    let(:param) { Lackeys::Registration.new(source, dest) }
    let(:source) { Integer }
    let(:dest) { String }
    let(:dest_object) { 'I am a String' }
    let(:method_name) { :foo }
    let(:observers) { [String] }
    let(:contents) do
      {
        String.name.to_sym => {
          registered_methods: { foo: { multi: false, observers: observers } }
        }
      }
    end

    subject(:method) { Lackeys::Registry.new(dest_object).get_observers method_name }

    before(:each) do
      @registry = Lackeys::Registry.instance_variable_get(:@registry)
      Lackeys::Registry.instance_variable_set(:@registry, contents)
      param.add_method method_name
    end

    after(:each) do
      Lackeys::Registry.instance_variable_set(:@registry, @registry)
    end

    it { should be_an Array }
    it { should include(String) }
  end

  describe '::add' do
    subject(:method) { Lackeys::Registry.add(parameter) }
    let(:param) { Lackeys::Registration.new(source, dest) }
    let(:source) { Integer }
    let(:dest) { String }
    let(:option) { {} }

    context 'registered_methods' do
      let(:method_name) { :foo }
      let(:contents) { {} }
      let(:error_msg) { 'foo has already been registered' }
      before(:each) do
        @registry = Lackeys::Registry.instance_variable_get(:@registry)
        Lackeys::Registry.instance_variable_set(:@registry, contents)
        param.add_method method_name, option
      end

      after(:each) do
        Lackeys::Registry.instance_variable_set(:@registry, @registry)
      end

      it 'adds the method' do
        Lackeys::Registry.add(param)
        registry = Lackeys::Registry.instance_variable_get(:@registry)
        methods = registry[dest][:registered_methods]
        expect(methods[method_name])
          .to eql(multi: false, observers: [Integer])
      end

      context 'a multi: false method has already been registered' do
        let(:contents) do
          {
            String => {
              registered_methods: { foo: { multi: false, observers: [String] } }
            }
          }
        end

        it { expect { Lackeys::Registry.add(param) }.to raise_error error_msg }
      end

      context 'add a allow_multi: true method' do
        let(:option) { { allow_multi: true } }
        let(:add_method) { Lackeys::Registry.add(param) }

        it 'adds the method' do
          Lackeys::Registry.add(param)
          registry = Lackeys::Registry.instance_variable_get(:@registry)
          method = registry[dest][:registered_methods][method_name]
          expect(method).to include(multi: true)
          expect(method).to include(observers: [Integer])
          expect(method).to include(returner: nil)
        end

        context 'this multi_method is a returner' do
          let(:method_name2) { :baz }
          before(:each) do
            param.add_method method_name2, option do
              # This is a block
            end
          end

          it 'adds the method' do
            Lackeys::Registry.add(param)
            registry = Lackeys::Registry.instance_variable_get(:@registry)
            method = registry[dest][:registered_methods][method_name2]
            expect(method).to include(multi: true)
            expect(method).to include(observers: [Integer])
            expect(method).to include(returner: an_instance_of(Proc))
          end

          context 'adding a 2nd multi_method with a block' do
            let(:source2) { Fixnum }
            let(:other_service) { Lackeys::Registration.new(source2, dest) }

            before(:each) do
              other_service.add_method method_name2, option do
              # This is a block
              end
            end

            it 'should raise an error' do
              expect { Lackeys::Registry.add(param) }.to_not raise_error
              expect { Lackeys::Registry.add(other_service) }.to raise_error "Multi-method #{method_name2} already previously registered with a block"
            end
          end
        end

        context 'a multi: false method has already been registered' do
          let(:contents) do
            {
              String => {
                registered_methods: { foo: { multi: false, observers: [String] } }
              }
            }
          end

          it { expect { add_method }.to raise_error error_msg }
        end
      end
    end

    context '@validations' do
      let(:method_name) { :foo }
      let(:contents) { {} }
      let(:error_msg) { 'foo has already been registered' }
      before(:each) do
        @registry = Lackeys::Registry.instance_variable_get(:@registry)
        Lackeys::Registry.instance_variable_set(:@regitry, contents)
        param.add_validation method_name
      end

      after(:each) do
        Lackeys::Registry.instance_variable_set(:@registry, @registry)
      end

      it 'adds the method' do
        Lackeys::Registry.add(param)
        methods = Lackeys::Registry.instance_variable_get(:@registry)[dest]
        expect(methods[:validations][method_name]).to eql(observers: [Integer])
      end

      context 'an existing validation has already been registered' do
        let(:contents) do
          {
            String => {
              validations: { foo: { observers: [Integer] } }
            }
          }
        end

        it { expect { Lackeys::Registry.add(param) }.to raise_error error_msg }
      end
    end

    context '@callbacks' do
      let(:method_name) { :foo }
      let(:callback_type) { :before_save }
      let(:contents) { { before_save: {} } }
      let(:error_msg) { 'foo has already been registered' }

      before(:each) do
        @registry = Lackeys::Registry.instance_variable_get(:@registry)
        Lackeys::Registry.instance_variable_set(:@registry, contents)
        param.add_callback :before_save, method_name
      end

      after(:each) do
        Lackeys::Registry.instance_variable_set(:@registry, @registry)
      end

      it 'adds the method' do
        Lackeys::Registry.add(param)
        methods = Lackeys::Registry.instance_variable_get(:@registry)[dest][:callbacks]
        expect(methods[callback_type][method_name]).to eql(observers: [Integer])
      end

      context 'an existing callback method has already been registered' do
        let(:contents) do
          {
            String => {
              callbacks: { before_save: { foo: { observers: [Integer] } } }
            }
          }
        end

        it { expect { Lackeys::Registry.add(param) }.to raise_error error_msg }
      end
    end
  end
end
