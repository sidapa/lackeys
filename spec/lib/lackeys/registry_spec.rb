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
    let(:source) { double }
    let(:source2) { double }
    let(:s_instance) { double('source2_instance')}
    let(:s2_instance) { double }
    let(:obs) { [source, source2] }
    let(:method_name) { :foo }
    let(:class_double) { double(name: 'Foo') }
    let(:calling_obj) { double(class: class_double) }
    let(:contents) do
      {
        class_double.name.to_sym => {
          registered_methods: { foo: { multi: false, observers: obs } }
        }
      }
    end
    subject(:method) do
      Lackeys::Registry.new(calling_obj).call method_name, 1, 2
    end

    before(:each) do
      @registry = Lackeys::Registry.instance_variable_get(:@registry)
      Lackeys::Registry.instance_variable_set(:@registry, contents)
      allow(source).to receive(:new).and_return(s_instance)
      allow(source2).to receive(:new).and_return(s2_instance)
    end

    after(:each) do
      Lackeys::Registry.instance_variable_set(:@registry, @registry)
    end

    it 'should call method from source passing calling_obj and args' do
      expect(s_instance).to receive(method_name).with(1, 2)
      expect(s2_instance).to receive(method_name).with(1, 2)
      method
    end

    it 'should return an array or returned values' do
      allow(s_instance)
        .to receive(method_name)
        .with(1, 2)
        .and_return('foo')
      allow(s2_instance)
        .to receive(method_name)
        .with(1, 2)
        .and_return('bar')
      expect(method).to eql(%w(foo bar))
    end

    context 'only 1 source' do
      let(:contents) do
        {
          class_double.name.to_sym => {
            registered_methods: { foo: { multi: false, observers: [source] } }
          }
        }
      end

      it 'should return an array or returned values' do
        allow(s_instance)
          .to receive(method_name)
          .with(1, 2)
          .and_return('foo')
        expect(method).to eql('foo')
      end
    end

    context 'method_name passed is a string' do
      let(:method_name) { 'foo' }

      it 'should call method from source passing calling_obj and args' do
        expect(s_instance).to receive(method_name.to_sym).with(1, 2)
        expect(s2_instance).to receive(method_name.to_sym).with(1, 2)
        method
      end
    end

    context 'method does not exist' do
      let(:method_name) { :bar }
      let(:error_msg) { 'bar has not been registered' }

      it { expect { method }.to raise_error error_msg }
    end

    context 'call commit on all observers for a multi call' do
      let(:s_instance) { double('source2_instance')}
      let(:s2_instance) { double }
      let(:contents) do
        {
          class_double.name.to_sym => {
            registered_methods: { foo: { multi: true, observers: obs } }
          }
        }
      end

      before(:each) do
        expect(s_instance).to receive(:foo).with(1,2).and_return true
        expect(s2_instance).to receive(:foo).with(1,2).and_return true
        expect(s_instance).to receive(:commit).and_return true
        expect(s2_instance).to receive(:commit).and_return true
      end

      it { method }
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
          mthods = registry[dest][:registered_methods]
          expect(mthods[method_name])
            .to eql(multi: true, observers: [Integer])
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
        mthods = Lackeys::Registry.instance_variable_get(:@registry)[dest]
        expect(mthods[:validations][method_name]).to eql(observers: [Integer])
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
        mthods = Lackeys::Registry.instance_variable_get(:@registry)[dest][:callbacks]
        expect(mthods[callback_type][method_name]).to eql(observers: [Integer])
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
